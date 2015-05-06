function [r,J] = obj_ba(x,a,b,param)
% Bundle adjustment objective
% a are camera extrinsic params, are structure params

% measurement vector is [x_ij] where i is the index of the 3d point and j
% is the index of the view

cam_num = size(a,1);
pts_num = size(b,1);

% 4 image coordinates for each observation in each view \times the number
% of parameters (motion + structure)
predd  = pts_num*cam_num*param.obd;
paramd = param.ad*cam_num+param.bd*pts_num;
% Jacobian
J = zeros(predd,paramd);
% residuals
r = nan(predd,1);

for i=1:pts_num
    for j=1:cam_num
        if isempty(x{i,j}),
            continue;
        end
        % index of the current element in the prediction vector/row
        % number in the Jacobian
        pred_ind = param.obd*((i-1)*cam_num+(j-1))+1;
        % index in the camera param vector
        param_ind = param.ad*(j-1)+1;
        
        % calc first order data r_{ij}
        [r(pred_ind:pred_ind+param.obd-1),Jx] = predict1(x{i,j},a{j},b{i},param);
        J(pred_ind:pred_ind+param.obd-1,param_ind:param_ind+param.ad-1) = Jx(:,1:param.ad);
        % index of the structure parameter
        param_ind = param.ad*cam_num+param.bd*(i-1)+1;
        J(pred_ind:pred_ind+param.obd-1,param_ind:param_ind+param.bd-1) = Jx(:,param.ad+1:param.ad+param.bd);
    end
end
end

% prediction model and its gradient
function [r,J] = predict1(x,a,b,param)
% motion parameteres, rotation(euler angles)/translation
rx = a(1); ry = a(2); rz = a(3);
tx = a(4); ty = a(5); tz = a(6);

% precompute sine/cosine
sx = sin(rx); cx = cos(rx); sy = sin(ry);
cy = cos(ry); sz = sin(rz); cz = cos(rz);

% compute rotation matrix
r00    = +cy*cz;           r01    = -cy*sz;           r02    = +sy;
r10    = +sx*sy*cz+cx*sz;  r11    = -sx*sy*sz+cx*cz;  r12    = -sx*cy;
r20    = -cx*sy*cz+sx*sz;  r21    = +cx*sy*sz+sx*cz;  r22    = +cx*cy;

X1p = b(1); Y1p = b(2); Z1p = b(3);
% [R t]*e2h(X)
X1c = r00*b(1)+r01*b(2)+r02*b(3)+tx;
Y1c = r10*b(1)+r11*b(2)+r12*b(3)+ty;
Z1c = r20*b(1)+r21*b(2)+r22*b(3)+tz;
X2c = X1c-param.base;

r = nan(4,1);
% residuals: x-h2e(K[R t]e2h(X))
r(1) = param.calib.f*X1c/Z1c+param.calib.cu-x(1);
r(2) = param.calib.f*Y1c/Z1c+param.calib.cv-x(2);
r(3) = param.calib.f*X2c/Z1c+param.calib.cu-x(3);
r(4) = param.calib.f*Y1c/Z1c+param.calib.cv-x(4);

% dR/drx
rdrx10 = +cx*sy*cz-sx*sz;  rdrx11 = -cx*sy*sz-sx*cz;  rdrx12 = -cx*cy;
rdrx20 = +sx*sy*cz+cx*sz;  rdrx21 = -sx*sy*sz+cx*cz;  rdrx22 = -sx*cy;
% dR/dry
rdry00 = -sy*cz;           rdry01 = +sy*sz;           rdry02 = +cy;
rdry10 = +sx*cy*cz;        rdry11 = -sx*cy*sz;        rdry12 = +sx*sy;
rdry20 = -cx*cy*cz;        rdry21 = +cx*cy*sz;        rdry22 = -cx*sy;
% dR/drz
rdrz00 = -cy*sz;           rdrz01 = -cy*cz;
rdrz10 = -sx*sy*sz+cx*cz;  rdrz11 = -sx*sy*cz-cx*sz;
rdrz20 = +cx*sy*sz+sx*cz;  rdrz21 = +cx*sy*cz-sx*sz;

J = nan(4,9);
% derivation w.r.t. motion parameters
for p=1:9
    switch p
        case 1
            % dR/drx*X
            X1cd = 0;
            Y1cd = rdrx10*X1p+rdrx11*Y1p+rdrx12*Z1p;
            Z1cd = rdrx20*X1p+rdrx21*Y1p+rdrx22*Z1p;
        case 2
            % dR/dry*X
            X1cd = rdry00*X1p+rdry01*Y1p+rdry02*Z1p;
            Y1cd = rdry10*X1p+rdry11*Y1p+rdry12*Z1p;
            Z1cd = rdry20*X1p+rdry21*Y1p+rdry22*Z1p;
        case 3
            % dR/drz*X
            X1cd = rdrz00*X1p+rdrz01*Y1p;
            Y1cd = rdrz10*X1p+rdrz11*Y1p;
            Z1cd = rdrz20*X1p+rdrz21*Y1p;
        case 4
            % dR/dtx*X
            X1cd = 1; Y1cd = 0; Z1cd = 0;
        case 5
            % dR/dty*X
            X1cd = 0; Y1cd = 1; Z1cd = 0;
        case 6
            % dR/dtz*X
            X1cd = 0; Y1cd = 0; Z1cd = 1;
        case 7
            X1cd = r00; Y1cd = r10; Z1cd = r20;
        case 8
            X1cd = r01; Y1cd = r11; Z1cd = r21;
        case 9
            X1cd = r02; Y1cd = r12; Z1cd = r22;
    end
    % division by Z1c*Z1c is because of the derivative of h2e
    J(1,p) = param.calib.f*(X1cd*Z1c-X1c*Z1cd)/(Z1c*Z1c);
    J(2,p) = param.calib.f*(Y1cd*Z1c-Y1c*Z1cd)/(Z1c*Z1c);
    J(3,p) = param.calib.f*(X1cd*Z1c-X2c*Z1cd)/(Z1c*Z1c);
    J(4,p) = param.calib.f*(Y1cd*Z1c-Y1c*Z1cd)/(Z1c*Z1c);
end
end