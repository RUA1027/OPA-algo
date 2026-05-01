function displayState = exp_init_realtime_display(displayCfg, initialIntensityMeasured)
%EXP_INIT_REALTIME_DISPLAY Initialize per-channel realtime calibration display state.

arguments
    displayCfg (1,1) struct
    initialIntensityMeasured (1,1) double
end

displayState = struct();
displayState.enabled = iResolveEnabled(displayCfg);
displayState.sensorMode = iResolveSensorMode(displayCfg);
displayState.isCcd = strcmp(displayState.sensorMode, "CCD");
displayState.figureNumber = iResolveFigureNumber(displayCfg);
displayState.saturationThreshold = iResolveSaturationThreshold(displayCfg);
displayState.figureName = iResolveFigureName(displayCfg);
displayState.figureHandle = [];
displayState.intensityHistory = initialIntensityMeasured;
displayState.bestIntensity = 0;
displayState.bestImage = [];
displayState.bestControlU = [];
displayState.bestRoundIdx = NaN;
displayState.bestChannelIdx = NaN;
displayState.bestPhaseFwhmDeg = NaN;
displayState.bestWlFwhmDeg = NaN;
displayState.bestBeamPositionDeg = NaN;
displayState.imageClim = [0, displayState.saturationThreshold];

end

function tf = iResolveEnabled(displayCfg)
tf = true;
if isfield(displayCfg, "enabled")
    tf = logical(displayCfg.enabled);
elseif isfield(displayCfg, "ccdRealtimeDisplay") && isfield(displayCfg.ccdRealtimeDisplay, "enabled")
    tf = logical(displayCfg.ccdRealtimeDisplay.enabled);
end
end

function sensorMode = iResolveSensorMode(displayCfg)
sensorMode = "CCD";
if isfield(displayCfg, "sensorMode")
    sensorMode = upper(string(displayCfg.sensorMode));
end
end

function figureNumber = iResolveFigureNumber(displayCfg)
figureNumber = 1;
if isfield(displayCfg, "figureNumber")
    figureNumber = displayCfg.figureNumber;
elseif isfield(displayCfg, "ccdRealtimeDisplay") && isfield(displayCfg.ccdRealtimeDisplay, "figureNumber")
    figureNumber = displayCfg.ccdRealtimeDisplay.figureNumber;
end
end

function saturationThreshold = iResolveSaturationThreshold(displayCfg)
saturationThreshold = 16000;
if isfield(displayCfg, "saturationThreshold")
    saturationThreshold = displayCfg.saturationThreshold;
elseif isfield(displayCfg, "ccdRealtimeDisplay") && isfield(displayCfg.ccdRealtimeDisplay, "saturationThreshold")
    saturationThreshold = displayCfg.ccdRealtimeDisplay.saturationThreshold;
end
end

function figureName = iResolveFigureName(displayCfg)
figureName = "Calibration Realtime Monitor";
if isfield(displayCfg, "figureName")
    figureName = string(displayCfg.figureName);
end
end
