function cfg = defaultConfig()
%DEFAULTCONFIG Default configuration for 1D OPA calibration simulation.
%
% Output:
%   cfg (struct) Configuration used by initSimulationState, runMrev,
%   runMrevGss, runPfpd, and main_compare_calibration.

thisFile = mfilename("fullpath");
repoRoot = fileparts(fileparts(thisFile)); %提取根目录路径

cfg = struct();

cfg.general = struct();
cfg.general.seed = 42;

cfg.sim = struct();
cfg.sim.numChannels = 128;
cfg.sim.wavelengthM = 1.55e-6;
cfg.sim.targetThetaDeg = 0;
cfg.sim.thetaGridDeg = linspace(-20, 20, 3001);
cfg.sim.dFilePath = fullfile(repoRoot, "一维opa远场计算", "一维opa远场计算", "d1.mat"); %读取间距数据
cfg.sim.dVarName = "d"; %读取变量名d的数据

cfg.sim.defaultSpacingM = 4e-6; %默认间距为4微米，未导入d1.mat时使用。
cfg.sim.u2pi = 7.5^2;  %电压的平方上限
cfg.sim.controlMin = 0;
cfg.sim.controlMax = cfg.sim.u2pi; %搜索区间
cfg.sim.crossTalkRatio = 0.01;  %热串扰比率

% --- 干扰1：通道间振幅不均匀性 ---
% 模拟级联MMI分束器工艺波动导致的各通道功率偏差（参考 Jiao et al., APL Photonics 2025）
cfg.sim.enableAmpNonuniformity = true;   % 默认关闭，不影响原有结果
cfg.sim.ampNonuniformityStd    = 0.03;    % 振幅相对标准差（0.05 = 5%，对应功率偏差~10%）

% --- 干扰2：光学串扰（波导间近场耦合） ---
% 模拟相邻波导倏逝场耦合，作用于电场层面，与热串扰（作用于控制量）机制不同
cfg.sim.opticalCrosstalk = struct();
cfg.sim.opticalCrosstalk.enable        = false;     % 默认关闭
cfg.sim.opticalCrosstalk.kappaAbs      = 0.005;      % |κ|，电场耦合系数绝对值（功率耦合比 η=|κ|²）
cfg.sim.opticalCrosstalk.kappaPhaseRad = pi/2;       % κ 的相位（rad），π/2 为耦合模理论标准值

% --- 干扰3：DAC 量化与驱动电路噪声 ---
% DAC量化为确定性操作，驱动噪声为随机操作；两者均作用于驱动端（区别于测量端噪声）
cfg.sim.dac = struct();
cfg.sim.dac.enable          = true;    % 默认关闭
cfg.sim.dac.bits            = 12;       % DAC位数（12位→量化步长≈0.01374，相位分辨率≈0.088°）
cfg.sim.dac.driverNoiseStd  = 0.05;      % 驱动电路噪声标准差（控制量单位），推荐测试值0.05

cfg.measurement = struct();
cfg.measurement.enableNoise = true; %控制噪声
cfg.measurement.relativeNoiseStd = 0.01; %控制噪声强度
cfg.measurement.enableQuantization = true;% 是否做ADC量化
cfg.measurement.quantizationBits = 12;% 量化位数，例如12位量化意味着测量值将被分成2^12=4096个离散级别。
cfg.measurement.quantizationMax = []; %量化满量程上限（量化范围上边界）


%通道遍历方式控制
cfg.channelOrder = struct();
cfg.channelOrder.mode = "random_each_round"; % "fixed" | "random_each_round"
cfg.channelOrder.randomSeedOffset = 1000;

% mREV 
cfg.mrev = struct();
cfg.mrev.maxRounds = 4;
cfg.mrev.kByRound = [7, 8, 10, 12];
cfg.mrev.shrinkRatio = (sqrt(5) - 1) / 2;
% 黄金分割比在 mREV 中扮演的是“分辨率衰减基数”的角色。
cfg.mrev.controlMin = cfg.sim.controlMin;
cfg.mrev.controlMax = cfg.sim.controlMax;

