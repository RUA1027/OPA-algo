function result = exp_run_mrevgss(state, cfgMrevGss, measureFn)
%EXP_RUN_MREVGSS Experiment-side mREV-GSS runner.

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
    error("opa_exp:exp_run_mrevgss:InvalidSchedule", "Invalid channelSchedule size.");
end

kByRound = cfgMrevGss.kByRound(:).';
L = cfgMrevGss.goldenRatio;

controlU = state.initialControlU;
evalCount = 0;

roundIntensityMeasured = zeros(1, maxRounds);
roundGapTol = zeros(1, maxRounds);
roundMaxTerminalGap = zeros(1, maxRounds);
roundEvalCount = zeros(1, maxRounds);
roundAccepted = false(1, maxRounds);

[initialIntensityMeasured, ~] = exp_measure_with_info(measureFn, controlU);
evalCount = evalCount + 1;
displayState = exp_init_realtime_display(exp_get_realtime_display_cfg(cfgMrevGss), initialIntensityMeasured);

for roundIdx = 1:maxRounds
    kThisRound = kByRound(min(roundIdx, numel(kByRound)));
    gapTol = state.u2pi * (L ^ kThisRound);

    channelOrder = schedule(roundIdx, :);
    terminalGapByChannel = zeros(1, numChannels);

    evalCountStart = evalCount;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);
        controlUBeforeChannel = controlU;
        [uOpt, evalLocal, terminalGap] = iGoldenSearchByChannel( ...
            controlU, channelIdx, cfgMrevGss.controlMin, cfgMrevGss.controlMax, L, gapTol, measureFn);

        candidateControlU = controlU;
        candidateControlU(channelIdx) = uOpt;
        prevAcceptedIntensity = displayState.intensityHistory(end);
        [controlU, channelIntensity, channelSensorInfo, acceptEval] = exp_apply_legacy_channel_acceptance( ...
            controlUBeforeChannel, candidateControlU, prevAcceptedIntensity, measureFn);
        evalCount = evalCount + evalLocal + acceptEval;
        terminalGapByChannel(orderIdx) = terminalGap;

        progressInfo = iBuildProgressInfo(roundIdx, channelIdx, orderIdx, "mREV-GSS");
        displayState = exp_update_realtime_display(displayState, channelIntensity, channelSensorInfo, controlU, progressInfo);
    end

    prevRoundIntensity = displayState.intensityHistory(end);
    roundIntensityMeasured(roundIdx) = prevRoundIntensity;
    roundAccepted(roundIdx) = true;

    roundGapTol(roundIdx) = gapTol;
    roundMaxTerminalGap(roundIdx) = max(terminalGapByChannel);
    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method = "mREV-GSS";
result.controlU = controlU;
result.evalCount = evalCount;
result.roundCount = maxRounds;
result.initialIntensityMeasured = initialIntensityMeasured;
result.roundIntensityMeasured = roundIntensityMeasured;
result.roundGapTol = roundGapTol;
result.roundMaxTerminalGap = roundMaxTerminalGap;
result.roundEvalCount = roundEvalCount;
result.roundAccepted = roundAccepted;
result.bestDisplayControlU = displayState.bestControlU;
result.V_measure_final = displayState.intensityHistory;
result.best_image = displayState.bestImage;
result.voltage_calibration_best = iControlUToVoltage(displayState.bestControlU);

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
