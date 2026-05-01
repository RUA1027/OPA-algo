function [coords, summary] = exp_preprocess_zju_coords(csvPath, ccdSpotSize)
%EXP_PREPROCESS_ZJU_COORDS Load and validate wavelength-indexed target points.
% The function name is kept for compatibility with the existing call chain.

if nargin < 1 || strlength(string(csvPath)) == 0
    csvPath = iDefaultCoordsCsvPath();
end
if nargin < 2 || isempty(ccdSpotSize)
    cfg = exp_default_config();
    ccdSpotSize = cfg.measure.ccdSpotSize;
end

csvPath = string(csvPath);
ccdSpotSize = double(ccdSpotSize);

if ~isfile(csvPath)
    error("opa_exp:exp_preprocess_zju_coords:MissingCsv", ...
        "Coordinate CSV not found: %s", csvPath);
end
csvInfo = dir(csvPath);
csvPath = string(fullfile(csvInfo(1).folder, csvInfo(1).name));
if ~isfinite(ccdSpotSize) || ccdSpotSize <= 0
    error("opa_exp:exp_preprocess_zju_coords:InvalidSpotSize", ...
        "ccdSpotSize must be a positive finite value.");
end

coords = readtable(csvPath, "TextType", "string");
iValidateColumns(coords);

if height(coords) < 1
    error("opa_exp:exp_preprocess_zju_coords:BadPointCount", ...
        "Coordinate CSV must contain at least one target point.");
end

hasLetter = ismember("letter", string(coords.Properties.VariableNames));
hasWavelength = ismember("wavelength_nm", string(coords.Properties.VariableNames));
coords.index = double(coords.index);
coords.x_pixel = double(coords.x_pixel);
coords.y_pixel = double(coords.y_pixel);
if hasWavelength
    coords.wavelength_nm = double(coords.wavelength_nm);
else
    coords.delta_lambda_nm = double(coords.delta_lambda_nm);
    coords.wavelength_nm = 1550 + coords.delta_lambda_nm;
end
coords.source_order = (1:height(coords)).';

iValidateNumericColumns(coords);

coords.wavelength_nm_0p001 = round(coords.wavelength_nm, 3);
coords.delta_lambda_nm = coords.wavelength_nm - 1550;
if hasLetter
    coords.letter = strip(string(coords.letter));
else
    coords.letter = repmat("F", height(coords), 1);
end
coords.point_id = coords.letter + string(coords.index);

outOfRange = coords.wavelength_nm < 1530 | coords.wavelength_nm > 1570;
if any(outOfRange)
    bad = coords(outOfRange, :);
    error("opa_exp:exp_preprocess_zju_coords:WavelengthOutOfRange", ...
        "Found %d points outside 1530-1570 nm. First bad point: %s at %.3f nm.", ...
        height(bad), bad.point_id(1), bad.wavelength_nm(1));
end

iValidateSingleRowPerWavelength(coords);
iWarnCloseTargets(coords, ccdSpotSize);

summary = struct();
summary.csvPath = csvPath;
summary.centerWavelengthNm = 1550;
summary.validRangeNm = [1530, 1570];
summary.roundingDecimals = 3;
summary.ccdSpotSize = ccdSpotSize;
summary.minRequiredHorizontalSeparation = 2 * ccdSpotSize;
summary.numPoints = height(coords);
summary.availableWavelengthNm = unique(coords.wavelength_nm_0p001, "stable");
summary.numWavelengthGroups = numel(summary.availableWavelengthNm);

end

function csvPath = iDefaultCoordsCsvPath()
thisDir = fileparts(mfilename("fullpath"));
csvPath = fullfile(thisDir, "..", "..", "vision0419", "smiley_coords.csv");
end

function iValidateColumns(coords)
actual = string(coords.Properties.VariableNames);
required = ["index", "x_pixel", "y_pixel"];
missing = required(~ismember(required, actual));
if ~isempty(missing)
    error("opa_exp:exp_preprocess_zju_coords:MissingColumns", ...
        "Coordinate CSV is missing required columns: %s", strjoin(missing, ", "));
end

hasWavelength = ismember("wavelength_nm", actual);
hasDelta = ismember("delta_lambda_nm", actual);
if ~hasWavelength && ~hasDelta
    error("opa_exp:exp_preprocess_zju_coords:MissingColumns", ...
        "Coordinate CSV must contain either wavelength_nm or delta_lambda_nm.");
end
end

function iValidateNumericColumns(coords)
numericColumns = ["index", "x_pixel", "y_pixel", "wavelength_nm"];
for ii = 1:numel(numericColumns)
    values = coords.(numericColumns(ii));
    if any(~isfinite(values))
        error("opa_exp:exp_preprocess_zju_coords:InvalidNumericData", ...
            "Column %s contains non-finite values.", numericColumns(ii));
    end
end
end

function iValidateSingleRowPerWavelength(coords)
wavelengths = unique(coords.wavelength_nm_0p001, "stable");
for ii = 1:numel(wavelengths)
    wave = wavelengths(ii);
    rows = unique(coords.y_pixel(coords.wavelength_nm_0p001 == wave));
    if numel(rows) > 1
        error("opa_exp:exp_preprocess_zju_coords:MultipleRowsForWavelength", ...
            "Rounded wavelength %.3f nm maps to multiple CCD rows: %s.", ...
            wave, strjoin(string(rows.'), ", "));
    end
end
end

function iWarnCloseTargets(coords, ccdSpotSize)
minRequiredDx = 2 * ccdSpotSize;
wavelengths = unique(coords.wavelength_nm_0p001, "stable");
numConflictGroups = 0;
numConflictPairs = 0;
firstMessage = "";

for ii = 1:numel(wavelengths)
    wave = wavelengths(ii);
    group = coords(coords.wavelength_nm_0p001 == wave, :);
    if height(group) < 2
        continue;
    end

    x = sort(group.x_pixel);
    dx = diff(x);
    closeMask = dx <= minRequiredDx;
    if any(closeMask)
        numConflictGroups = numConflictGroups + 1;
        numConflictPairs = numConflictPairs + nnz(closeMask);

        if strlength(firstMessage) == 0
            [minDx, minIdx] = min(dx);
            firstMessage = sprintf( ...
                "First close pair: wavelength %.3f nm row %.0f x %.0f and %.0f, dx %.3g <= suggested %.3g.", ...
                wave, group.y_pixel(1), x(minIdx), x(minIdx + 1), minDx, minRequiredDx);
        end
    end
end

if numConflictGroups > 0
    warning("opa_exp:exp_preprocess_zju_coords:CloseTargets", ...
        "Found %d close x-pixel pair(s) across %d wavelength group(s). %s Calibration is not blocked.", ...
        numConflictPairs, numConflictGroups, firstMessage);
end
end
