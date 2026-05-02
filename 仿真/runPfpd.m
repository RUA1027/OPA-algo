function result = runPfpd(state, cfgPfpd, measureFn)
%RUNPFPD Phase-fitting peak detection with fixed rounds.
%
% Stopping rule:
%   fixed number of rounds controlled by cfgPfpd.rounds.

arguments
    state (1,1) struct
    cfgPfpd (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
rounds = cfgPfpd.rounds;

if isfield(cfgPfpd, "channelSchedule")
    schedule = cfgPfpd.channelSchedule;
else
    schedule = repmat(1:numChannels, rounds, 1);
end

if size(schedule, 1) < rounds || size(schedule, 2) ~= numChannels
    error("opa_sim:runPfpd:InvalidSchedule", "Invalid channelSchedule size.");
end

controlU = state.initialControlU;
evalCount = 0;
fitFailureCount = 0;

roundTargetIntensityTrue = zeros(1, rounds);
roundEvalCount = zeros(1, rounds);
roundAccepted = false(1, rounds);

uSamplesBase = linspace(cfgPfpd.controlMin, cfgPfpd.controlMax, cfgPfpd.numFitSamples);
prevRoundIntensity = computeTargetIntensity(controlU, state);

for roundIdx = 1:rounds
    channelOrder = schedule(roundIdx, :);
    evalCountStart = evalCount;
    controlUBeforeRound = controlU;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);

        ySamples = zeros(1, cfgPfpd.numFitSamples);
        for sampleIdx = 1:cfgPfpd.numFitSamples
            candidate = controlU;
            candidate(channelIdx) = uSamplesBase(sampleIdx);
            ySamples(sampleIdx) = measureFn(candidate);
        end
        evalCount = evalCount + cfgPfpd.numFitSamples;

        [uOpt, fitSuccess] = iFitPeakControl( ...
            uSamplesBase, ySamples, cfgPfpd.controlMin, cfgPfpd.controlMax, cfgPfpd.fitGridPoints);

        if ~fitSuccess
            fitFailureCount = fitFailureCount + 1;
        end

        controlU(channelIdx) = uOpt; %得到的最佳控制电压
    end

    roundCandidateIntensity = computeTargetIntensity(controlU, state);
    if roundCandidateIntensity < prevRoundIntensity
        controlU = controlUBeforeRound;
        roundTargetIntensityTrue(roundIdx) = prevRoundIntensity;
        roundAccepted(roundIdx) = false;
    else
        prevRoundIntensity = roundCandidateIntensity;
        roundTargetIntensityTrue(roundIdx) = roundCandidateIntensity;
        roundAccepted(roundIdx) = true;
    end

    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method = "PFPD";
result.controlU = controlU;
result.evalCount = evalCount;
result.roundCount = rounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.roundEvalCount = roundEvalCount;
result.fitFailureCount = fitFailureCount;
result.roundAccepted = roundAccepted;

result = attachSimulationMetrics(result, state);

end

function [uOpt, fitSuccess] = iFitPeakControl(uSamples, ySamples, uMin, uMax, fitGridPoints)

%防御性逻辑—————— 
fitSuccess = false;

uSamples = double(uSamples(:).');
ySamples = double(ySamples(:).');

[~, sampleMaxIdx] = max(ySamples);
uFallback = uSamples(sampleMaxIdx);
uOpt = uFallback;

if numel(unique(ySamples)) < 3
    return;
end

%-——————————

uRange = max(uMax - uMin, eps);
d0 = (ySamples(end) - ySamples(1)) / uRange;
e0 = mean(ySamples);
detrended = ySamples - (d0 * uSamples + e0);
a0 = 0.5 * (max(detrended) - min(detrended));
a0 = max(a0, eps);
b0 = 2 * pi / uRange;
c0 = 0;
p0 = [a0, b0, c0, d0, e0];

%% 拟合模型：y(u)=acos(bu+c)+du+e

model = @(p, u) p(1) .* cos(p(2) .* u + p(3)) + p(4) .* u + p(5);
loss = @(p) sum((model(p, uSamples) - ySamples).^2); %最小二乘估计

opts = optimset("Display", "off", "MaxIter", 300, "MaxFunEvals", 800);
[pBest, ~, exitflag] = fminsearch(loss, p0, opts);

if exitflag <= 0 || ~all(isfinite(pBest))
    return;
end

uGrid = linspace(uMin, uMax, fitGridPoints);
yGrid = model(pBest, uGrid);
if ~all(isfinite(yGrid))
    return;
end

[~, idxMax] = max(yGrid);
uOpt = uGrid(idxMax);
fitSuccess = true;

end
