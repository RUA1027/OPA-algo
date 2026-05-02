function result = exp_attach_display_metrics(result, displayState)
%EXP_ATTACH_DISPLAY_METRICS Copy realtime image metrics into a result struct.

result.bestDisplayControlU = displayState.bestControlU;
result.V_measure_final = displayState.intensityHistory;
result.best_image = displayState.bestImage;
result.bestPhaseFwhmDeg = displayState.bestPhaseFwhmDeg;
result.bestWlFwhmDeg = displayState.bestWlFwhmDeg;
result.bestBeamPositionDeg = displayState.bestBeamPositionDeg;

result.bestPeak = displayState.bestPeak;
result.bestPeakXPixel = displayState.bestPeakXPixel;
result.bestPeakYPixel = displayState.bestPeakYPixel;
result.bestPeakXDeg = displayState.bestPeakXDeg;
result.bestPeakYDeg = displayState.bestPeakYDeg;

result.targetXPixel = displayState.targetXPixel;
result.targetYPixel = displayState.targetYPixel;
result.bestTargetDeviationXPixel = displayState.bestTargetDeviationXPixel;
result.bestTargetDeviationYPixel = displayState.bestTargetDeviationYPixel;
result.bestTargetDeviationRssPixel = displayState.bestTargetDeviationRssPixel;
result.bestTargetDeviationXDeg = displayState.bestTargetDeviationXDeg;
result.bestTargetDeviationYDeg = displayState.bestTargetDeviationYDeg;
result.bestTargetDeviationRssDeg = displayState.bestTargetDeviationRssDeg;

end
