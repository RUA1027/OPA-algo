function runResult = exp_run_wavelength_calibration(method, wavelengthNm, cfg, varargin)
%EXP_RUN_WAVELENGTH_CALIBRATION Calibrate all target x positions for one wavelength.

if nargin < 1 || strlength(string(method)) == 0
    method = "mREV-GSS";
end
if nargin < 2 || isempty(wavelengthNm)
    error("opa_exp:exp_run_wavelength_calibration:MissingWavelength", ...
        "An absolute wavelength in nm is required.");
end
if nargin < 3 || isempty(cfg)
    cfg = exp_default_config();
end

opts = iParseOptions(varargin{:});
cfg.method = string(method);

[targets, preprocessSummary] = exp_select_wavelength_targets( ...
    opts.CsvPath, wavelengthNm, cfg.measure.ccdSpotSize);

matchedWavelengthNm = round(double(wavelengthNm), 3);
outputDir = iPrepareOutputDir(opts.OutputRoot, matchedWavelengthNm);

runResult = struct();
runResult.mode = "wavelength-multipoint";
runResult.method = string(method);
runResult.inputWavelengthNm = double(wavelengthNm);
runResult.matchedWavelengthNm = matchedWavelengthNm;
runResult.deltaLambdaNm = matchedWavelengthNm - preprocessSummary.centerWavelengthNm;
runResult.csvPath = string(preprocessSummary.csvPath);
runResult.outputRoot = string(opts.OutputRoot);
runResult.outputDir = string(outputDir);
runResult.preprocessSummary = preprocessSummary;
runResult.targets = targets;
runResult.targetCount = height(targets);
runResult.pointResults = repmat(iPointResultTemplate(), height(targets), 1);
runResult.manifest = table();

manifestRecords = repmat(iManifestRecordTemplate(), height(targets), 1);

cfgLoop = cfg;
if iShouldReuseHardware(cfgLoop, opts.ReuseHardware)
    exp_legacy_precleanup();
    hw = exp_init_hardware(cfgLoop);
    hardwareCleaner = onCleanup(@() exp_close_hardware(hw));
    cfgLoop.hardware.useExternalSerial = true;
    cfgLoop.hardware.externalSerialObj = hw.serialObj;
    if strcmpi(string(cfgLoop.hardware.sensorMode), "CCD")
        cfgLoop.hardware.useExternalVideo = true;
        cfgLoop.hardware.externalVideoObj = hw.videoObj;
    end
end

for pointIdx = 1:height(targets)
    target = targets(pointIdx, :);
    pointLabel = iMakePointLabel(pointIdx, target);
    imagePath = fullfile(outputDir, pointLabel + "_best_image.tif");
    fomCurvePath = fullfile(outputDir, pointLabel + "_fom_curve.png");
    resultPath = fullfile(outputDir, pointLabel + "_result.mat");

    cfgPoint = cfgLoop;
    cfgPoint.method = string(method);
    cfgPoint.measure.ccdCenterCol = target.x_pixel;

    try
        result = exp_run_calibration(cfgPoint);
        [imagePathSaved, imageSaved] = iSaveBestImageIfAvailable(result, imagePath);
        [fomCurvePathSaved, fomCurveSaved] = iSaveFomCurveIfAvailable(result, fomCurvePath, target, string(method));
        targetInfo = target;
        pointResult = result;
        save(resultPath, "pointResult", "targetInfo", "method", "wavelengthNm", ...
            "matchedWavelengthNm", "fomCurvePathSaved");

        resultSummary = iMakeResultSummary(result);
        manifestRecords(pointIdx) = iMakeManifestRecord( ...
            pointIdx, target, string(method), wavelengthNm, matchedWavelengthNm, ...
            imagePathSaved, fomCurvePathSaved, resultPath, "completed", "", resultSummary);
        runResult.pointResults(pointIdx) = iMakePointResult( ...
            pointIdx, target, imagePathSaved, fomCurvePathSaved, resultPath, ...
            imageSaved, fomCurveSaved, "completed", "", resultSummary);
    catch ME
        manifestRecords(pointIdx) = iMakeManifestRecord( ...
            pointIdx, target, string(method), wavelengthNm, matchedWavelengthNm, ...
            "", "", resultPath, "failed", string(ME.message), iEmptyResultSummary());
        runResult.pointResults(pointIdx) = iMakePointResult( ...
            pointIdx, target, "", "", resultPath, false, false, ...
            "failed", string(ME.message), iEmptyResultSummary());
        runResult.manifest = struct2table(manifestRecords(1:pointIdx));
        iWriteRunOutputs(runResult);
        clear hardwareCleaner;
        rethrow(ME);
    end
