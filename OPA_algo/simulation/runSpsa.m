function result = runSpsa(state, cfgSpsa, measureFn)
%RUNSPSA Simultaneous Perturbation Stochastic Approximation for OPA calibration.
%
%   result = runSpsa(state, cfgSpsa, measureFn)
%
%   SPSA estimates the N-dimensional gradient using only 2 measurements per
%   iteration, regardless of channel count. Uses Spall's standard gain
%   sequences with best-so-far tracking.

arguments
    state   (1,1) struct
    cfgSpsa (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxIter     = cfgSpsa.maxIter;
a0          = cfgSpsa.a0;
c0          = cfgSpsa.c0;
alpha       = cfgSpsa.alpha;
gamma       = cfgSpsa.gamma;
A           = cfgSpsa.stabilityConst;
uMin        = cfgSpsa.controlMin;
uMax        = cfgSpsa.controlMax;
numLogicalRounds = cfgSpsa.numLogicalRounds;

% Early stopping parameters
doEarlyStop = false;
if isfield(cfgSpsa, 'earlyStop') && cfgSpsa.earlyStop
    doEarlyStop = true;
    esWindow    = cfgSpsa.earlyStopWindow;
    esPatience  = cfgSpsa.earlyStopPatience;
    esTolRel    = cfgSpsa.earlyStopTolRel;
end

% Independent random stream for reproducibility
spsaSeed = 2024;
if isfield(cfgSpsa, 'spsaSeed')
    spsaSeed = cfgSpsa.spsaSeed;
end
stream = RandStream('mt19937ar', 'Seed', spsaSeed);

controlU = state.initialControlU;
evalCount = 0;

% Best-so-far tracking
bestControlU  = controlU;
bestIntensity = computeTargetIntensity(controlU, state);

% Iteration history (diagnostic)
histTrueIntensity = zeros(1, maxIter);
histMeasuredDiff  = zeros(1, maxIter);
histStepSize      = zeros(1, maxIter);
histPerturbSize   = zeros(1, maxIter);

% Early stopping state
noImproveCount = 0;
recentIntensities = zeros(1, maxIter);

actualIter = 0;

for k = 1:maxIter
    actualIter = k;

    % Gain sequences (1-indexed: iteration k corresponds to Spall's k-1)
    ak = a0 / (k + A)^alpha;
    ck = c0 / (k)^gamma;

    % Bernoulli perturbation vector
    delta = 2 * (rand(stream, 1, numChannels) > 0.5) - 1;

    % Perturbed control vectors (clipped)
    uPlus  = min(max(controlU + ck * delta, uMin), uMax);
    uMinus = min(max(controlU - ck * delta, uMin), uMax);

    % Two measurements
    Iplus  = measureFn(uPlus);
    Iminus = measureFn(uMinus);
    evalCount = evalCount + 2;

    % Gradient estimate (element-wise)
    gHat = (Iplus - Iminus) ./ (2 * ck * delta);

    % Gradient ascent update (maximise intensity)
    controlU = min(max(controlU + ak * gHat, uMin), uMax);

    % True intensity for tracking (not counted in evalCount)
    trueInt = computeTargetIntensity(controlU, state);

    if trueInt > bestIntensity
        bestControlU  = controlU;
        bestIntensity = trueInt;
    end

    % Record history
    histTrueIntensity(k) = trueInt;
    histMeasuredDiff(k)  = Iplus - Iminus;
    histStepSize(k)      = ak;
    histPerturbSize(k)   = ck;
    recentIntensities(k) = trueInt;

    % Early stopping check
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

% Trim history to actual iterations
histTrueIntensity = histTrueIntensity(1:actualIter);
histMeasuredDiff  = histMeasuredDiff(1:actualIter);
histStepSize      = histStepSize(1:actualIter);
histPerturbSize   = histPerturbSize(1:actualIter);

% Build logical-round summary for compatibility
itersPerRound = ceil(actualIter / numLogicalRounds);
roundTargetIntensityTrue = zeros(1, numLogicalRounds);
roundEvalCount           = zeros(1, numLogicalRounds);
roundAccepted            = false(1, numLogicalRounds);
prevLogicalIntensity     = computeTargetIntensity(state.initialControlU, state);

for r = 1:numLogicalRounds
    idxEnd = min(r * itersPerRound, actualIter);
    if idxEnd >= 1
        roundTargetIntensityTrue(r) = histTrueIntensity(idxEnd);
        if r == 1
            roundEvalCount(r) = idxEnd * 2;
        else
            roundEvalCount(r) = max(idxEnd - (r-1) * itersPerRound, 0) * 2;
        end
    end
    if roundTargetIntensityTrue(r) >= prevLogicalIntensity
        roundAccepted(r) = true;
        prevLogicalIntensity = roundTargetIntensityTrue(r);
    end
end

% Output
result = struct();
result.method                   = "SPSA";
result.controlU                 = bestControlU;
result.evalCount                = evalCount;
result.roundCount               = numLogicalRounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.roundEvalCount           = roundEvalCount;
result.roundAccepted            = roundAccepted;

result.iterHistory = struct();
result.iterHistory.trueIntensity = histTrueIntensity;
result.iterHistory.measuredDiff  = histMeasuredDiff;
result.iterHistory.stepSize      = histStepSize;
result.iterHistory.perturbSize   = histPerturbSize;
result.actualIter                = actualIter;

end
