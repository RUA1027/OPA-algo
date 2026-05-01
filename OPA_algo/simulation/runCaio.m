function result = runCaio(state, cfgCaio, measureFn)
%RUNCAIO Crosstalk-Aware Interleaved Optimization for OPA calibration.
%
%   result = runCaio(state, cfgCaio, measureFn)
%
%   Exploits the bipartite topology of first-order nearest-neighbour
%   crosstalk: odd and even channels do not directly couple. Each round
%   consists of two half-steps (odd group then even group). An optional
%   analytic crosstalk post-compensation corrects residual inter-half-step
%   coupling at zero measurement cost.

arguments
    state    (1,1) struct
    cfgCaio  (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxRounds   = cfgCaio.maxRounds;
ppsSteps    = cfgCaio.ppsSteps;
omega       = state.phasePerU;
u2pi        = state.u2pi;
uMin        = cfgCaio.controlMin;
uMax        = cfgCaio.controlMax;
enableCtComp = cfgCaio.enableCtCompensation;
ct          = state.crossTalkRatio;

if isfield(cfgCaio, 'channelSchedule')
    schedule = cfgCaio.channelSchedule;
else
    schedule = repmat(1:numChannels, maxRounds, 1);
end
if size(schedule, 1) < maxRounds || size(schedule, 2) ~= numChannels
    schedule = repmat(1:numChannels, maxRounds, 1);
end

controlU  = state.initialControlU;
evalCount = 0;

roundTargetIntensityTrue = zeros(1, maxRounds);
roundEvalCount           = zeros(1, maxRounds);
roundAccepted            = false(1, maxRounds);
halfStepIntensity        = zeros(1, 2 * maxRounds);
ctCorrectionApplied      = false(1, maxRounds);

prevRoundIntensity = computeTargetIntensity(controlU, state);

for roundIdx = 1:maxRounds
    channelOrder     = schedule(roundIdx, :);
    evalCountStart   = evalCount;
    controlUBeforeRound = controlU;

    % Split channels by parity
    oddChannels  = channelOrder(mod(channelOrder, 2) == 1);
    evenChannels = channelOrder(mod(channelOrder, 2) == 0);

    % --- Half-step A: optimise odd channels ---
    controlUBeforeOdd = controlU;
    for ch = oddChannels
        [uOpt, localEval] = iPpsByChannel( ...
            controlU, ch, ppsSteps, omega, u2pi, uMin, uMax, measureFn);
        controlU(ch) = uOpt;
        evalCount = evalCount + localEval;
    end
    halfStepIntensity(2*roundIdx - 1) = computeTargetIntensity(controlU, state);

    % --- Half-step B: optimise even channels ---
    controlUBeforeEven = controlU;
    for ch = evenChannels
        [uOpt, localEval] = iPpsByChannel( ...
            controlU, ch, ppsSteps, omega, u2pi, uMin, uMax, measureFn);
        controlU(ch) = uOpt;
        evalCount = evalCount + localEval;
    end
    halfStepIntensity(2*roundIdx) = computeTargetIntensity(controlU, state);

    % --- Optional crosstalk post-compensation for odd channels ---
    % Odd channels were optimised when even channels had old values;
    % now even channels have been updated. Correct the residual.
    if enableCtComp
        for ch = 1:2:numChannels
            deltaNeighbor = 0;
            if ch > 1
                deltaNeighbor = deltaNeighbor + (controlU(ch-1) - controlUBeforeEven(ch-1));
            end
            if ch < numChannels
                deltaNeighbor = deltaNeighbor + (controlU(ch+1) - controlUBeforeEven(ch+1));
            end
            correction = ct * deltaNeighbor;
            controlU(ch) = min(max(controlU(ch) - correction, uMin), uMax);
        end
        ctCorrectionApplied(roundIdx) = true;
    end

    % Round-wise rollback protection
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
result.method                   = "CAIO";
result.controlU                 = controlU;
result.evalCount                = evalCount;
result.roundCount               = maxRounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.halfStepIntensity        = halfStepIntensity;
result.roundEvalCount           = roundEvalCount;
result.roundAccepted            = roundAccepted;
result.ctCorrectionApplied      = ctCorrectionApplied;

end

%% ---- internal: PPS per channel (supports 3/4/5 steps) ----
function [uOpt, evalCount] = iPpsByChannel(controlU, channelIdx, ppsSteps, omega, u2pi, uMin, uMax, measureFn)

deltaU = u2pi / 4;
uCur   = controlU(channelIdx);

switch ppsSteps
    case 3
        samplePoints = uCur + [-1, 0, 1] * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn);
        evalCount = 3;

        if all(I == I(1)), uOpt = uCur; return; end

        u0_centre = samplePoints(2);
        phi0 = atan2(I(1) - I(3), 2*I(2) - I(1) - I(3));

    case 4
        samplePoints = uCur + [-1.5, -0.5, 0.5, 1.5] * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn);
        evalCount = 4;

        if all(I == I(1)), uOpt = uCur; return; end

        u0_centre = mean(samplePoints(2:3));
        phi0 = atan2(I(4) - I(2), I(1) - I(3));

    case 5
        samplePoints = uCur + (-2:2) * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn);
        evalCount = 5;

        if all(I == I(1)), uOpt = uCur; return; end

        u0_centre = samplePoints(3);
        phi0 = atan2(2*(I(2) - I(4)), 2*I(3) - I(5) - I(1));

    otherwise
        error('opa_sim:runCaio:BadPpsSteps', 'ppsSteps must be 3, 4, or 5.');
end

uOpt = u0_centre - phi0 / omega;
uOpt = mod(uOpt - uMin, u2pi) + uMin;
if uOpt > uMax
    uOpt = uMin;
end

end

%% ---- helpers ----
function pts = iShiftWindow(pts, uMin, uMax)
    if pts(1) < uMin
        pts = pts + (uMin - pts(1));
    end
    if pts(end) > uMax
        pts = pts - (pts(end) - uMax);
    end
end

function I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn)
    nPts = numel(samplePoints);
    I = zeros(1, nPts);
    for j = 1:nPts
        candidate = controlU;
        candidate(channelIdx) = samplePoints(j);
        I(j) = measureFn(candidate);
    end
end
