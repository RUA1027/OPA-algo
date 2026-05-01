function [acceptedControlU, acceptedIntensity, acceptedSensorInfo, evalCount, accepted] = ...
    exp_apply_legacy_channel_acceptance(controlUBeforeChannel, candidateControlU, prevAcceptedIntensity, measureFn)
%EXP_APPLY_LEGACY_CHANNEL_ACCEPTANCE Apply legacy-style per-channel acceptance logic.

arguments
    controlUBeforeChannel (1,:) double
    candidateControlU (1,:) double
    prevAcceptedIntensity (1,1) double
    measureFn (1,1) function_handle
end

[baselineIntensity, baselineSensorInfo] = exp_measure_with_info(measureFn, controlUBeforeChannel);
evalCount = 1;

if isequal(candidateControlU, controlUBeforeChannel)
    candidateIntensity = baselineIntensity;
    candidateSensorInfo = baselineSensorInfo;
else
    [candidateIntensity, candidateSensorInfo] = exp_measure_with_info(measureFn, candidateControlU);
    evalCount = evalCount + 1;
end

acceptanceThreshold = (baselineIntensity + prevAcceptedIntensity) / 2;

if candidateIntensity <= acceptanceThreshold
    acceptedControlU = controlUBeforeChannel;
    acceptedIntensity = acceptanceThreshold;
    acceptedSensorInfo = baselineSensorInfo;
    accepted = false;
else
    acceptedControlU = candidateControlU;
    acceptedIntensity = candidateIntensity;
    acceptedSensorInfo = candidateSensorInfo;
    accepted = true;
end

end
