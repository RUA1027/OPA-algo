function result = exp_run_caio(state, cfgCaio, measureFn)
%EXP_RUN_CAIO Experiment-side crosstalk-aware interleaved optimization.
% This implementation keeps odd/even interleaved PPS updates and round
% rollback, while removing simulation-only explicit crosstalk compensation.

arguments
    state (1,1) struct
    cfgCaio (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxRounds = cfgCaio.maxRounds;
ppsSteps = cfgCaio.ppsSteps;
omega = state.phasePerU;
u2pi = state.u2pi;
uMin = cfgCaio.controlMin;
uMax = cfgCaio.controlMax;

if ~ismember(ppsSteps, [3, 4, 5])
    error("opa_exp:exp_run_caio:BadPpsSteps", "ppsSteps must be 3, 4, or 5.");
end

if isfield(cfgCaio, "channelSchedule")
    schedule = cfgCaio.channelSchedule;
else
    schedule = repmat(1:numChannels, maxRounds, 1);
end

if size(schedule, 1) < maxRounds || size(schedule, 2) ~= numChannels
    error("opa_exp:exp_run_caio:InvalidSchedule", "Invalid channelSchedule size.");
end

controlU = state.initialControlU;
evalCount = 0;

roundIntensityMeasured = zeros(1, maxRounds);
roundEvalCount = zeros(1, maxRounds);
roundAccepted = false(1, maxRounds);

[initialIntensityMeasured, ~] = exp_measure_with_info(measureFn, controlU);
evalCount = evalCount + 1;
displayState = exp_init_realtime_display(exp_get_realtime_display_cfg(cfgCaio), initialIntensityMeasured);

for roundIdx = 1:maxRounds
    channelOrder = schedule(roundIdx, :);
    evalCountStart = evalCount;

    oddChannels = channelOrder(mod(channelOrder, 2) == 1);
    evenChannels = channelOrder(mod(channelOrder, 2) == 0);

    for idx = 1:numel(oddChannels)
        channelIdx = oddChannels(idx);
        controlUBeforeChannel = controlU;
        [uOpt, localEval] = iPpsByChannel( ...
            controlU, channelIdx, ppsSteps, omega, u2pi, uMin, uMax, measureFn);
        candidateControlU = controlU;
        candidateControlU(channelIdx) = uOpt;
        prevAcceptedIntensity = displayState.intensityHistory(end);
        [controlU, channelIntensity, channelSensorInfo, acceptEval] = exp_apply_legacy_channel_acceptance( ...
            controlUBeforeChannel, candidateControlU, prevAcceptedIntensity, measureFn);
        evalCount = evalCount + localEval + acceptEval;

        progressInfo = iBuildProgressInfo(roundIdx, channelIdx, idx, "CAIO");
        displayState = exp_update_realtime_display(displayState, channelIntensity, channelSensorInfo, controlU, progressInfo);
    end

    for idx = 1:numel(evenChannels)
        channelIdx = evenChannels(idx);
        controlUBeforeChannel = controlU;
        [uOpt, localEval] = iPpsByChannel( ...
            controlU, channelIdx, ppsSteps, omega, u2pi, uMin, uMax, measureFn);
        candidateControlU = controlU;
        candidateControlU(channelIdx) = uOpt;
        prevAcceptedIntensity = displayState.intensityHistory(end);
        [controlU, channelIntensity, channelSensorInfo, acceptEval] = exp_apply_legacy_channel_acceptance( ...
            controlUBeforeChannel, candidateControlU, prevAcceptedIntensity, measureFn);
        evalCount = evalCount + localEval + acceptEval;

        progressInfo = iBuildProgressInfo(roundIdx, channelIdx, idx, "CAIO");
        displayState = exp_update_realtime_display(displayState, channelIntensity, channelSensorInfo, controlU, progressInfo);
    end

    prevRoundIntensity = displayState.intensityHistory(end);
    roundIntensityMeasured(roundIdx) = prevRoundIntensity;
    roundAccepted(roundIdx) = true;

    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method = "CAIO";
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

function [uOpt, evalCount] = iPpsByChannel(controlU, channelIdx, ppsSteps, omega, u2pi, uMin, uMax, measureFn)

deltaU = u2pi / 4;
uCur = controlU(channelIdx);

switch ppsSteps
    case 3
        samplePoints = uCur + [-1, 0, 1] * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn);
        evalCount = 3;

        if max(I) - min(I) <= eps(max(abs(I)) + 1)
            uOpt = uCur;
            return;
        end

        u0Centre = samplePoints(2);
        phi0 = atan2(I(1) - I(3), 2 * I(2) - I(1) - I(3));

    case 4
        samplePoints = uCur + [-1.5, -0.5, 0.5, 1.5] * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn);
        evalCount = 4;

        if max(I) - min(I) <= eps(max(abs(I)) + 1)
            uOpt = uCur;
            return;
        end

        u0Centre = mean(samplePoints(2:3));
        phi0 = atan2(I(4) - I(2), I(1) - I(3));

    case 5
        samplePoints = uCur + (-2:2) * deltaU;
        samplePoints = iShiftWindow(samplePoints, uMin, uMax);
        I = iMeasurePoints(controlU, channelIdx, samplePoints, measureFn);
        evalCount = 5;

        if max(I) - min(I) <= eps(max(abs(I)) + 1)
            uOpt = uCur;
            return;
        end

        u0Centre = samplePoints(3);
        phi0 = atan2(2 * (I(2) - I(4)), 2 * I(3) - I(5) - I(1));

    otherwise
        error("opa_exp:exp_run_caio:BadPpsSteps", "ppsSteps must be 3, 4, or 5.");
end

uOpt = u0Centre - phi0 / omega;
uOpt = mod(uOpt - uMin, u2pi) + uMin;
uOpt = min(max(uOpt, uMin), uMax);

end

function pts = iShiftWindow(pts, uMin, uMax)
span = pts(end) - pts(1);
if span > (uMax - uMin)
    pts = linspace(uMin, uMax, numel(pts));
    return;
end

if pts(1) < uMin
    pts = pts + (uMin - pts(1));
end
if pts(end) > uMax
    pts = pts - (pts(end) - uMax);
end

if pts(1) < uMin || pts(end) > uMax
    pts = linspace(uMin, uMax, numel(pts));
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
