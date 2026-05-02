function cfg = defaultConfig()
%DEFAULTCONFIG Default configuration for 1D OPA calibration simulation.
%
% Simplified physics model (论文基准配置):
%   1. 随机初始相位误差  — 均匀分布 U(0, 2π)，模拟工艺误差
%   2. 测量噪声           — 加性高斯噪声，幅度 = relativeNoiseStd * max(signal, 1)
%   3. 其他非核心扰动     — 默认关闭，仅保留配置入口用于消融实验
%
% 已禁用的物理模型 (可通过修改 cfg 重新开启):
%   - 阵元振幅不均匀性     (cfg.sim.enableAmpNonuniformity = false)
%   - DAC 量化与驱动噪声   (cfg.sim.dac.enable = false)
%   - 热串扰              (cfg.sim.crossTalkRatio = 0)
%   - 光学耦合串扰         (cfg.sim.opticalCrosstalk.enable = false)
%
% Output:
%   cfg (struct) Configuration used by initSimulationState, all runners,
%   main_compare_calibration, and main_beam_steering.

thisFile = mfilename("fullpath");
repoRoot = fileparts(fileparts(thisFile)); %提取根目录路径

cfg = struct();

cfg.general = struct();
cfg.general.seed = 42;

cfg.sim = struct();
cfg.sim.numChannels = 128;
cfg.sim.wavelengthM = 1.55e-6;
cfg.sim.targetThetaDeg = 10;
cfg.sim.thetaGridDeg = linspace(-10, 30, 3001);
cfg.sim.dFilePath = fullfile(repoRoot, "一维opa远场计算", "一维opa远场计算", "d1.mat"); %读取间距数据
cfg.sim.dVarName = "d"; %读取变量名d的数据

cfg.sim.defaultSpacingM = 4e-6; %默认间距为4微米，未导入d1.mat时使用。
cfg.sim.u2pi = 7.5^2;  %电压的平方上限
cfg.sim.controlMin = 0;
cfg.sim.controlMax = cfg.sim.u2pi; %搜索区间
cfg.sim.crossTalkRatio = 0;  %热串扰比率 (0 = 禁用)

% --- 干扰1：通道间振幅不均匀性 ---
% 模拟级联MMI分束器工艺波动导致的各通道功率偏差（参考 Jiao et al., APL Photonics 2025）
cfg.sim.enableAmpNonuniformity = false;  % 振幅不均匀性 (论文基准: 关闭)
cfg.sim.ampNonuniformityStd    = 0.03;   % 振幅相对标准差

% --- 干扰2：光学串扰（波导间近场耦合） ---
% 模拟相邻波导倏逝场耦合，作用于电场层面，与热串扰（作用于控制量）机制不同
cfg.sim.opticalCrosstalk = struct();
cfg.sim.opticalCrosstalk.enable        = false;     % 默认关闭
cfg.sim.opticalCrosstalk.kappaAbs      = 0.005;      % |κ|，电场耦合系数绝对值（功率耦合比 η=|κ|²）
cfg.sim.opticalCrosstalk.kappaPhaseRad = pi/2;       % κ 的相位（rad），π/2 为耦合模理论标准值

% --- 干扰3：DAC 量化与驱动电路噪声 ---
% DAC量化为确定性操作，驱动噪声为随机操作；两者均作用于驱动端（区别于测量端噪声）
cfg.sim.dac = struct();
cfg.sim.dac.enable          = false;   % DAC量化与驱动噪声 (论文基准: 关闭)
cfg.sim.dac.bits            = 12;      % DAC位数
cfg.sim.dac.driverNoiseStd  = 0;       % 驱动电路噪声标准差

cfg.measurement = struct();
cfg.measurement.enableNoise = true;        % 测量噪声 (论文基准: 开启)
cfg.measurement.relativeNoiseStd = 0.01;   % 噪声相对标准差 (1% of signal)
cfg.measurement.enableQuantization = false; % 测量ADC量化 (论文基准: 关闭)
cfg.measurement.quantizationBits = 12;     % ADC位数
cfg.measurement.quantizationMax = [];      % 量化满量程上限 ([] = 自动取信号最大值)


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
cfg.pfpd.numFitSamples = 10; %每次拟合时采14个样本点
cfg.pfpd.fitGridPoints = 201; %拟合后评估网格点数，越多越精细但计算越慢
cfg.pfpd.controlMin = cfg.sim.controlMin;
cfg.pfpd.controlMax = cfg.sim.controlMax;

% 5PPS (Five-Point Phase Stepping)
cfg.fivePps = struct();
cfg.fivePps.maxRounds = 4;
cfg.fivePps.controlMin = cfg.sim.controlMin;
cfg.fivePps.controlMax = cfg.sim.controlMax;

% SPGD (Stochastic Parallel Gradient Descent)
cfg.spgd = struct();
cfg.spgd.maxIter = 2500;
cfg.spgd.a0 = cfg.sim.u2pi * 0.1;
cfg.spgd.c0 = cfg.sim.u2pi * 0.03;
cfg.spgd.alpha = 0.602;
cfg.spgd.gamma = 0.101;
cfg.spgd.stabilityConst = 60;
cfg.spgd.earlyStop = true;
cfg.spgd.earlyStopWindow = 50;
cfg.spgd.earlyStopPatience = 100;
cfg.spgd.earlyStopTolRel = 1e-4;
cfg.spgd.spgdSeed = 2024;
cfg.spgd.numLogicalRounds = 4;
cfg.spgd.controlMin = cfg.sim.controlMin;
cfg.spgd.controlMax = cfg.sim.controlMax;

% Hill-Climbing (per-channel dense grid search)
cfg.hillClimb = struct();
cfg.hillClimb.maxRounds = 4;
cfg.hillClimb.gridPointsByRound = [32, 16];   % 每轮每通道扫描的网格点数
cfg.hillClimb.shrinkWindow = true;             % 第2轮起在当前值附近收缩窗口
cfg.hillClimb.controlMin = cfg.sim.controlMin;
cfg.hillClimb.controlMax = cfg.sim.controlMax;

cfg.beamSteering = struct();
cfg.beamSteering.startThetaDeg = 0;
cfg.beamSteering.endThetaDeg = 20;
cfg.beamSteering.stepThetaDeg = 2;
cfg.beamSteering.showFigures = true;
cfg.beamSteering.verbose = true;
cfg.beamSteering.exportMat = true;
cfg.beamSteering.exportCsv = true;
cfg.beamSteering.exportDir = fullfile(repoRoot, "beam_steering_outputs");

cfg.output = struct();
cfg.output.printSummary = true;
cfg.output.exportMat = true;
cfg.output.exportCsv = true;
cfg.output.exportFigures = true;
cfg.output.outputDir = fullfile(repoRoot, "仿真", "simulation_outputs");

cfg.plot = struct();
cfg.plot.showFigures = true;
cfg.plot.dbFloor = -40; %绘图时的dB下限

end