end

runResult.manifest = struct2table(manifestRecords);
iWriteRunOutputs(runResult);
clear hardwareCleaner;

fprintf("Wavelength %.3f nm: calibrated %d target(s). Results: %s\n", ...
    matchedWavelengthNm, runResult.targetCount, outputDir);

end

function opts = iParseOptions(varargin)
parser = inputParser();
parser.FunctionName = "exp_run_wavelength_calibration";
addParameter(parser, "CsvPath", "");
addParameter(parser, "OutputRoot", fullfile(pwd, "calibration_outputs"));
addParameter(parser, "ReuseHardware", true);
parse(parser, varargin{:});
opts = parser.Results;
opts.CsvPath = string(opts.CsvPath);
opts.OutputRoot = string(opts.OutputRoot);
opts.ReuseHardware = logical(opts.ReuseHardware);
end

function tf = iShouldReuseHardware(cfg, reuseHardware)
tf = reuseHardware;
if ~tf
    return;
end
if isfield(cfg, "runtime") && isfield(cfg.runtime, "mockMeasureFn") && ~isempty(cfg.runtime.mockMeasureFn)
    tf = false;
end
end

function outputDir = iPrepareOutputDir(outputRoot, wavelengthNm)
outputRoot = string(outputRoot);
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

stamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
lambdaToken = strrep(compose("%.3f", wavelengthNm), ".", "p");
baseName = stamp + "_lambda_" + lambdaToken + "nm";
outputDir = fullfile(outputRoot, baseName);

suffix = 1;
while isfolder(outputDir)
    outputDir = fullfile(outputRoot, baseName + "_" + string(suffix));
    suffix = suffix + 1;
end
mkdir(outputDir);
outputDir = string(outputDir);
end

function label = iMakePointLabel(pointIdx, target)
label = sprintf("point_%02d_%s_x%d_y%d", ...
    pointIdx, char(target.point_id), round(target.x_pixel), round(target.y_pixel));
label = string(label);
end

function [savedPath, imageSaved] = iSaveBestImageIfAvailable(result, imagePath)
savedPath = "";
imageSaved = false;

if ~isfield(result, "best_image") || isempty(result.best_image)
    return;
end

img = result.best_image;
if ~isinteger(img)
    img = uint16(min(max(double(img), 0), double(intmax("uint16"))));
end

imwrite(img, imagePath);
savedPath = string(imagePath);
imageSaved = true;
end

function [savedPath, curveSaved] = iSaveFomCurveIfAvailable(result, curvePath, target, method)
savedPath = "";
curveSaved = false;

[fomValues, sourceLabel] = iExtractFomHistory(result);
if isempty(fomValues)
    return;
end

fig = figure("Visible", "off", "Color", "w");
cleaner = onCleanup(@() close(fig));
iterations = 1:numel(fomValues);
plot(iterations, fomValues, "-o", "LineWidth", 1.4, "MarkerSize", 3);
grid on;
xlabel("Evaluation index");
ylabel("FOM");
title(sprintf("FOM Optimization - %s %s (x=%d, y=%d, source=%s)", ...
    char(method), char(target.point_id), round(target.x_pixel), round(target.y_pixel), char(sourceLabel)), ...
    "Interpreter", "none");

print(fig, char(curvePath), "-dpng", "-r150");
savedPath = string(curvePath);
curveSaved = true;
end

function [fomValues, sourceLabel] = iExtractFomHistory(result)
fomValues = [];
sourceLabel = "";

if isfield(result, "V_measure_final") && ~isempty(result.V_measure_final)
    fomValues = result.V_measure_final;
    sourceLabel = "V_measure_final";
elseif isfield(result, "V_measure") && ~isempty(result.V_measure)
    fomValues = result.V_measure;
    sourceLabel = "V_measure";
elseif isfield(result, "roundIntensityMeasured") && ~isempty(result.roundIntensityMeasured)
    fomValues = result.roundIntensityMeasured;
    sourceLabel = "roundIntensityMeasured";
end

