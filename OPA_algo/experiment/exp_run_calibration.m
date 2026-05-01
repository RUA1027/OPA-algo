function result = exp_run_calibration(cfg)
%EXP_RUN_CALIBRATION Unified entry for experiment-side calibration.

if nargin < 1 || isempty(cfg)
    cfg = exp_default_config();
end

rawMeasureFn = [];
measureLog = struct();
measureLog.values = zeros(1, 0);
measureLog.sensorInfo = {};

state = exp_build_state(cfg);
runner = exp_get_algorithm_runner(cfg.method);
cfgMethod = iSelectMethodCfg(cfg);
cfgMethod.realtimeDisplay = iBuildRealtimeDisplayCfg(cfg);

rounds = iMethodRounds(cfg.method, cfgMethod);
if ~isfield(cfgMethod, "channelSchedule") || isempty(cfgMethod.channelSchedule)
    cfgMethod.channelSchedule = exp_make_channel_schedule(cfg.channelOrder, state.numChannels, rounds);
end

if ~isfield(cfgMethod, "enableRoundRollback")
    cfgMethod.enableRoundRollback = cfg.rollback.enableRoundRollback;
end

if isfield(cfg, "runtime") && isfield(cfg.runtime, "mockMeasureFn") && ~isempty(cfg.runtime.mockMeasureFn)
    rawMeasureFn = cfg.runtime.mockMeasureFn;
    measureFn = @iLoggedMeasure;
    [result, calibrationTiming] = iRunTimedRunner(@() runner(state, cfgMethod, measureFn));
    preFinalEvalCount = numel(measureLog.values);
else
    exp_legacy_precleanup();
    hw = exp_init_hardware(cfg);
    cleaner = onCleanup(@() exp_close_hardware(hw));

    rawMeasureFn = exp_make_measure_fn(hw, cfg);
    iResetVoltageToInitialState(hw.serialObj, state.initialControlU, cfg);
    measureFn = @iLoggedMeasure;
    [result, calibrationTiming] = iRunTimedRunner(@() runner(state, cfgMethod, measureFn));
    preFinalEvalCount = numel(measureLog.values);

    result.finalIntensityMeasured = measureFn(result.controlU);
    result.evalCountWithFinal = result.evalCount + 1;
end

result.initialControlU = state.initialControlU;
result.methodSelected = string(cfg.method);
result.voltage_calibration = iControlUToVoltage(result.controlU);
if ~isfield(result, "voltage_calibration_best") || isempty(result.voltage_calibration_best)
    result.voltage_calibration_best = result.voltage_calibration;
end
if ~isfield(result, "V_measure_final") || isempty(result.V_measure_final)
    result.V_measure_final = [];
end
result.V_measure = measureLog.values(1:preFinalEvalCount);

if ~isfield(result, "best_image")
    result.best_image = [];
end

result.calibrationElapsedSec = calibrationTiming.elapsedSec;
result.calibrationTiming = calibrationTiming;

    function [y, sensorInfo] = iLoggedMeasure(controlU)
        [y, sensorInfo] = exp_measure_with_info(rawMeasureFn, reshape(double(controlU), 1, []));
        measureLog.values(end + 1) = y;
        measureLog.sensorInfo{end + 1} = sensorInfo;
    end

    function [timedResult, timing] = iRunTimedRunner(runFn)
        timing = struct();
        timing.scope = "initial sample through end of calibration rounds";
        timing.startedAt = datetime("now");

        timerId = tic;
        timedResult = runFn();
        timing.elapsedSec = toc(timerId);
        timing.finishedAt = timing.startedAt + seconds(timing.elapsedSec);
    end

end

function cfgMethod = iSelectMethodCfg(cfg)
token = iNormalizeMethodToken(cfg.method);

switch token
    case "MREVGSS"
        cfgMethod = cfg.mrevGss;
    case {"5PPS", "FIVEPPS"}
        cfgMethod = cfg.fivePps;
    case "PFPD"
        cfgMethod = cfg.pfpd;
    case "CAIO"
        cfgMethod = cfg.caio;
    otherwise
        error("opa_exp:exp_run_calibration:UnsupportedMethod", "Unsupported method: %s", cfg.method);
end

end

function rounds = iMethodRounds(method, cfgMethod)
token = iNormalizeMethodToken(method);

switch token
    case "MREVGSS"
        rounds = cfgMethod.maxRounds;
    case {"5PPS", "FIVEPPS"}
        rounds = cfgMethod.maxRounds;
    case "PFPD"
        rounds = cfgMethod.rounds;
    case "CAIO"
        rounds = cfgMethod.maxRounds;
    otherwise
        error("opa_exp:exp_run_calibration:UnsupportedMethod", "Unsupported method: %s", method);
end

end

function displayCfg = iBuildRealtimeDisplayCfg(cfg)
displayCfg = struct();
displayCfg.sensorMode = string(cfg.hardware.sensorMode);
displayCfg.enabled = true;
displayCfg.figureNumber = 1;
displayCfg.saturationThreshold = 16000;
displayCfg.figureName = "Calibration Realtime Monitor";

if isfield(cfg, "measure") && isfield(cfg.measure, "ccdRealtimeDisplay")
    rawCfg = cfg.measure.ccdRealtimeDisplay;
    if isfield(rawCfg, "enabled")
        displayCfg.enabled = logical(rawCfg.enabled);
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

function token = iNormalizeMethodToken(method)
token = regexprep(upper(string(method)), "[^A-Z0-9]", "");
end

function voltage = iControlUToVoltage(controlU)
if isempty(controlU)
    voltage = [];
else
    voltage = sqrt(max(controlU, 0));
end
end

function iResetVoltageToInitialState(serialObj, initialControlU, cfg)
% Write initial control voltage once before the first algorithm sample.
initialVoltage = iControlUToVoltage(initialControlU);
voltageAllChannels = func_V_transition(initialVoltage);
ZJY_256VSRC_WRITE(serialObj, voltageAllChannels);

if isfield(cfg, "measure") && isfield(cfg.measure, "delaySec") && cfg.measure.delaySec > 0
    pause(cfg.measure.delaySec);
end
end
