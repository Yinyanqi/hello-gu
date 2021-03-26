close all
format long
clc
clear
warning off
global gv
tic

%-------------------------------------------------------------------------
disp('Pre-processing')

% 几何参数
E        =110e3;                         % [Pa] 杨氏模量
eta      =5e3;                           % [Pa*s] 粘度 5e3
Poi      =0.5;                           % [-] 泊松比 0.5
G        =E/(2*(1+Poi));                 % [Pa] 剪切模量
R        =10e-3;                         % [m] 半径 10e-3
L        =250e-3;                        % [m] 臂长 250e-3
num_piece=2;                             % number of pieces 
num_disc =20;                           
X        =linspace(0,L,num_piece);       % 
A        =pi*R^2;                        % [m^2] 横截面积
J        =pi*R^4/4;                      % [m^4] 横截面惯性矩（截面对y和z轴）
I        =pi*R^4/2;                      % [m^4] 截面极惯性矩

% 未变形时的应变
xi_star    =[0;0;0;1;0;0];

% dynamic parameters

ro_arm      =1080;                             % [kg/m^3] 1080
Gra         =[0;0;0;-9.81;0;0];                % [m/s^2]重力加速度旋量（相对于空间坐标系）
Eps         =diag([G*I E*J E*J E*A G*A G*A]);  % stifness matrix
Ipsi        =eta*diag([I 3*J 3*J 3*A A A]);    % viscosity matrix eta*diag([I 3*J 3*J 3*A A A]);
% eta is the shear viscosity that can be formulated in terms of the retardation time constant
M           =ro_arm*diag([I J J A A A]);       % 螺旋惯性矩阵

%-------------------------------------------------------------------------
% numerical setting

time        =1;                          % [s]
nsol        =time*10^2+1;                % a solution every centisecond关节数量
tspan       =linspace(0,time,nsol);      % [s] time

dX          =L/(num_disc-1);             % delta X

%-------------------------------------------------------------------------
% 驱动力 (body frame)
tact        =1;                        % [s] torque time in dir z o y 外力持续时间 
trel        =2;                        % [s] relaxation time 松弛时间   阶梯冲激
Fax         =0*[0 0 0 0];              % [N] contraction load
Fay         =0*[0 0 0 0];              % [N] lateral y load 0.1
Faz         =0*[0 0 0 0];              % [N] lateral z load 0.01
Famx        =0*[0 0 0 0];              % [Nm] torsion torque 0.001
Famy        =0*[0 0 0 0];              % [Nm] bending torque
Famz        =0*[0 0 0 0];              % [Nm] bending torque 0.005
%-------------------------------------------------------------------------
% external tip load (base (X=0) coordinate)

Fpx         =0*[0 0 0 0];              % [N] contraction load
Fpy         =0.01*[0 5 0 0];           % [N] lateral y load
Fpz         =0.01*[0 1 0 0];              % [N] lateral z load
Fpmx        =0*[0 0 0 0];              % [Nm] torsion torque
Fpmy        =0*[0 0 0 0];              % [Nm] bending torque
Fpmz        =0*[0 0 0 0];              % [Nm] bending torque
%-------------------------------------------------------------------------
% observable
g           =zeros(4*nsol,4*num_disc*num_piece);
eta         =zeros(6*nsol,num_disc*num_piece);
nstep       =1;

% global variable
gv.ro_arm      =ro_arm;
gv.Gra         =Gra;
gv.L           =L;
gv.X           =X;
gv.R           =R;
gv.xi_star     =xi_star;
gv.A           =A;
gv.Eps         =Eps;
gv.Ipsi        =Ipsi;
gv.M           =M;
gv.nsol        =nsol;
gv.num_disc    =num_disc;
gv.num_piece   =num_piece;
gv.dX          =dX;
gv.time        =time;
gv.tspan       =tspan;
gv.tact        =tact;
gv.trel        =trel;
gv.Fax         =Fax;
gv.Fay         =Fay;
gv.Faz         =Faz;
gv.Famx        =Famx;
gv.Famy        =Famy;
gv.Famz        =Famz;
gv.Fpx         =Fpx;
gv.Fpy         =Fpy;
gv.Fpz         =Fpz;
gv.Fpmx        =Fpmx;
gv.Fpmy        =Fpmy;
gv.Fpmz        =Fpmz;