% mREV-GSS
cfg.mrevGss = struct();
cfg.mrevGss.maxRounds = 4;
cfg.mrevGss.kByRound = [7, 8, 10, 12];
cfg.mrevGss.goldenRatio = (sqrt(5) - 1) / 2;
cfg.mrevGss.controlMin = cfg.sim.controlMin;
cfg.mrevGss.controlMax = cfg.sim.controlMax;

%峰值拟合
cfg.pfpd = struct();
cfg.pfpd.rounds = 4;
cfg.pfpd.numFitSamples = 14; %每次拟合时采14个样本点
cfg.pfpd.fitGridPoints = 201; %拟合后评估网格点数，越多越精细但计算越慢
cfg.pfpd.controlMin = cfg.sim.controlMin;
cfg.pfpd.controlMax = cfg.sim.controlMax;

% 5PPS (Five-Point Phase Stepping)
cfg.fivePps = struct();
cfg.fivePps.maxRounds = 4;
cfg.fivePps.controlMin = cfg.sim.controlMin;
cfg.fivePps.controlMax = cfg.sim.controlMax;

% SPSA (Simultaneous Perturbation Stochastic Approximation)
cfg.spsa = struct();
cfg.spsa.maxIter = 600;
cfg.spsa.a0 = cfg.sim.u2pi * 0.05;
cfg.spsa.c0 = cfg.sim.u2pi * 0.02;
cfg.spsa.alpha = 0.602;
cfg.spsa.gamma = 0.101;
cfg.spsa.stabilityConst = 60;  % 0.1 * maxIter
cfg.spsa.controlMin = cfg.sim.controlMin;
cfg.spsa.controlMax = cfg.sim.controlMax;
cfg.spsa.earlyStop = false;
cfg.spsa.earlyStopWindow = 50;
cfg.spsa.earlyStopPatience = 100;
cfg.spsa.earlyStopTolRel = 1e-4;
cfg.spsa.spsaSeed = 2024;
cfg.spsa.numLogicalRounds = 4;

% Hybrid SPSA-PPS
cfg.hybrid = struct();
cfg.hybrid.spsa = struct();
cfg.hybrid.spsa.maxIter = 250;
cfg.hybrid.spsa.a0 = cfg.sim.u2pi * 0.08;
cfg.hybrid.spsa.c0 = cfg.sim.u2pi * 0.02;
cfg.hybrid.spsa.alpha = 0.602;
cfg.hybrid.spsa.gamma = 0.101;
cfg.hybrid.spsa.stabilityConst = 25;
cfg.hybrid.spsa.spsaSeed = 2024;
cfg.hybrid.pps = struct();
cfg.hybrid.pps.ppsSteps = 5;
cfg.hybrid.pps.maxRounds = 2;
cfg.hybrid.pps.averagingCount = 1;
cfg.hybrid.controlMin = cfg.sim.controlMin;
cfg.hybrid.controlMax = cfg.sim.controlMax;
cfg.hybrid.numLogicalRounds = 4;

% CAIO (Crosstalk-Aware Interleaved Optimization)
cfg.caio = struct();
cfg.caio.maxRounds = 2;
cfg.caio.ppsSteps = 5;
cfg.caio.enableCtCompensation = true;
cfg.caio.controlMin = cfg.sim.controlMin;
cfg.caio.controlMax = cfg.sim.controlMax;

cfg.beamSteering = struct();
cfg.beamSteering.startThetaDeg = 0;
cfg.beamSteering.endThetaDeg = 60;
cfg.beamSteering.stepThetaDeg = 3;
cfg.beamSteering.showFigures = true;
cfg.beamSteering.verbose = true;
cfg.beamSteering.exportMat = false;
cfg.beamSteering.exportCsv = false;
cfg.beamSteering.exportDir = fullfile(repoRoot, "beam_steering_outputs");

cfg.output = struct();
cfg.output.printSummary = true;

cfg.plot = struct();
cfg.plot.showFigures = true;
cfg.plot.dbFloor = -40; %绘图时的dB下限

end

