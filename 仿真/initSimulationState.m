function state = initSimulationState(cfg)
%INITSIMULATIONSTATE Initialize 1D OPA simulation state from configuration.
%
% Input:
%   cfg (struct) Configuration from defaultConfig.
% Output:
%   state (struct) Immutable simulation state shared by calibration methods.

arguments
    cfg (1,1) struct
end

% 检查通道数合法性
validateattributes(cfg.sim.numChannels, {'numeric'}, {'scalar', 'integer', '>=', 2});

numChannels = cfg.sim.numChannels;

% 读取阵元间距（优先读 d1.mat，失败则用默认间距）
dM = iLoadSpacingMeters(cfg.sim.dFilePath, cfg.sim.dVarName, numChannels, cfg.sim.defaultSpacingM);

% 根据间距构造阵元坐标，并以阵列中心为零点
xPositionsM = zeros(1, numChannels);
xPositionsM(2:end) = cumsum(dM);
xPositionsM = xPositionsM - mean(xPositionsM);

% 设定随机种子，保证可复现
rng(cfg.general.seed, "twister");

% 随机本征相位：模拟工艺误差导致的通道相位偏差
intrinsicPhaseRad = 2 * pi * rand(1, numChannels);

% 通道振幅：根据配置决定是否启用振幅不均匀性
% 使用独立RandStream，避免干扰后续intrinsicPhaseRad和initialControlU的随机序列
if cfg.sim.enableAmpNonuniformity
    ampStream = RandStream("mt19937ar", "Seed", cfg.general.seed + 500);
    ampRaw = 1 + cfg.sim.ampNonuniformityStd * randn(ampStream, 1, numChannels);
    amplitude = max(ampRaw, 0.01);  % 截断为正数，物理上不存在负振幅
else
    amplitude = ones(1, numChannels);  % 各通道振幅均匀
end

state = struct();
state.numChannels = numChannels;
state.lambdaM = cfg.sim.wavelengthM;
state.k = 2 * pi / state.lambdaM;

% 角度网格与目标角
state.thetaGridDeg = cfg.sim.thetaGridDeg(:).';
state.targetThetaDeg = cfg.sim.targetThetaDeg;
state.targetUSin = sind(state.targetThetaDeg);

% 阵列几何和本征参数
state.xPositionsM = xPositionsM;
state.amplitude = amplitude;
state.intrinsicPhaseRad = intrinsicPhaseRad;

% 控制量范围：u ~ V^2
state.u2pi = cfg.sim.u2pi;
state.controlMin = cfg.sim.controlMin;
state.controlMax = cfg.sim.controlMax;

% 每单位控制量引起的相位变化斜率
state.phasePerU = 2 * pi / state.u2pi;

% 热串扰系数（邻道耦合）
state.crossTalkRatio = cfg.sim.crossTalkRatio;

% 初始控制电压（你要求改为随机初始化）
state.initialControlU = state.controlMin + ...
    (state.controlMax - state.controlMin) .* rand(1, numChannels);

% 理论最大强度上限（用于量化满量程默认值）
state.maxTheoreticalIntensity = (sum(amplitude))^2;

% 光学串扰配置（波导间近场耦合，在computeFarField/computeTargetIntensity中使用）
state.opticalCrosstalk = cfg.sim.opticalCrosstalk;

% DAC配置（量化在mapControlToPhase中使用，驱动噪声在makeMeasureFunction中使用）
state.dac = cfg.sim.dac;

end

% 读入间距函数
function dM = iLoadSpacingMeters(dFilePath, dVarName, numChannels, defaultSpacingM)
if exist(dFilePath, "file") ~= 2
    dM = defaultSpacingM * ones(1, numChannels - 1);
    return;
end

s = load(dFilePath);
if ~isfield(s, dVarName)
    dM = defaultSpacingM * ones(1, numChannels - 1);
    return;
end

dLoaded = double(s.(dVarName));
dLoaded = dLoaded(:).';
if numel(dLoaded) == numChannels - 1
    % 仓库里的 d 数据单位是 um，这里转成 m
    dM = dLoaded * 1e-6;
else
    dM = defaultSpacingM * ones(1, numChannels - 1);
end
end
