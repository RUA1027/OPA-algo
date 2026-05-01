function displayCfg = exp_get_realtime_display_cfg(cfgMethod)
%EXP_GET_REALTIME_DISPLAY_CFG Resolve optional realtime display config from a method cfg.

arguments
    cfgMethod (1,1) struct
end

displayCfg = struct();
displayCfg.enabled = true;
displayCfg.sensorMode = "CCD";
displayCfg.figureNumber = 1;
displayCfg.saturationThreshold = 16000;
displayCfg.figureName = "Calibration Realtime Monitor";

if isfield(cfgMethod, "realtimeDisplay") && ~isempty(cfgMethod.realtimeDisplay)
    rawCfg = cfgMethod.realtimeDisplay;
    if isfield(rawCfg, "enabled")
        displayCfg.enabled = logical(rawCfg.enabled);
    end
    if isfield(rawCfg, "sensorMode")
        displayCfg.sensorMode = string(rawCfg.sensorMode);
    end
    if isfield(rawCfg, "figureNumber")
        displayCfg.figureNumber = rawCfg.figureNumber;
    end
    if isfield(rawCfg, "saturationThreshold")
        displayCfg.saturationThreshold = rawCfg.saturationThreshold;
    end
    if isfield(rawCfg, "figureName")
        displayCfg.figureName = string(rawCfg.figureName);
    end
end

end
