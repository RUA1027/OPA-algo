function result = runSpgd(state, cfgSpgd, measureFn)
%RUNSPGD Stochastic Parallel Gradient Descent for OPA calibration.
%
%   result = runSpgd(state, cfgSpgd, measureFn)
%
% Implementation notes:
%   - Bernoulli(+/-1) perturbation for SPSA-style gradient estimation
%   - Gradient is normalized by max absolute component before update
%   - Each iteration uses exactly 2 measurements

arguments
    state (1,1) struct
    cfgSpgd (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxIter     = cfgSpgd.maxIter;
a0          = cfgSpgd.a0;
c0          = cfgSpgd.c0;
alpha       = cfgSpgd.alpha;
gamma       = cfgSpgd.gamma;
A           = cfgSpgd.stabilityConst;
uMin        = cfgSpgd.controlMin;
uMax        = cfgSpgd.controlMax;
numLogicalRounds = cfgSpgd.numLogicalRounds;

doEarlyStop = false;
if isfield(cfgSpgd, "earlyStop") && cfgSpgd.earlyStop
    doEarlyStop = true;
    esWindow   = cfgSpgd.earlyStopWindow;
    esPatience = cfgSpgd.earlyStopPatience;
    esTolRel   = cfgSpgd.earlyStopTolRel;
end

spgdSeed = 2024;
if isfield(cfgSpgd, "spgdSeed")
    spgdSeed = cfgSpgd.spgdSeed;
end
stream = RandStream("mt19937ar", "Seed", spgdSeed);

controlU = state.initialControlU;
evalCount = 0;

bestControlU  = controlU;
bestIntensity = computeTargetIntensity(controlU, state);

histTrueIntensity = zeros(1, maxIter);
histPerturbSize   = zeros(1, maxIter);
histStepSize      = zeros(1, maxIter);

noImproveCount = 0;
recentIntensities = zeros(1, maxIter);

actualIter = 0;

for k = 1:maxIter
    actualIter = k;

    ak = a0 / (k + A)^alpha;
    ck = c0 / (k)^gamma;

    delta = 2 * (rand(stream, 1, numChannels) > 0.5) - 1;

    uPlus  = min(max(controlU + ck * delta, uMin), uMax);
    uMinus = min(max(controlU - ck * delta, uMin), uMax);

    Iplus  = measureFn(uPlus);
    Iminus = measureFn(uMinus);
    evalCount = evalCount + 2;

    % Sign-based SPGD gradient: direction only, magnitude via ak
    deltaJ = Iplus - Iminus;
    gHat = sign(deltaJ) * delta;

    % Gradient ascent update
    controlU = min(max(controlU + ak * gHat, uMin), uMax);

    trueInt = computeTargetIntensity(controlU, state);

    if trueInt > bestIntensity
        bestControlU  = controlU;
        bestIntensity = trueInt;
    end

    histTrueIntensity(k) = trueInt;
    histStepSize(k)      = ak;
    histPerturbSize(k)   = ck;
    recentIntensities(k) = trueInt;

    if doEarlyStop && k > esWindow
        currentAvg  = mean(recentIntensities(k - esWindow + 1 : k));
        previousAvg = mean(recentIntensities(max(1, k - 2*esWindow + 1) : k - esWindow));
        if previousAvg > 0 && (currentAvg - previousAvg) / abs(previousAvg) < esTolRel
            noImproveCount = noImproveCount + 1;
        else
            noImproveCount = 0;
        end
        if noImproveCount >= esPatience
            break;
        end
    end
end

histTrueIntensity = histTrueIntensity(1:actualIter);
histStepSize      = histStepSize(1:actualIter);
histPerturbSize   = histPerturbSize(1:actualIter);

itersPerRound = ceil(actualIter / numLogicalRounds);
roundTargetIntensityTrue = zeros(1, numLogicalRounds);
roundEvalCount           = zeros(1, numLogicalRounds);
roundAccepted            = false(1, numLogicalRounds);
prevLogicalIntensity     = computeTargetIntensity(state.initialControlU, state);

for r = 1:numLogicalRounds
    idxStart = (r - 1) * itersPerRound + 1;
    idxEnd = min(r * itersPerRound, actualIter);
    if idxStart <= actualIter && idxEnd >= idxStart
        roundTargetIntensityTrue(r) = histTrueIntensity(idxEnd);
        roundEvalCount(r) = 2 * (idxEnd - idxStart + 1);
    elseif actualIter >= 1
        roundTargetIntensityTrue(r) = histTrueIntensity(end);
        roundEvalCount(r) = 0;
    end
    if roundTargetIntensityTrue(r) >= prevLogicalIntensity
        roundAccepted(r) = true;
        prevLogicalIntensity = roundTargetIntensityTrue(r);
    end
end

result = struct();
result.method                   = "SPGD";
result.controlU                 = bestControlU;
result.evalCount                = evalCount;
result.roundCount               = numLogicalRounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.roundEvalCount           = roundEvalCount;
result.roundAccepted            = roundAccepted;

result.iterHistory = struct();
result.iterHistory.trueIntensity = histTrueIntensity;
result.iterHistory.stepSize      = histStepSize;
result.iterHistory.perturbSize   = histPerturbSize;
result.actualIter                = actualIter;

result = attachSimulationMetrics(result, state);

end
