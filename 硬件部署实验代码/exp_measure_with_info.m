function [y, sensorInfo] = exp_measure_with_info(measureFn, controlU)
%EXP_MEASURE_WITH_INFO Evaluate the measurement callback with optional metadata.

arguments
    measureFn (1,1) function_handle
    controlU (1,:) double
end

sensorInfo = struct();
nOutputs = nargout(measureFn);

if nOutputs < 0 || nOutputs >= 2
    [y, sensorInfo] = measureFn(controlU);
else
    y = measureFn(controlU);
end

end
