% Define plane plant
megaclear
addpath('../');
[parameters, gains] = GetDefaultGains();


disp('Loading trajectory library...');
%load ../trajlib/june13.mat
load ../trajfunnel/funnel.mat
disp('done.');

%p_world_coords = DeltawingPlant(parameters);
p = lib.p;

p = p.setInputLimits(-Inf*ones(3,1), Inf*ones(3,1));

%%
% load funnelLibrary.mat
% load funnelLibrary_Jan17.mat
% load funnelLibrary_Feb06_2.mat
% load funnelLibrary_Feb10.mat

traj = lib.GetTrajectoryByNumber(0);
xtraj = traj.xtraj;
utraj = traj.utraj;

%strs = {'18'};

%for kk = 1:length(strs)

%xtraj = trajLibrary{str2num(strs{kk})}.xtraj; % 
%utraj = trajLibrary{str2num(strs{kk})}.utraj; % 

% xtraj = funnelLibrary(1).xtraj;
% utraj = funnelLibrary(1).utraj;

xtraj = xtraj.setOutputFrame(p.getStateFrame);
utraj = utraj.setOutputFrame(p.getInputFrame); % return;

% % Feb 10:
% % Do tvlqr
% Q = diag([2000 6000 1000, 500 500 500, 1200 700 500, 500 200 500]);
% R = 0.2*diag([0.1 0.1 0.5 0.1]); % 0.25
% Qf = Q;

% load initialConditionSet_small.mat
% load G0_big.mat
% G0 = G0_big;


% March 23:
% Do tvlqr
% Q = diag([2000 6000 1000, 500 500 500, 1200 700 500, 500 200 500]);
% R = 0.2*diag([0.1 0.1 0.5 0.1]); % 0.25
% Qf = G0*1000;

Q = gains.Q;
Qf = gains.Qf;
R_values = gains.R_values;
R = diag([R_values(1)*ones(1,3)]);


options = struct();
% options.sqrtmethod = false;

disp('Doing tvlqr...');
[tv,Vtv] = tvlqr(p,xtraj,utraj,Q,R,Qf,options);
disp('done');

% -------- for simulation testing -----------


% tvlqr doesn't do a good job of picking frames correctly, so assign
% them (*sigh*)

% create new coordinate frames so that we can simulate using
% Drake's tools

% nX = lib.p.getNumStates();
% nU = lib.p.getNumInputs();
% 
% iframe = CoordinateFrame([lib.p.getStateFrame.name,' - x0(t)'],nX,lib.p.getStateFrame.prefix);
% lib.p.getStateFrame.addTransform(AffineTransform(lib.p.getStateFrame,iframe,eye(nX),-xtraj));
% iframe.addTransform(AffineTransform(iframe,lib.p.getStateFrame,eye(nX),xtraj));
% 
% oframe = CoordinateFrame([lib.p.getInputFrame.name,' + u0(t)'],nU,lib.p.getInputFrame.prefix);
% oframe.addTransform(AffineTransform(oframe,lib.p.getInputFrame,eye(nU),utraj));
% lib.p.getInputFrame.addTransform(AffineTransform(lib.p.getInputFrame,oframe,eye(nU),-utraj));
% 
% tv = tv.setInputFrame(iframe);
% tv = tv.setOutputFrame(oframe);

comments = 'FUNNEL-test';
lib = lib.AddTrajectory(xtraj, utraj, tv, ['FUNNEL-test'], comments);


%return;
% -------- end for simulation testing -----------
%%



ts = Vtv.S.getBreaks();

for k = 2:12
  
   figure(k)
    clf
    
    %useful for tuning Q,R,and Qf
   % figure(25);
    optionsPlt.inclusion = 'slice';
    optionsPlt.plotdims = [1 k];
    optionsPlt.x0 = xtraj;
    optionsPlt.ts = linspace(ts(1),ts(end),20);
    Vtv_x = Vtv.inFrame(p.getStateFrame);
    plotFunnel(Vtv_x,optionsPlt);
    fnplt(xtraj,[1 k]);
    axis equal
    drawnow
