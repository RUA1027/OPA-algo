function result = runMrevGss(state, cfgMrevGss, measureFn)
%RUNMREVGSS mREV with golden-section search per channel.
%
% Stopping rule per channel:
%   stop when spacing between the two sampled points is < gapTol.

arguments
    state (1,1) struct
    cfgMrevGss (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxRounds = cfgMrevGss.maxRounds;

if isfield(cfgMrevGss, "channelSchedule")
    schedule = cfgMrevGss.channelSchedule;
else
    schedule = repmat(1:numChannels, maxRounds, 1);
end

if size(schedule, 1) < maxRounds || size(schedule, 2) ~= numChannels
    error("opa_sim:runMrevGss:InvalidSchedule", "Invalid channelSchedule size.");
end

kByRound = cfgMrevGss.kByRound(:).';
L = cfgMrevGss.goldenRatio;

controlU = state.initialControlU;
evalCount = 0;

roundTargetIntensityTrue = zeros(1, maxRounds);
roundGapTol = zeros(1, maxRounds);
roundMaxTerminalGap = zeros(1, maxRounds);
roundEvalCount = zeros(1, maxRounds);
roundAccepted = false(1, maxRounds);

prevRoundIntensity = computeTargetIntensity(controlU, state);

for roundIdx = 1:maxRounds
    kThisRound = kByRound(min(roundIdx, numel(kByRound)));
    gapTol = state.u2pi * (L ^ kThisRound);

    channelOrder = schedule(roundIdx, :);
    terminalGapByChannel = zeros(1, numChannels);

    evalCountStart = evalCount;
    controlUBeforeRound = controlU;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);
        [uOpt, evalLocal, terminalGap] = iGoldenSearchByChannel( ...
            controlU, channelIdx, cfgMrevGss.controlMin, cfgMrevGss.controlMax, L, gapTol, measureFn);

        controlU(channelIdx) = uOpt;
        evalCount = evalCount + evalLocal;
        terminalGapByChannel(orderIdx) = terminalGap;
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

    roundGapTol(roundIdx) = gapTol;
    roundMaxTerminalGap(roundIdx) = max(terminalGapByChannel);
    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method = "mREV-GSS";
result.controlU = controlU;
result.evalCount = evalCount;
result.roundCount = maxRounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.roundGapTol = roundGapTol;
result.roundMaxTerminalGap = roundMaxTerminalGap;
result.roundEvalCount = roundEvalCount;
result.roundAccepted = roundAccepted;

end

function [uOpt, evalCount, terminalGap] = iGoldenSearchByChannel(controlU, channelIdx, uMin, uMax, L, gapTol, measureFn)
a = uMin;
b = uMax;
x1 = b - L * (b - a);
x2 = a + L * (b - a);

y1 = iEvaluateAt(controlU, channelIdx, x1, measureFn);
y2 = iEvaluateAt(controlU, channelIdx, x2, measureFn);
evalCount = 2;

while abs(x2 - x1) >= gapTol
    if y1 >= y2
        b = x2;
        x2 = x1;
        y2 = y1;
        x1 = b - L * (b - a);
        y1 = iEvaluateAt(controlU, channelIdx, x1, measureFn);
    else
        a = x1;
        x1 = x2;
        y1 = y2;
        x2 = a + L * (b - a);
        y2 = iEvaluateAt(controlU, channelIdx, x2, measureFn);
    end
    evalCount = evalCount + 1;
end

if y1 >= y2
    uOpt = x1;
else
    uOpt = x2;
end

terminalGap = abs(x2 - x1);

end

function value = iEvaluateAt(controlU, channelIdx, uValue, measureFn)
candidate = controlU;
candidate(channelIdx) = uValue;
value = measureFn(candidate);
end
