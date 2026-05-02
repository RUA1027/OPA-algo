function result = exp_run_pfpd(state, cfgPfpd, measureFn)
%EXP_RUN_PFPD Experiment-side phase-fitting peak detection.

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
    error("opa_exp:exp_run_pfpd:InvalidSchedule", "Invalid channelSchedule size.");
end

controlU = state.initialControlU;
evalCount = 0;
fitFailureCount = 0;

roundIntensityMeasured = zeros(1, rounds);
roundEvalCount = zeros(1, rounds);
roundAccepted = false(1, rounds);

uSamplesBase = linspace(cfgPfpd.controlMin, cfgPfpd.controlMax, cfgPfpd.numFitSamples);

[initialIntensityMeasured, ~] = exp_measure_with_info(measureFn, controlU);
evalCount = evalCount + 1;
displayState = exp_init_realtime_display(exp_get_realtime_display_cfg(cfgPfpd), initialIntensityMeasured);

for roundIdx = 1:rounds
    channelOrder = schedule(roundIdx, :);
    evalCountStart = evalCount;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);
        controlUBeforeChannel = controlU;

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

        candidateControlU = controlU;
        candidateControlU(channelIdx) = uOpt;
        prevAcceptedIntensity = displayState.intensityHistory(end);
        [controlU, channelIntensity, channelSensorInfo, acceptEval] = exp_apply_legacy_channel_acceptance( ...
            controlUBeforeChannel, candidateControlU, prevAcceptedIntensity, measureFn);
        evalCount = evalCount + acceptEval;
        progressInfo = iBuildProgressInfo(roundIdx, channelIdx, orderIdx, "PFPD");
        displayState = exp_update_realtime_display(displayState, channelIntensity, channelSensorInfo, controlU, progressInfo);
    end

    prevRoundIntensity = displayState.intensityHistory(end);
    roundIntensityMeasured(roundIdx) = prevRoundIntensity;
    roundAccepted(roundIdx) = true;

    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method = "PFPD";
result.controlU = controlU;
result.evalCount = evalCount;
result.roundCount = rounds;
result.initialIntensityMeasured = initialIntensityMeasured;
result.roundIntensityMeasured = roundIntensityMeasured;
result.roundEvalCount = roundEvalCount;
result.fitFailureCount = fitFailureCount;
result.roundAccepted = roundAccepted;
result = exp_attach_display_metrics(result, displayState);
result.voltage_calibration_best = iControlUToVoltage(displayState.bestControlU);

end

function [uOpt, fitSuccess] = iFitPeakControl(uSamples, ySamples, uMin, uMax, fitGridPoints)

fitSuccess = false;

uSamples = double(uSamples(:).');
ySamples = double(ySamples(:).');

[~, sampleMaxIdx] = max(ySamples);
uFallback = uSamples(sampleMaxIdx);
uOpt = uFallback;

if numel(unique(ySamples)) < 3
    return;
end

uRange = max(uMax - uMin, eps);
d0 = (ySamples(end) - ySamples(1)) / uRange;
e0 = mean(ySamples);
detrended = ySamples - (d0 * uSamples + e0);
a0 = 0.5 * (max(detrended) - min(detrended));
a0 = max(a0, eps);
b0 = 2 * pi / uRange;
c0 = 0;
p0 = [a0, b0, c0, d0, e0];

model = @(p, u) p(1) .* cos(p(2) .* u + p(3)) + p(4) .* u + p(5);
loss = @(p) sum((model(p, uSamples) - ySamples) .^ 2);

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

function progressInfo = iBuildProgressInfo(roundIdx, channelIdx, orderIdx, methodName)
progressInfo = struct();
progressInfo.roundIdx = roundIdx;
progressInfo.channelIdx = channelIdx;
progressInfo.orderIdx = orderIdx;
progressInfo.methodName = string(methodName);
end

function voltage = iControlUToVoltage(controlU)
if isempty(controlU)
    voltage = [];
else
    voltage = sqrt(max(controlU, 0));
end
end
