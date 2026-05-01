function func_beam_steering(theta,s)
% Legacy helper kept for compatibility with historical beam steering flow.
%
% 功能概述：
% - 根据目标偏转角 theta 构造相位梯度；
% - 结合历史校准电压/功率映射，生成 256 路电压向量；
% - 通过 ZJY_256VSRC_WRITE 下发至电压源。
%
% 说明：本函数属于历史链路，保留用于兼容旧实验流程，
% 日常优化与标定建议优先使用统一入口（exp_run_calibration）。

persistent warnedLegacy;
if isempty(warnedLegacy)
	warning('opa_exp:legacy:func_beam_steering', ...
		['func_beam_steering follows a legacy mapping path. ' ...
		 'Prefer unified experiment entry for routine calibration/optimization.']);
	warnedLegacy = true;
end

% 输入前置校验：
% theta 必须是有限实数标量；s 必须为可用串口对象。
validateattributes(theta, {'numeric'}, {'scalar', 'real', 'finite'});
if nargin < 2 || isempty(s)
	error("opa_exp:func_beam_steering:MissingSerial", ...
		"A valid serial object is required as input argument s.");
end

% 外部数据依赖校验：
% 0du.txt：历史校准电压基线；d1.mat：阵元间距数据 d。
if ~isfile("0du.txt")
	error("opa_exp:func_beam_steering:MissingFile", ...
		"Required file 0du.txt is missing in current folder.");
end
if ~isfile("d1.mat")
	error("opa_exp:func_beam_steering:MissingFile", ...
		"Required file d1.mat is missing in current folder.");
end

lambda = 1.55e-6;
V = zeros(1,256);

% 读取历史电压基线（128 路），映射到 256 路后半区间。
vLegacy = load("0du.txt");
validateattributes(vLegacy, {'numeric'}, {'vector', 'numel', 128, 'real', 'finite'});
V(129:256) = reshape(double(vLegacy), 1, 128);

% 读取阵元间距向量 d，并转换成累计位置 x。
dData = load("d1.mat", "d");
if ~isfield(dData, "d")
	error("opa_exp:func_beam_steering:BadData", "Variable d is missing in d1.mat.");
end
validateattributes(dData.d, {'numeric'}, {'vector', 'real', 'finite'});

R = 1040;
P_2pi = 0.0353;
P_temp = V.^2/R;
d = [0, flip(reshape(double(dData.d), 1, []))]*1e-6;
x = cumsum(d);

% 基于几何位置与目标角度构造相位项。
phi = x.*sind(theta)*2*pi/lambda;

input_phi = phi;


%% 打开串口
% SerialObj = func_256_serial_open;
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
% 历史通道映射规则：将功率向量重排后叠加 steering 相位，再回推电压。
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
% 最终下发电压向量，完成一次 beam steering 写入。
ZJY_256VSRC_WRITE(s, V);


end
