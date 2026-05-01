function result = exp_run_5pps(state, cfg5pps, measureFn)
%EXP_RUN_5PPS Experiment-side five-point phase stepping calibration.

arguments
    state (1,1) struct
    cfg5pps (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxRounds = cfg5pps.maxRounds;
omega = state.phasePerU;
u2pi = state.u2pi;
uMin = cfg5pps.controlMin;
uMax = cfg5pps.controlMax;

if isfield(cfg5pps, "channelSchedule")
    schedule = cfg5pps.channelSchedule;
else
    schedule = repmat(1:numChannels, maxRounds, 1);
end

if size(schedule, 1) < maxRounds || size(schedule, 2) ~= numChannels
    error("opa_exp:exp_run_5pps:InvalidSchedule", "Invalid channelSchedule size.");
end

controlU = state.initialControlU;
evalCount = 0;

roundIntensityMeasured = zeros(1, maxRounds);
roundEvalCount = zeros(1, maxRounds);
roundAccepted = false(1, maxRounds);

[initialIntensityMeasured, ~] = exp_measure_with_info(measureFn, controlU);
evalCount = evalCount + 1;
displayState = exp_init_realtime_display(exp_get_realtime_display_cfg(cfg5pps), initialIntensityMeasured);

for roundIdx = 1:maxRounds
    channelOrder = schedule(roundIdx, :);
    evalCountStart = evalCount;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);
        controlUBeforeChannel = controlU;
        [uOpt, localEval] = iFiveStepByChannel( ...
            controlU, channelIdx, omega, uMin, uMax, u2pi, measureFn);
        candidateControlU = controlU;
        candidateControlU(channelIdx) = uOpt;
        prevAcceptedIntensity = displayState.intensityHistory(end);
        [controlU, channelIntensity, channelSensorInfo, acceptEval] = exp_apply_legacy_channel_acceptance( ...
            controlUBeforeChannel, candidateControlU, prevAcceptedIntensity, measureFn);
        evalCount = evalCount + localEval + acceptEval;

        progressInfo = iBuildProgressInfo(roundIdx, channelIdx, orderIdx, "5PPS");
        displayState = exp_update_realtime_display(displayState, channelIntensity, channelSensorInfo, controlU, progressInfo);
    end

    prevRoundIntensity = displayState.intensityHistory(end);
    roundIntensityMeasured(roundIdx) = prevRoundIntensity;
    roundAccepted(roundIdx) = true;

    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method = "5PPS";
result.controlU = controlU;
result.evalCount = evalCount;
result.roundCount = maxRounds;
result.initialIntensityMeasured = initialIntensityMeasured;
result.roundIntensityMeasured = roundIntensityMeasured;
result.roundEvalCount = roundEvalCount;
result.roundAccepted = roundAccepted;
result.bestDisplayControlU = displayState.bestControlU;
result.V_measure_final = displayState.intensityHistory;
result.best_image = displayState.bestImage;
result.voltage_calibration_best = iControlUToVoltage(displayState.bestControlU);

end

function [uOpt, evalCount] = iFiveStepByChannel(controlU, channelIdx, omega, uMin, uMax, u2pi, measureFn)

evalCount = 5;
deltaU = u2pi / 4;

u0 = controlU(channelIdx);
samplePoints = u0 + (-2:2) * deltaU;

if samplePoints(1) < uMin
    samplePoints = samplePoints + (uMin - samplePoints(1));
end
if samplePoints(5) > uMax
    samplePoints = samplePoints - (samplePoints(5) - uMax);
end
if samplePoints(1) < uMin || samplePoints(5) > uMax
    samplePoints = linspace(uMin, uMax, 5);
end

I = zeros(1, 5);
for j = 1:5
    candidate = controlU;
    candidate(channelIdx) = samplePoints(j);
    I(j) = measureFn(candidate);
end

if max(I) - min(I) <= eps(max(abs(I)) + 1)
    uOpt = controlU(channelIdx);
    return;
end

u0Centre = samplePoints(3);
phi0 = atan2(2 * (I(2) - I(4)), 2 * I(3) - I(5) - I(1));

uOpt = u0Centre - phi0 / omega;
uOpt = mod(uOpt - uMin, u2pi) + uMin;
uOpt = min(max(uOpt, uMin), uMax);

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
