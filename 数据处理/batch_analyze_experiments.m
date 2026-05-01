function summary = batch_analyze_experiments()
%BATCH_ANALYZE_EXPERIMENTS Batch-scan experiment outputs and produce summary.csv.
%
% Usage:
%   summary = batch_analyze_experiments();
%
% Walks all subdirectories under 实验数据/, loads every point_*_result.mat
% and its best_image.tif, extracts spot metrics (FWHM, peak position, target
% deviation), and writes 数据处理/summary.csv.
%
% Output:
%   summary  MATLAB table; also saved as summary.csv in the script directory.

scriptDir = fileparts(mfilename("fullpath"));
projectRoot = fileparts(scriptDir);
dataRoot = fullfile(projectRoot, "实验数据");
outputPath = fullfile(scriptDir, "summary.csv");

% Add experiment utilities to path
addpath(genpath(fullfile(projectRoot, "OPA_algo")));

% Recursively find all best_image.tif files
imageFiles = dir(fullfile(dataRoot, "**", "point_*_best_image.tif"));

if isempty(imageFiles)
    error("batch_analyze:noFiles", "No point_*_best_image.tif found under %s", dataRoot);
end

fprintf("Found %d point image files. Processing...\n", numel(imageFiles));

nPoints = numel(imageFiles);

% Pre-allocate cell arrays for table construction
colWavelengthRun = cell(nPoints, 1);
colPointLabel    = cell(nPoints, 1);
colMethod        = cell(nPoints, 1);
colTargetX       = zeros(nPoints, 1);
colTargetY       = zeros(nPoints, 1);
colEvalCount     = zeros(nPoints, 1);
colElapsedSec    = zeros(nPoints, 1);
colFinalIntensity = zeros(nPoints, 1);
colBestIntensity  = zeros(nPoints, 1);
colPhaseFwhmDeg  = zeros(nPoints, 1);
colWlFwhmDeg     = zeros(nPoints, 1);
colPhaseFwhmPx   = zeros(nPoints, 1);
colWlFwhmPx      = zeros(nPoints, 1);
colPeakXpx       = zeros(nPoints, 1);
colPeakYpx       = zeros(nPoints, 1);
colDevXpx        = zeros(nPoints, 1);
colDevYpx        = zeros(nPoints, 1);
colDevRssPx      = zeros(nPoints, 1);
colStatus        = cell(nPoints, 1);

for idx = 1:nPoints
    imageFile = imageFiles(idx);
    imageDir  = imageFile.folder;
    imageFull = fullfile(imageDir, imageFile.name);

    % Derive result .mat path from image filename
    resultName = strrep(imageFile.name, "_best_image.tif", "_result.mat");
    resultFull = fullfile(imageDir, resultName);

    % Parse wavelength run name and point label
    [wavelengthRun, pointLabel] = iParseImagePath(imageDir, imageFile.name);
    colWavelengthRun{idx} = wavelengthRun;
    colPointLabel{idx}    = pointLabel;

    if ~isfile(resultFull)
        warning("Missing result file: %s", resultFull);
        colStatus{idx} = "missing_result_mat";
        continue;
    end

    try
        loaded = load(resultFull);
    catch
        warning("Failed to load: %s", resultFull);
        colStatus{idx} = "load_error";
        continue;
    end

    % Extract fields from result.mat
    [methodStr, targetX, targetY, evalCount, elapsedSec, finalIntensity] = ...
        iExtractPointFields(loaded);
    colMethod{idx}    = methodStr;
    colTargetX(idx)   = targetX;
    colTargetY(idx)   = targetY;
    colEvalCount(idx) = evalCount;
    colElapsedSec(idx) = elapsedSec;
    colFinalIntensity(idx) = finalIntensity;

    % Read best_image
    if ~isfile(imageFull)
        warning("Missing image file: %s", imageFull);
        colStatus{idx} = "missing_image";
        continue;
    end
    try
        image = imread(imageFull);
    catch
        warning("Failed to read image: %s", imageFull);
        colStatus{idx} = "image_read_error";
        continue;
    end

    colBestIntensity(idx) = max(image(:));

    % Compute spot metrics
    try
        m = compute_spot_metrics(image, targetX, targetY);
    catch ME
        warning("Spot metrics failed for %s: %s", pointLabel, ME.message);
        colStatus{idx} = "metrics_error";
        continue;
    end

    colPhaseFwhmDeg(idx) = m.phase_FWHM_deg;
    colWlFwhmDeg(idx)    = m.wl_FWHM_deg;
    colPhaseFwhmPx(idx)  = m.phase_FWHM_px;
    colWlFwhmPx(idx)     = m.wl_FWHM_px;
    colPeakXpx(idx)      = m.peak_x_px;
    colPeakYpx(idx)      = m.peak_y_px;
    colDevXpx(idx)       = m.deviation_x_px;
    colDevYpx(idx)       = m.deviation_y_px;
    colDevRssPx(idx)     = m.deviation_rss_px;

    colStatus{idx} = "ok";

    if mod(idx, 10) == 0
        fprintf("  %d/%d processed\n", idx, nPoints);
    end
