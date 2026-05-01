function result = exp_run_mrev(state, cfgMrev, measureFn)
%EXP_RUN_MREV Experiment-side pure mREV grid-search runner.
%
% Per-channel strategy:
%   evaluate a uniform grid with spacing gapTol = u2pi * shrinkRatio^k,
%   then keep the best sampled point.
% Across rounds:
%   keep using the full control vector from the previous round as current
%   working point.

arguments
    state (1,1) struct
    cfgMrev (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxRounds = cfgMrev.maxRounds;

if isfield(cfgMrev, "channelSchedule")
    schedule = cfgMrev.channelSchedule;
else
    schedule = repmat(1:numChannels, maxRounds, 1);
end

if size(schedule, 1) < maxRounds || size(schedule, 2) ~= numChannels
    error("opa_exp:exp_run_mrev:InvalidSchedule", "Invalid channelSchedule size.");
end

kByRound = cfgMrev.kByRound(:).';
L = cfgMrev.shrinkRatio;

controlU = state.initialControlU;
evalCount = 0;

roundIntensityMeasured = zeros(1, maxRounds);
roundGapTol = zeros(1, maxRounds);
roundGridStep = zeros(1, maxRounds);
roundEvalCount = zeros(1, maxRounds);
roundAccepted = false(1, maxRounds);

[initialIntensityMeasured, ~] = exp_measure_with_info(measureFn, controlU);
evalCount = evalCount + 1;
displayState = exp_init_realtime_display(exp_get_realtime_display_cfg(cfgMrev), initialIntensityMeasured);

for roundIdx = 1:maxRounds
    kThisRound = kByRound(min(roundIdx, numel(kByRound)));
    gapTol = state.u2pi * (L ^ kThisRound);

    channelOrder = schedule(roundIdx, :);
    gridStepsThisRound = zeros(1, numChannels);

    evalCountStart = evalCount;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);
        controlUBeforeChannel = controlU;
        [uOpt, evalLocal, gridStepUsed] = iGridSearchByChannel( ...
            controlU, channelIdx, cfgMrev.controlMin, cfgMrev.controlMax, gapTol, measureFn);

        candidateControlU = controlU;
        candidateControlU(channelIdx) = uOpt;
        prevAcceptedIntensity = displayState.intensityHistory(end);
        [controlU, channelIntensity, channelSensorInfo, acceptEval] = exp_apply_legacy_channel_acceptance( ...
            controlUBeforeChannel, candidateControlU, prevAcceptedIntensity, measureFn);
        evalCount = evalCount + evalLocal + acceptEval;
        gridStepsThisRound(orderIdx) = gridStepUsed;

        progressInfo = iBuildProgressInfo(roundIdx, channelIdx, orderIdx, "mREV");
        displayState = exp_update_realtime_display(displayState, channelIntensity, channelSensorInfo, controlU, progressInfo);
    end

    prevRoundIntensity = displayState.intensityHistory(end);
    roundIntensityMeasured(roundIdx) = prevRoundIntensity;
    roundAccepted(roundIdx) = true;

    roundGapTol(roundIdx) = gapTol;
    roundGridStep(roundIdx) = max(gridStepsThisRound);
    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method = "mREV";
result.controlU = controlU;
result.evalCount = evalCount;
result.roundCount = maxRounds;
result.initialIntensityMeasured = initialIntensityMeasured;
result.roundIntensityMeasured = roundIntensityMeasured;
result.roundGapTol = roundGapTol;
result.roundGridStep = roundGridStep;
result.roundEvalCount = roundEvalCount;
result.roundAccepted = roundAccepted;
result.bestDisplayControlU = displayState.bestControlU;
result.V_measure_final = displayState.intensityHistory;
result.best_image = displayState.bestImage;
result.voltage_calibration_best = iControlUToVoltage(displayState.bestControlU);
result.bestPhaseFwhmDeg = displayState.bestPhaseFwhmDeg;
result.bestWlFwhmDeg = displayState.bestWlFwhmDeg;
result.bestBeamPositionDeg = displayState.bestBeamPositionDeg;

end

function [uOpt, evalCount, gridStepUsed] = iGridSearchByChannel(controlU, channelIdx, uMin, uMax, gapTol, measureFn)
gridU = uMin:gapTol:uMax;
if isempty(gridU)
    gridU = [uMin, uMax];
elseif gridU(end) < uMax
    gridU(end + 1) = uMax;
end

if numel(gridU) >= 2
    gridStepUsed = max(diff(gridU));
else
    gridStepUsed = uMax - uMin;
end

y = zeros(1, numel(gridU));
for idx = 1:numel(gridU)
    candidate = controlU;
    candidate(channelIdx) = gridU(idx);
    y(idx) = measureFn(candidate);
end

[~, idxBest] = max(y);
uOpt = gridU(idxBest);
evalCount = numel(gridU);

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
