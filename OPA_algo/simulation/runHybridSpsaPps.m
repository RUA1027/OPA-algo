function result = runHybridSpsaPps(state, cfgHybrid, measureFn)
%RUNHYBRIDSPSAPPS Two-stage hybrid calibration: SPSA coarse + PPS fine.
%
%   result = runHybridSpsaPps(state, cfgHybrid, measureFn)
%
%   Stage 1: SPSA rapidly reduces phase errors across all channels.
%   Stage 2: Per-channel phase stepping (3/4/5-step) refines each channel
%            starting from the SPSA solution.

arguments
    state     (1,1) struct
    cfgHybrid (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
omega       = state.phasePerU;
u2pi        = state.u2pi;
uMin        = cfgHybrid.controlMin;
uMax        = cfgHybrid.controlMax;

%% ========== Stage 1: SPSA coarse tuning ==========
spsaCfg = cfgHybrid.spsa;
spsaMaxIter = spsaCfg.maxIter;

spsaSeed = 2024;
if isfield(spsaCfg, 'spsaSeed'), spsaSeed = spsaCfg.spsaSeed; end
stream = RandStream('mt19937ar', 'Seed', spsaSeed);

controlU      = state.initialControlU;
bestControlU  = controlU;
bestIntensity = computeTargetIntensity(controlU, state);
spsaEvalCount = 0;

a0    = spsaCfg.a0;
c0    = spsaCfg.c0;
alpha = spsaCfg.alpha;
gamma = spsaCfg.gamma;
A     = spsaCfg.stabilityConst;

spsaTrueHist = zeros(1, spsaMaxIter);

for k = 1:spsaMaxIter
    ak = a0 / (k + A)^alpha;
    ck = c0 / (k)^gamma;

    delta  = 2 * (rand(stream, 1, numChannels) > 0.5) - 1;
    uPlus  = min(max(controlU + ck * delta, uMin), uMax);
    uMinus = min(max(controlU - ck * delta, uMin), uMax);

    Iplus  = measureFn(uPlus);
    Iminus = measureFn(uMinus);
    spsaEvalCount = spsaEvalCount + 2;

    gHat = (Iplus - Iminus) ./ (2 * ck * delta);
    controlU = min(max(controlU + ak * gHat, uMin), uMax);

    trueInt = computeTargetIntensity(controlU, state);
    spsaTrueHist(k) = trueInt;
    if trueInt > bestIntensity
        bestControlU  = controlU;
        bestIntensity = trueInt;
    end
end

spsaFinalIntensity = bestIntensity;

%% ========== Stage 2: PPS fine tuning ==========
ppsCfg    = cfgHybrid.pps;
ppsSteps  = ppsCfg.ppsSteps;
ppsRounds = ppsCfg.maxRounds;
avgCount  = 1;
if isfield(ppsCfg, 'averagingCount'), avgCount = ppsCfg.averagingCount; end

if isfield(ppsCfg, 'channelSchedule')
    ppsSchedule = ppsCfg.channelSchedule;
else
    ppsSchedule = repmat(1:numChannels, ppsRounds, 1);
end
if size(ppsSchedule, 1) < ppsRounds
    ppsSchedule = repmat(1:numChannels, ppsRounds, 1);
end

controlU      = bestControlU;  % start from SPSA best
ppsEvalCount  = 0;
prevRoundIntensity = bestIntensity;

ppsRoundIntensity = zeros(1, ppsRounds);
ppsRoundEval      = zeros(1, ppsRounds);
ppsRoundAccepted  = false(1, ppsRounds);

for roundIdx = 1:ppsRounds
    channelOrder     = ppsSchedule(roundIdx, :);
    evalStart        = ppsEvalCount;
    controlUBefore   = controlU;

    for orderIdx = 1:numChannels
        ch = channelOrder(orderIdx);
        [uOpt, localEval] = iPpsByChannel( ...
            controlU, ch, ppsSteps, omega, u2pi, uMin, uMax, measureFn, avgCount);
        controlU(ch) = uOpt;
        ppsEvalCount = ppsEvalCount + localEval;
    end

    roundCandidateIntensity = computeTargetIntensity(controlU, state);
    if roundCandidateIntensity < prevRoundIntensity
        controlU = controlUBefore;
        ppsRoundIntensity(roundIdx) = prevRoundIntensity;
        ppsRoundAccepted(roundIdx)  = false;
    else
        prevRoundIntensity = roundCandidateIntensity;
        ppsRoundIntensity(roundIdx) = roundCandidateIntensity;
        ppsRoundAccepted(roundIdx)  = true;
    end
    ppsRoundEval(roundIdx) = ppsEvalCount - evalStart;
end

%% ========== Assemble output ==========
numLogicalRounds = 4;
if isfield(cfgHybrid, 'numLogicalRounds')
    numLogicalRounds = cfgHybrid.numLogicalRounds;
end

% Split SPSA iterations into (numLogicalRounds - ppsRounds) logical rounds
spsaLogicalRounds = max(numLogicalRounds - ppsRounds, 1);
itersPerSpsaRound = ceil(spsaMaxIter / spsaLogicalRounds);

roundTargetIntensityTrue = zeros(1, numLogicalRounds);
roundEvalCount           = zeros(1, numLogicalRounds);
roundAccepted            = false(1, numLogicalRounds);

initIntensity = computeTargetIntensity(state.initialControlU, state);
prevLogical   = initIntensity;

for r = 1:spsaLogicalRounds
    idxEnd = min(r * itersPerSpsaRound, spsaMaxIter);
    if idxEnd >= 1
        roundTargetIntensityTrue(r) = spsaTrueHist(idxEnd);
        if r == 1
            roundEvalCount(r) = idxEnd * 2;
        else
            roundEvalCount(r) = max(idxEnd - (r-1) * itersPerSpsaRound, 0) * 2;
        end
    end
    if roundTargetIntensityTrue(r) >= prevLogical
        roundAccepted(r) = true;
        prevLogical = roundTargetIntensityTrue(r);
    end
end

for r = 1:ppsRounds
    idx = spsaLogicalRounds + r;
    if idx <= numLogicalRounds
        roundTargetIntensityTrue(idx) = ppsRoundIntensity(r);
        roundEvalCount(idx)           = ppsRoundEval(r);
        roundAccepted(idx)            = ppsRoundAccepted(r);
    end
end

result = struct();
result.method                   = "Hybrid-SPSA-PPS";
result.controlU                 = controlU;
result.evalCount                = spsaEvalCount + ppsEvalCount;
result.roundCount               = numLogicalRounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.roundEvalCount           = roundEvalCount;
result.roundAccepted            = roundAccepted;

result.spsaPhase = struct();
result.spsaPhase.evalCount      = spsaEvalCount;
result.spsaPhase.actualIter     = spsaMaxIter;
result.spsaPhase.finalIntensity = spsaFinalIntensity;

result.ppsPhase = struct();
result.ppsPhase.evalCount = ppsEvalCount;
result.ppsPhase.rounds    = ppsRounds;

end

%% ---- internal: PPS per channel (supports 3/4/5 steps) ----
function [uOpt, evalCount] = iPpsByChannel(controlU, channelIdx, ppsSteps, omega, u2pi, uMin, uMax, measureFn, avgCount)

deltaU = u2pi / 4;   % quarter-period step
uCur   = controlU(channelIdx);

switch ppsSteps
    case 3
        % Three-step phase shifting
        samplePoints = uCur + [-1, 0, 1] * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn, avgCount);
        evalCount = 3 * avgCount;

        if all(I == I(1))
            uOpt = uCur; return;
        end

        u0_centre = samplePoints(2);
        phi0 = atan2(I(1) - I(3), 2*I(2) - I(1) - I(3));

    case 4
        % Four-step phase shifting (simplified, pi/2 spacing)
        samplePoints = uCur + [-1.5, -0.5, 0.5, 1.5] * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn, avgCount);
        evalCount = 4 * avgCount;

        if all(I == I(1))
            uOpt = uCur; return;
        end

        u0_centre = mean(samplePoints(2:3));  % midpoint
        phi0 = atan2(I(4) - I(2), I(1) - I(3));

    case 5
        % Five-step Schwider-Hariharan
        samplePoints = uCur + (-2:2) * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn, avgCount);
        evalCount = 5 * avgCount;

        if all(I == I(1))
            uOpt = uCur; return;
        end

        u0_centre = samplePoints(3);
        phi0 = atan2(2*(I(2) - I(4)), 2*I(3) - I(5) - I(1));

    otherwise
        error('opa_sim:runHybridSpsaPps:BadPpsSteps', 'ppsSteps must be 3, 4, or 5.');
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

function I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn, avgCount)
    nPts = numel(samplePoints);
    I = zeros(1, nPts);
    for j = 1:nPts
        accum = 0;
        for a = 1:avgCount
            candidate = controlU;
            candidate(channelIdx) = samplePoints(j);
            accum = accum + measureFn(candidate);
        end
        I(j) = accum / avgCount;
    end
end