end

fprintf("Processed %d/%d points.\n", nPoints, nPoints);

summary = table( ...
    colWavelengthRun, colPointLabel, colMethod, ...
    colTargetX, colTargetY, ...
    colEvalCount, colElapsedSec, colFinalIntensity, colBestIntensity, ...
    colPhaseFwhmDeg, colWlFwhmDeg, colPhaseFwhmPx, colWlFwhmPx, ...
    colPeakXpx, colPeakYpx, ...
    colDevXpx, colDevYpx, colDevRssPx, ...
    colStatus, ...
    'VariableNames', { ...
    'wavelength_run', 'point_label', 'method', ...
    'target_x_px', 'target_y_px', ...
    'eval_count', 'elapsed_sec', 'final_intensity', 'best_intensity', ...
    'phase_FWHM_deg', 'wl_FWHM_deg', 'phase_FWHM_px', 'wl_FWHM_px', ...
    'peak_x_px', 'peak_y_px', ...
    'deviation_x_px', 'deviation_y_px', 'deviation_rss_px', ...
    'status'});

writetable(summary, outputPath);
fprintf("Summary written to: %s\n", outputPath);

% Quick stats — use cellfun for robust status check
okMask = false(nPoints, 1);
for k = 1:nPoints
    okMask(k) = strcmp(colStatus{k}, "ok");
end
nOk = sum(okMask);
fprintf("\n=== Quick Summary ===\n");
fprintf("Total points: %d\n", nPoints);
fprintf("Successfully processed: %d\n", nOk);
if nOk > 0
    fprintf("Mean eval_count: %.0f\n", mean(colEvalCount(okMask)));
    fprintf("Mean elapsed_sec: %.2f\n", mean(colElapsedSec(okMask)));
    fprintf("Mean final_intensity: %.1f\n", mean(colFinalIntensity(okMask)));
    fprintf("Mean deviation_rss_px: %.2f\n", mean(colDevRssPx(okMask)));
    fprintf("Mean phase_FWHM_px: %.2f\n", mean(colPhaseFwhmPx(okMask)));
    fprintf("Mean wl_FWHM_px: %.2f\n", mean(colWlFwhmPx(okMask)));
end

end

% -------------------------------------------------------------------------
function [wavelengthRun, pointLabel] = iParseImagePath(imageDir, imageName)
% Parse directory structure to extract wavelength run name and point label.
% imageName format: point_01_C0_x160_y62_best_image.tif

[~, dirName] = fileparts(imageDir);
wavelengthRun = string(dirName);

% Extract point label from filename: e.g. "point_01_C0_x160_y62" from full name
parts = split(imageName, "_best_image.tif");
pointLabel = string(parts{1});

end

% -------------------------------------------------------------------------
function [methodStr, targetX, targetY, evalCount, elapsedSec, finalIntensity] = ...
    iExtractPointFields(loaded)

methodStr = "";
targetX = NaN;
targetY = NaN;
evalCount = NaN;
elapsedSec = NaN;
finalIntensity = NaN;

if isfield(loaded, "method")
    methodStr = string(loaded.method);
end

% targetInfo is a table row with x_pixel, y_pixel columns
if isfield(loaded, "targetInfo") && ~isempty(loaded.targetInfo)
    ti = loaded.targetInfo;
    if istable(ti)
        if any(strcmp(ti.Properties.VariableNames, "x_pixel"))
            targetX = double(ti.x_pixel);
        end
        if any(strcmp(ti.Properties.VariableNames, "y_pixel"))
            targetY = double(ti.y_pixel);
        end
    elseif isstruct(ti)
        if isfield(ti, "x_pixel"), targetX = double(ti.x_pixel); end
        if isfield(ti, "y_pixel"), targetY = double(ti.y_pixel); end
    end
end

if isfield(loaded, "pointResult") && ~isempty(loaded.pointResult)
    pr = loaded.pointResult;
    if isfield(pr, "evalCount"),             evalCount = double(pr.evalCount); end
    if isfield(pr, "calibrationElapsedSec"), elapsedSec = double(pr.calibrationElapsedSec); end
    if isfield(pr, "finalIntensityMeasured"), finalIntensity = double(pr.finalIntensityMeasured); end
end

end
