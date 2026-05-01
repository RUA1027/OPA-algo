function [targets, preprocessSummary] = exp_select_wavelength_targets(csvPath, wavelengthNm, ccdSpotSize)
%EXP_SELECT_WAVELENGTH_TARGETS Select all targets for one rounded wavelength.

if nargin < 1 || strlength(string(csvPath)) == 0
    csvPath = "";
end
if nargin < 2 || isempty(wavelengthNm)
    error("opa_exp:exp_select_wavelength_targets:MissingWavelength", ...
        "An absolute wavelength in nm is required.");
end
if nargin < 3 || isempty(ccdSpotSize)
    cfg = exp_default_config();
    ccdSpotSize = cfg.measure.ccdSpotSize;
end

[coords, preprocessSummary] = exp_preprocess_zju_coords(csvPath, ccdSpotSize);

matchedWavelength = round(double(wavelengthNm), 3);
isMatch = abs(coords.wavelength_nm_0p001 - matchedWavelength) < 1e-12;
targets = coords(isMatch, :);

if isempty(targets)
    available = strjoin(compose("%.3f", preprocessSummary.availableWavelengthNm), ", ");
    error("opa_exp:exp_select_wavelength_targets:NoTargets", ...
        "No targets for rounded wavelength %.3f nm. Available wavelengths: %s.", ...
        matchedWavelength, available);
end

targets = sortrows(targets, "source_order");

end