end
%%

G0 = Vtv.S.eval(0);
G0 = 1.01*G0; % Scale it to make initial condition set reasonable.


sysCl = feedback(p,tv); 

disp('Doing taylor approx');
psys = taylorApprox(sysCl,xtraj,[],3);
disp('done');

utraj = utraj.setOutputFrame(p.getInputFrame);
polyOrig = taylorApprox(p,xtraj,utraj,3); % return;


% Do frame thing
% p.getStateFrame.addTransform(AffineTransform(p.getStateFrame,p.getStateFrame,eye(length(x)),double(0*x)));

% Get time samples
% ts = Vtv.S.getBreaks(); tsend = ts(end);
% ts = ts(1:ceil(ts(end)/12*(1/mean(diff(ts)))):length(ts));

ts = linspace(0,0.1,10);


% Do verification
options = struct();
options.saturations = false;
options.rho0_tau = 10;
options.rho0 - 1.00;
options.degL1 = 2;
options.max_iterations = 10;
% options.solveroptions.OutputFlag = 0; 
disp('Starting verification...')

save(['funnelStuff.mat'])

% load(['funnelStuff' num2str(str2num(strs{kk})-7) '_funnel.mat'], 'V');
% 
% Vold = V;
% for k = 1:length(ts)
%     % Phi{k} = funnelLibrary(1).V.S.eval(ts(k)) - Vtv.S.eval(ts(k))/10000;
%     Phi{k} = Vold.S.eval(ts(k)) - Vtv.S.eval(ts(k))/10000;
% end


[V,rho,Phi]=sampledFiniteTimeReach_B0(psys,polyOrig,Vtv,G0,G0,tv,ts,xtraj,utraj,options);
% [V,rho,Phi]=sampledFiniteTimeReach_B0(psys,polyOrig,Vtv/10000,G0,1000*G0,tv,ts,xtraj,utraj,options,Phi,rho);

V = V.setFrame(Vtv.getFrame);

save(['funnelStuff_funnel.mat'])

close all;

%end

return;

% Convert V back to state frame and plot it
Vxframe = V.inFrame(p.getStateFrame());
figure
options.plotdims = [1 2];
options.x0 = xtraj;
options.ts = V.S.getBreaks;
options.inclusion = 'projection';
% options.inclusion = 'slice';
plotFunnel(Vxframe,options);
fnplt(xtraj,[1 2]); 
axis equal

% Tests to make sure simulated trajectories stay inside computed funnel
doTest = 1;
if doTest
    
% Create closed loop system with optimized controller
% sysCl = feedback(p,tv);
V0 = Vxframe.getPoly(0); % Get inlet of funnel
opts = struct();
opts.x0 = zeros(12,1);
opts.num_samples = 100;
xinit = getLevelSet(decomp(V0),V0,opts);

% xp = psys.getStateFrame.poly;
% up = psys.getInputFrame.poly;

addpath('/home/anirudha/Documents/Research/MURI/SBach/OnlinePlanning/Util');

Vsall = [];
figure
hold on
grid on
for j = 1:length(xinit)
    Vs = [];
    x0 = 0.99*xinit(:,j); % + xtraj.eval(0); % Simulate from 0.95*boundary of funnel
    % xsim = psys.simulate([0 ts(end)],x0);
    % xsim = simulateEuler(psys,ts(end),x0,0.001,'msspoly',xp,up);
    xsim = sysCl.simulate([0 ts(end)],x0);
    for k = 1:length(ts)
        Vs = [Vs, Vxframe.eval(ts(k),xsim.eval(ts(k)))];
    end
    Vsall = [Vsall, Vs];
    
    plot(ts,Vs)
    plot(ts,ones(1,length(ts)),'ro')
    drawnow;
end
end















