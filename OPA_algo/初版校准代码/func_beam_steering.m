function func_beam_steering(theta,s)
lambda = 1.55e-6;
V = zeros(1,256);
V(129:256) = load("0du.txt");
load("d1.mat");
R = 1040;
P_2pi = 0.0353;
P_temp = V.^2/R;
d = [0, flip(d)]*1e-6;
x = cumsum(d);

phi = x.*sind(theta)*2*pi/lambda;

input_phi = phi;


%% 打开串口
% SerialObj = func_256_serial_open;
Vbefore = rand(1,256);
% while(1)
% for theta = 10
% for theta = theta0:d_theta:theta1
% %%---------RX------------------------
% P_0(3:4:127) = P_temp(1:32);
% P_0(1:4:125) = P_temp(33:64);
% P_0(4:4:128) = P_temp(65:96);
% P_0(2:4:126) = P_temp(97:128);
% 
% 
% P = mod((P_0+input_phi/2/pi*P_2pi), P_2pi);
% input_V = sqrt(P*R);
% 
% V_cal(1:32)   = input_V(3:4:127);
% V_cal(33:64)  = input_V(1:4:125);
% V_cal(65:96)  = input_V(4:4:128);
% V_cal(97:128) = input_V(2:4:126);

% %%---------TX------------------------
P_0(2:4:126) = P_temp(1+128:32+128);
P_0(4:4:128) = P_temp(33+128:64+128);
P_0(1:4:125) = P_temp(65+128:96+128);
P_0(3:4:127)= P_temp(97+128:128+128);

% P_0(3:4:127) = P_temp(1+128:32+128);
% P_0(1:4:125) = P_temp(33+128:64+128);
% P_0(4:4:128) = P_temp(65+128:96+128);
% P_0(2:4:126) = P_temp(97+128:128+128);
% 
P = mod((P_0+input_phi/2/pi*P_2pi), P_2pi);
input_V = sqrt(P*R);

V(1+128:32+128) = input_V(2:4:126);
V(33+128:64+128) = input_V(4:4:128);
V(65+128:96+128) = input_V(1:4:125);
V(97+128:128+128) = input_V(3:4:127);

%% 256电压源输出代码
%% 更改电压
ZJY_256VSRC_WRITE(s, V);


end
