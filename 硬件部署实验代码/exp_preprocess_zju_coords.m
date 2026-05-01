function [coords, summary] = exp_preprocess_zju_coords(csvPath, ccdSpotSize)
%EXP_PREPROCESS_ZJU_COORDS Load and validate wavelength-indexed ZJU target points.

if nargin < 1 || strlength(string(csvPath)) == 0
    csvPath = "smiley_coords.csv";
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
if ~isfinite(ccdSpotSize) || ccdSpotSize <= 0
    error("opa_exp:exp_preprocess_zju_coords:InvalidSpotSize", ...
        "ccdSpotSize must be a positive finite value.");
end

coords = readtable(csvPath, "TextType", "string");
iValidateColumns(coords);

if isempty(coords)
    error("opa_exp:exp_preprocess_zju_coords:EmptyCsv", ...
        "Coordinate CSV has no rows: %s", csvPath);
end

coords.letter = string(coords.letter);
coords.index = double(coords.index);
coords.x_pixel = double(coords.x_pixel);
coords.y_pixel = double(coords.y_pixel);
coords.delta_lambda_nm = double(coords.delta_lambda_nm);
coords.eta_min_to_this_spot = double(coords.eta_min_to_this_spot);
coords.source_order = (1:height(coords)).';

iValidateNumericColumns(coords);

coords.wavelength_nm = 1550 + coords.delta_lambda_nm;
coords.point_id = coords.letter + string(coords.index);

outOfRange = coords.wavelength_nm < 1530 | coords.wavelength_nm > 1570;
if any(outOfRange)
    bad = coords(outOfRange, :);
    error("opa_exp:exp_preprocess_zju_coords:WavelengthOutOfRange", ...
        "Found %d points outside 1530-1570 nm. First bad point: %s at %.3f nm.", ...
        height(bad), bad.point_id(1), bad.wavelength_nm(1));
end

iValidateSingleRowPerWavelength(coords);
iValidateResolvableTargets(coords, ccdSpotSize);

summary = struct();
summary.centerWavelengthNm = 1550;
summary.validRangeNm = [1530, 1570];
summary.precisionDecimals = 3;
summary.selectionPrecisionNm = 1e-3;
summary.ccdSpotSize = ccdSpotSize;
summary.minRequiredHorizontalSeparation = 2 * ccdSpotSize;
summary.numPoints = height(coords);
summary.availableWavelengthNm = unique(coords.wavelength_nm, "stable");
summary.numWavelengthGroups = numel(summary.availableWavelengthNm);

end

function iValidateColumns(coords)
required = ["letter", "index", "x_pixel", "y_pixel", "delta_lambda_nm", "eta_min_to_this_spot"];
actual = string(coords.Properties.VariableNames);
missing = required(~ismember(required, actual));
if ~isempty(missing)
    error("opa_exp:exp_preprocess_zju_coords:MissingColumns", ...
        "Coordinate CSV is missing required columns: %s", strjoin(missing, ", "));
end
end

function iValidateNumericColumns(coords)
numericColumns = ["index", "x_pixel", "y_pixel", "delta_lambda_nm", "eta_min_to_this_spot"];
for ii = 1:numel(numericColumns)
    values = coords.(numericColumns(ii));
    if any(~isfinite(values))
        error("opa_exp:exp_preprocess_zju_coords:InvalidNumericData", ...
            "Column %s contains non-finite values.", numericColumns(ii));
    end
end
end

function iValidateSingleRowPerWavelength(coords)
wavelengths = unique(coords.wavelength_nm, "stable");
for ii = 1:numel(wavelengths)
    wave = wavelengths(ii);
    rows = unique(coords.y_pixel(abs(coords.wavelength_nm - wave) < 1e-12));
    if numel(rows) > 1
        error("opa_exp:exp_preprocess_zju_coords:MultipleRowsForWavelength", ...
            "Wavelength %.3f nm maps to multiple CCD rows: %s.", ...
            wave, strjoin(string(rows.'), ", "));
    end
end
end

function iValidateResolvableTargets(coords, ccdSpotSize)
minRequiredDx = 2 * ccdSpotSize;
wavelengths = unique(coords.wavelength_nm, "stable");

for ii = 1:numel(wavelengths)
    wave = wavelengths(ii);
    group = coords(abs(coords.wavelength_nm - wave) < 1e-12, :);
    if height(group) < 2
        continue;
    end

    x = sort(group.x_pixel);
    dx = diff(x);
    if any(dx <= minRequiredDx)
        [minDx, minIdx] = min(dx);
        error("opa_exp:exp_preprocess_zju_coords:UnresolvableTargets", ...
            "Wavelength %.3f nm row %.0f has unresolvable x pixels %.0f and %.0f: dx %.3g <= required %.3g.", ...
            wave, group.y_pixel(1), x(minIdx), x(minIdx + 1), minDx, minRequiredDx);
    end
end
end
