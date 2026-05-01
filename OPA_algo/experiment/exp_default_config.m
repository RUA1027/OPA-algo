function cfg = exp_default_config()
%EXP_DEFAULT_CONFIG Default config for hardware-in-the-loop calibration.
%
% 说明（核心约定）：
% 1) 本框架算法控制域使用 U，且 U = V^2。
% 2) 算法层统一在 U 域优化；仅在写硬件前做 sqrt(U) 得到电压 V。
% 3) 若进行无硬件联调，可使用 cfg.runtime.mockMeasureFn 注入测量回调。
% 4) 方法分发最终由 exp_get_algorithm_runner / exp_run_calibration 统一处理。

cfg = struct();

% ---------------------- 算法方法选择 ----------------------
cfg.method = "mREV-GSS"; 
% "mREV-GSS" | "5PPS" | "PFPD" | "CAIO"

% ---------------------- 全局控制参数（U 域） ----------------------
cfg.numChannels = 64;
cfg.controlMin = 0;
cfg.controlMax = 4 ^ 2; % algorithm control unit U = V^2
cfg.u2pi = 0.012 * 570;  % one 2pi period in U-domain

% ---------------------- 初始控制量 ----------------------
% 为空时，在 [controlMin, controlMax] 内随机初始化。
cfg.initialControlU = []; 
% empty -> random init in [controlMin, controlMax]

% ---------------------- 通道调度策略 ----------------------
% fixed: 每轮固定 1..N 顺序；random_each_round: 每轮重新随机。
cfg.channelOrder = struct();
cfg.channelOrder.mode = "random_each_round"; 
% "fixed" | "random_each_round"

cfg.channelOrder.seed = 42;

% ---------------------- 回滚策略 ----------------------
% 每轮完成后若测量变差，则回滚到该轮开始前状态。
cfg.rollback = struct();
cfg.rollback.enableRoundRollback = true;

% ---------------------- 测量配置 ----------------------
% sampleTimes: 同一控制点重复采样次数。
% delaySec: 写电压后到采样前的稳定等待。
% ccdSpotSize / ccdCenterCol: CCD积分区域配置。
cfg.measure = struct();
cfg.measure.sampleTimes = 1;
cfg.measure.delaySec = 0.03;
cfg.measure.ccdSpotSize = 4;
cfg.measure.ccdCenterCol = 160;
cfg.measure.ccdRealtimeDisplay = struct();
cfg.measure.ccdRealtimeDisplay.enabled = true;
cfg.measure.ccdRealtimeDisplay.figureNumber = 1;
cfg.measure.ccdRealtimeDisplay.saturationThreshold = 16000;
cfg.measure.ccdRealtimeDisplay.figureName = "Calibration Realtime Monitor";

% ---------------------- 硬件总配置 ----------------------
cfg.hardware = struct();
cfg.hardware.sensorMode = "CCD"; 
% "CCD" | "DSO" | "CAPTURE_CARD"

% 电压源串口配置
cfg.hardware.serialPort = "COM6";
cfg.hardware.serialBaud = 128000;

% 外部对象注入开关（true 时复用外部句柄，避免重复创建/关闭）
cfg.hardware.useExternalSerial = false;
cfg.hardware.useExternalVideo = false;
cfg.hardware.externalSerialObj = [];
cfg.hardware.externalVideoObj = [];

% DSO（示波器）配置
cfg.hardware.dso = struct();
cfg.hardware.dso.vendor = "NI";
cfg.hardware.dso.resource = "USB0::0x0957::0x173B::MY54410002::0::INSTR";
cfg.hardware.dso.channel = "CHAN1";
cfg.hardware.dso.points = 250;

% CAPTURE_CARD（USB3000）配置
% 注意：dllDir/headerDir 是与本地驱动安装路径绑定的硬编码，部署时需核对。
cfg.hardware.capture = struct();
cfg.hardware.capture.dllDir = "E:\\script（请勿修改）\\base_function\\数据采集卡\\USB-3000_Matlab\\x64";
cfg.hardware.capture.headerDir = "E:\\script（请勿修改）\\base_function\\数据采集卡\\USB-3000_Matlab";
cfg.hardware.capture.sampleNum = 1000;
cfg.hardware.capture.sampleTimes = 1;
cfg.hardware.capture.sampleRateNs = 1000;
cfg.hardware.capture.openChannels = 1;
cfg.hardware.capture.sampleRange = 1.28;

% ---------------------- mREV-GSS 配置 ----------------------
cfg.mrevGss = struct();
cfg.mrevGss.maxRounds = 4;
cfg.mrevGss.kByRound = [5, 8, 10, 12];
cfg.mrevGss.goldenRatio = (sqrt(5) - 1) / 2;
cfg.mrevGss.controlMin = cfg.controlMin;
cfg.mrevGss.controlMax = cfg.controlMax;

% ---------------------- 5PPS 配置 ----------------------
cfg.fivePps = struct();
cfg.fivePps.maxRounds = 4;
cfg.fivePps.controlMin = cfg.controlMin;
cfg.fivePps.controlMax = cfg.controlMax;

% ---------------------- PFPD 配置 ----------------------
cfg.pfpd = struct();
cfg.pfpd.rounds = 4;
cfg.pfpd.numFitSamples = 14;
cfg.pfpd.fitGridPoints = 201;
cfg.pfpd.controlMin = cfg.controlMin;
cfg.pfpd.controlMax = cfg.controlMax;

% ---------------------- CAIO 配置 ----------------------
cfg.caio = struct();
cfg.caio.maxRounds = 2;
cfg.caio.ppsSteps = 5; % valid values: 3 | 4 | 5
cfg.caio.controlMin = cfg.controlMin;
cfg.caio.controlMax = cfg.controlMax;

% ---------------------- 运行时注入 ----------------------
% mockMeasureFn 非空时，exp_run_calibration 将跳过硬件初始化，直接调用该测量函数。
cfg.runtime = struct();
cfg.runtime.mockMeasureFn = [];

end