fomValues = double(fomValues(:).');
fomValues = fomValues(isfinite(fomValues));
end

function summary = iMakeResultSummary(result)
summary = iEmptyResultSummary();
if isfield(result, "evalCount") && ~isempty(result.evalCount)
    summary.evalCount = double(result.evalCount);
end
if isfield(result, "calibrationElapsedSec") && ~isempty(result.calibrationElapsedSec)
    summary.elapsedSec = double(result.calibrationElapsedSec);
end
if isfield(result, "finalIntensityMeasured") && ~isempty(result.finalIntensityMeasured)
    summary.finalIntensity = double(result.finalIntensityMeasured);
elseif isfield(result, "V_measure_final") && ~isempty(result.V_measure_final)
    summary.finalIntensity = double(result.V_measure_final(end));
end
if isfield(result, "best_image") && ~isempty(result.best_image)
    summary.bestIntensity = double(max(result.best_image, [], "all"));
elseif isfield(result, "V_measure_final") && ~isempty(result.V_measure_final)
    summary.bestIntensity = double(max(result.V_measure_final));
end
end

function summary = iEmptyResultSummary()
summary = struct();
summary.evalCount = NaN;
summary.elapsedSec = NaN;
summary.finalIntensity = NaN;
summary.bestIntensity = NaN;
end

function record = iManifestRecordTemplate()
record = struct();
record.point_index = NaN;
record.method = "";
record.input_wavelength_nm = NaN;
record.matched_wavelength_nm = NaN;
record.delta_lambda_nm = NaN;
record.letter = "";
record.letter_index = NaN;
record.point_id = "";
record.x_pixel = NaN;
record.y_pixel = NaN;
record.image_path = "";
record.fom_curve_path = "";
record.result_path = "";
record.best_intensity = NaN;
record.final_intensity = NaN;
record.eval_count = NaN;
record.elapsed_sec = NaN;
record.status = "";
record.error_message = "";
end

function record = iMakeManifestRecord(pointIdx, target, method, inputWavelengthNm, matchedWavelengthNm, ...
    imagePath, fomCurvePath, resultPath, status, errorMessage, resultSummary)
record = iManifestRecordTemplate();
record.point_index = pointIdx;
record.method = method;
record.input_wavelength_nm = double(inputWavelengthNm);
record.matched_wavelength_nm = double(matchedWavelengthNm);
record.delta_lambda_nm = double(target.delta_lambda_nm);
record.letter = string(target.letter);
record.letter_index = double(target.index);
record.point_id = string(target.point_id);
record.x_pixel = double(target.x_pixel);
record.y_pixel = double(target.y_pixel);
record.image_path = string(imagePath);
record.fom_curve_path = string(fomCurvePath);
record.result_path = string(resultPath);
record.best_intensity = resultSummary.bestIntensity;
record.final_intensity = resultSummary.finalIntensity;
record.eval_count = resultSummary.evalCount;
record.elapsed_sec = resultSummary.elapsedSec;
record.status = string(status);
record.error_message = string(errorMessage);
end

function pointResult = iPointResultTemplate()
pointResult = struct();
pointResult.pointIndex = NaN;
pointResult.target = table();
pointResult.imagePath = "";
pointResult.fomCurvePath = "";
pointResult.resultPath = "";
pointResult.imageSaved = false;
pointResult.fomCurveSaved = false;
pointResult.status = "";
pointResult.errorMessage = "";
pointResult.summary = iEmptyResultSummary();
end

function pointResult = iMakePointResult(pointIdx, target, imagePath, fomCurvePath, resultPath, ...
    imageSaved, fomCurveSaved, status, errorMessage, summary)
pointResult = iPointResultTemplate();
pointResult.pointIndex = pointIdx;
pointResult.target = target;
pointResult.imagePath = string(imagePath);
pointResult.fomCurvePath = string(fomCurvePath);
pointResult.resultPath = string(resultPath);
pointResult.imageSaved = logical(imageSaved);
pointResult.fomCurveSaved = logical(fomCurveSaved);
pointResult.status = string(status);
pointResult.errorMessage = string(errorMessage);
pointResult.summary = summary;
end

function iWriteRunOutputs(runResult)
manifestPath = fullfile(runResult.outputDir, "run_manifest.csv");
resultPath = fullfile(runResult.outputDir, "wavelength_run_result.mat");
manifest = runResult.manifest;
writetable(manifest, manifestPath);
wavelengthRunResult = runResult;
save(resultPath, "wavelengthRunResult");
end
