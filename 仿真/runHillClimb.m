function result = runHillClimb(state, cfgHillClimb, measureFn)
%RUNHILLCLIMB Hill-climbing calibration with per-channel dense grid search.
%
%   result = runHillClimb(state, cfgHillClimb, measureFn)
%
% Per-channel strategy:
%   Discretize control range [controlMin, controlMax] into K uniform grid
%   points, measure intensity at each grid point, set channel control to
%   the grid point yielding maximum intensity.
% Multi-round: grid density refines round by round (gridPointsByRound).

arguments
    state (1,1) struct
    cfgHillClimb (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxRounds   = cfgHillClimb.maxRounds;

if isfield(cfgHillClimb, "channelSchedule")
    schedule = cfgHillClimb.channelSchedule;
else
    schedule = repmat(1:numChannels, maxRounds, 1);
end

if size(schedule, 1) < maxRounds || size(schedule, 2) ~= numChannels
    error("opa_sim:runHillClimb:InvalidSchedule", "Invalid channelSchedule size.");
end

gridPointsByRound = cfgHillClimb.gridPointsByRound(:).';
uMin = cfgHillClimb.controlMin;
uMax = cfgHillClimb.controlMax;

controlU = state.initialControlU;
evalCount = 0;

roundTargetIntensityTrue = zeros(1, maxRounds);
roundEvalCount           = zeros(1, maxRounds);
roundAccepted            = false(1, maxRounds);

prevRoundIntensity = computeTargetIntensity(controlU, state);

for roundIdx = 1:maxRounds
    K = gridPointsByRound(min(roundIdx, numel(gridPointsByRound)));

    % Determine search window for this round
    if roundIdx == 1 || ~isfield(cfgHillClimb, "shrinkWindow") || ~cfgHillClimb.shrinkWindow
        % Full range search
        roundUMin = uMin * ones(1, numChannels);
        roundUMax = uMax * ones(1, numChannels);
    else
        % Shrink window around current best per channel
        prevK = gridPointsByRound(min(roundIdx - 1, numel(gridPointsByRound)));
        windowHalf = (uMax - uMin) / prevK;
        roundUMin = max(controlU - windowHalf, uMin);
        roundUMax = min(controlU + windowHalf, uMax);
    end

    channelOrder = schedule(roundIdx, :);
    evalCountStart = evalCount;
    controlUBeforeRound = controlU;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);
        [uNew, localEval] = iHillClimbChannelGrid( ...
            controlU, channelIdx, K, ...
            roundUMin(channelIdx), roundUMax(channelIdx), measureFn);
        controlU(channelIdx) = uNew;
        evalCount = evalCount + localEval;
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
result.method                   = "Hill-Climb";
result.controlU                 = controlU;
result.evalCount                = evalCount;
result.roundCount               = maxRounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.roundEvalCount           = roundEvalCount;
result.roundAccepted            = roundAccepted;

result = attachSimulationMetrics(result, state);

end

function [uOpt, evalCount] = iHillClimbChannelGrid(controlU, channelIdx, K, uMin, uMax, measureFn)
%IHILLCLIMBCHANNELGRID Dense grid search on a single channel.

if uMax <= uMin
    uOpt = controlU(channelIdx);
    evalCount = 0;
    return;
end

gridPoints = linspace(uMin, uMax, K);
intensities = zeros(1, K);

for j = 1:K
    candidate = controlU;
    candidate(channelIdx) = gridPoints(j);
    intensities(j) = measureFn(candidate);
end

[~, bestIdx] = max(intensities);
uOpt = gridPoints(bestIdx);
evalCount = K;

end