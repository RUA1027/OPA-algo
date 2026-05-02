function result = attachSimulationMetrics(result, state)
%ATTACHSIMULATIONMETRICS Compute far-field and attach all beam quality metrics.
%
%   result = attachSimulationMetrics(result, state)
%
% Adds to result:
%   result.field            — far-field electric field (complex)
%   result.intensity        — far-field intensity
%   result.targetIntensity  — scalar intensity at target angle
%   result.metrics          — struct: smsrDb/slsrDb, beamwidth3dBDeg/fwhmDeg,
%                             mainPeakThetaDeg, pointingErrorDeg,
%                             targetIntensity, targetIntensityNorm,
%                             mainLobePowerRatio

[thetaDeg, field, intensity] = computeFarField(result.controlU, state);
result.field = field;
result.intensity = intensity;
result.metrics = computeMetrics(thetaDeg, intensity, state.targetThetaDeg);
result.targetIntensity = computeTargetIntensity(result.controlU, state);

end
