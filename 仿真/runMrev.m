function result = runMrev(state, cfgMrev, measureFn)
%RUNMREV mREV without golden-section search.
%
% Per-channel strategy:
%   evaluate a uniform grid with spacing controlled by gapTol,
%   then keep the best sampled point.
% Across rounds:
%   keep using the full control vector from the previous round as current
%   working point.

arguments
    state (1,1) struct
    cfgMrev (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxRounds = cfgMrev.maxRounds;

if isfield(cfgMrev, "channelSchedule")
    schedule = cfgMrev.channelSchedule;
else
    schedule = repmat(1:numChannels, maxRounds, 1);
end

if size(schedule, 1) < maxRounds || size(schedule, 2) ~= numChannels
    error("opa_sim:runMrev:InvalidSchedule", "Invalid channelSchedule size.");
end

kByRound = cfgMrev.kByRound(:).';
L = cfgMrev.shrinkRatio; % 缩小系数（仅用于步长衰减，不是GSS）

% 初始控制量：来自 state（当前已是随机初始化）
controlU = state.initialControlU;
evalCount = 0;

% 预分配记录量
roundTargetIntensityTrue = zeros(1, maxRounds);
roundGapTol = zeros(1, maxRounds);
roundGridStep = zeros(1, maxRounds);
roundEvalCount = zeros(1, maxRounds);
roundAccepted = false(1, maxRounds);

% 与上一轮对比用的目标强度（初始工作点）
prevRoundIntensity = computeTargetIntensity(controlU, state);

for roundIdx = 1:maxRounds
    % 每轮按 kByRound 设定步长精度（防御性写法：超过长度时用最后一个k）
    kThisRound = kByRound(min(roundIdx, numel(kByRound)));
    gapTol = state.u2pi * (L ^ kThisRound); % 计算本轮扫描步长

    channelOrder = schedule(roundIdx, :);      % 本轮通道扫描顺序
    gridStepsThisRound = zeros(1, numChannels);% 记录每个通道实际步长

    evalCountStart = evalCount;
    controlUBeforeRound = controlU;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);

        % 单通道扫描（不设采样上限，直接按步长遍历全区间）
        [uOpt, evalLocal, gridStepUsed] = iGridSearchByChannel( ...
            controlU, channelIdx, cfgMrev.controlMin, cfgMrev.controlMax, gapTol, measureFn);

        controlU(channelIdx) = uOpt;            % 更新该通道最优值
        evalCount = evalCount + evalLocal;      % 记录采样次数
        gridStepsThisRound(orderIdx) = gridStepUsed;
    end

    roundCandidateIntensity = computeTargetIntensity(controlU, state);

    % 若本轮效果不如上一轮，则回退到上一轮整组电压
    if roundCandidateIntensity < prevRoundIntensity
        controlU = controlUBeforeRound;
        roundTargetIntensityTrue(roundIdx) = prevRoundIntensity;
        roundAccepted(roundIdx) = false;
    else
        prevRoundIntensity = roundCandidateIntensity;
        roundTargetIntensityTrue(roundIdx) = roundCandidateIntensity;
        roundAccepted(roundIdx) = true;
    end

    % 注意：下一轮不会重置 controlU，沿用当前（可能已回退）整组电压继续优化
    roundGapTol(roundIdx) = gapTol;
    roundGridStep(roundIdx) = max(gridStepsThisRound);
    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method = "mREV";
result.controlU = controlU;
result.evalCount = evalCount;
result.roundCount = maxRounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.roundGapTol = roundGapTol;
result.roundGridStep = roundGridStep;
result.roundEvalCount = roundEvalCount;
result.roundAccepted = roundAccepted;

result = attachSimulationMetrics(result, state);

end

function [uOpt, evalCount, gridStepUsed] = iGridSearchByChannel(controlU, channelIdx, uMin, uMax, gapTol, measureFn)
% 构造均匀候选网格
gridU = uMin:gapTol:uMax;
if isempty(gridU)
    gridU = [uMin, uMax];
elseif gridU(end) < uMax
    gridU(end+1) = uMax;
end

% 记录本通道实际步长
if numel(gridU) >= 2
    gridStepUsed = max(diff(gridU));
else
    gridStepUsed = uMax - uMin;
end

% 遍历候选点，比较目标函数
% 其余通道固定，仅扫描当前通道
y = zeros(1, numel(gridU));
for idx = 1:numel(gridU)
    candidate = controlU;
    candidate(channelIdx) = gridU(idx);
    y(idx) = measureFn(candidate);
end

% 取本通道最佳点
[~, idxBest] = max(y);
uOpt = gridU(idxBest);
evalCount = numel(gridU);

end