% observable
gv.g           =g;
gv.eta         =eta;
gv.nstep       =nstep;

%-------------------------------------------

disp('Time-advancing')
myopt          =odeset('RelTol',1e-4,'OutputFcn',@piecewise_observables);

%-------------------------------------------------------------------------
% initial temporal conditions

xi_0          =[0;0;0;1;0;0];  % given variable of the joint 
xidot_0       =[0;0;0;0;0;0];
            
ini_cond        =[repmat(xi_0',[1,num_piece]) repmat(xidot_0',[1,num_piece])];
%B = repmat(A,m,n)，B is consist of m×n A.
% integrate
% [t,z]          =ode45(@piecewise_derivatives,tspan,ini_cond,myopt);

[t,z]          =ode45(@piecewise_CBA,tspan,ini_cond,myopt);

toc
% postproc
disp('Post-processing')

%r=size(A,1)返回矩阵A的行数， c=size(A,2) 返回矩阵A的列数
tau       =zeros(nsol,num_piece);
xci       =zeros(nsol,num_piece);
k         =zeros(nsol,num_piece);
q         =zeros(nsol,num_piece);
p         =zeros(nsol,num_piece);
r         =zeros(nsol,num_piece);
for ii=1:num_piece
    tau(:,ii) =z(:,6*(ii-1)+1);
    xci(:,ii) =z(:,6*(ii-1)+2);
    k(:,ii)   =z(:,6*(ii-1)+3);
    q(:,ii)   =z(:,6*(ii-1)+4);
    p(:,ii)   =z(:,6*(ii-1)+5);
    r(:,ii)   =z(:,6*(ii-1)+6);
end
for ii=1:num_piece
    % deformations

    figure
    plot(t,tau(:,ii))
    grid on
    title(strcat('torsion of piece',num2str(ii)))
    xlabel('t [s]')
    ylabel('tau [1/m]')
    auxstr  =strcat('.\LAST RUN\torsione',num2str(ii),'.png');
    print('-dpng',auxstr)

    figure
    plot(t,xci(:,ii))
    grid on
    title(strcat('curvature on y of piece',num2str(ii)))
    xlabel('t [s]')
    ylabel('xci [1/m]')
    auxstr  =strcat('.\LAST RUN\curvature',num2str(ii),'_on_y.png');
    print('-dpng',auxstr)

    figure
    plot(t,k(:,ii))
    grid on
    title(strcat('curvature on z of piece',num2str(ii)))
    xlabel('t [s]')
    ylabel('k [1/m]')
    auxstr  =strcat('.\LAST RUN\curvature',num2str(ii),'_on_z.png');
    print('-dpng',auxstr)

    figure
    plot(t,q(:,ii))
    grid on
    title(strcat('longitudinal strain of piece',num2str(ii)))
    xlabel('t [s]')
    ylabel('q [-]')
    auxstr  =strcat('.\LAST RUN\longitudinal_strain',num2str(ii),'.png');
    print('-dpng',auxstr)

    figure
    plot(t,p(:,ii))
    grid on
    title(strcat('tras y strain of piece',num2str(ii)))
    xlabel('t [s]')
    ylabel('p [-]')
    auxstr  =strcat('.\LAST RUN\tras_y_strain',num2str(ii),'.png');
    print('-dpng',auxstr)

    figure
    plot(t,r(:,ii))
    grid on
    title(strcat('tras z strain of piece',num2str(ii)))
    xlabel('t [s]')
    ylabel('r [-]')
    auxstr  =strcat('.\LAST RUN\tras_z_strain',num2str(ii),'.png');
    print('-dpng',auxstr)

end
% piecewise_postprocsolo(t,z)
toc