function test_stereo_motion()

dbstop if error;
close all;

num_pts = 12;                            % number of 3d points to generate
K = [718.8560, 0, 607.1928; 0, 718.8560, 185.2157; 0, 0, 1.0000]; % camera intrinsics

% R0/t0 is the orientation/origin of the right camera as seen from the left
% camera
T0 = [eye(3),[1,0,0]';0 0 0 1];

P1 = K*[eye(3) zeros(3,1)];    % initial cam1

X = 20+5*rand(3,num_pts);      % 3d points, as seen in the world frame
x = nan(4,2*num_pts);          % image projections

[x(1:2,1:num_pts),visible1] = project(P1,X);                         % cam1 projection into (left) image
[x(1:2,(num_pts+1):(2*num_pts)),visible2] =  project(P1,X,T0);  % cam2 projection into (right) image
assert(all([visible1,visible2]),'some points are invisible in the initial stereo rig');

% describes translation and orientation of the frame {i} relative to frame {i-1}
a = rand(6,1);
%a = [0,0,pi/2,0,0,1]';
T = tr2mat(a);

% observations in the new image pair
[x(3:4,1:num_pts),visible1] = project(P1,X,T);
[x(3:4,(num_pts+1):(2*num_pts)),visible2] = project(P1,X,T*T0);
assert(all([visible1,visible2]),'some points are invisible in the new pose of a rig');

% estimate motion
a_est = estimate_stereo_motion(x,K,num_pts,T0(1:3,1:3),T0(1:3,4),a);

assert(norm(a_est-a,'fro')<1e-5);
end