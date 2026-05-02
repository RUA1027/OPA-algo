function [phase_FWHM, wl_FWHM] = func_extract_FWHM(image)
%FUNC_EXTRACT_FWHM Extract phase- and wavelength-direction FWHM from an image.
%
% The CCD field of view is treated as 11 deg / 256 px, matching the legacy
% display code. The width is interpolated at the half-maximum crossings so
% the result remains valid when the crossing lies between two pixels.

pixel_angle = 11 / 256;
image = double(image);

if isempty(image) || ~ismatrix(image) || all(~isfinite(image(:)))
    phase_FWHM = NaN;
    wl_FWHM = NaN;
    return;
end

image(~isfinite(image)) = 0;
[max_intensity, linearIdx] = max(image(:));
if max_intensity <= 0
    phase_FWHM = NaN;
    wl_FWHM = NaN;
    return;
end

[row_index, col_index] = ind2sub(size(image), linearIdx);

phase_envelope = image(row_index, :);
wl_envelope = image(:, col_index).';
half_intensity = max_intensity / 2;

phase_FWHM = round(iProfileFwhm(phase_envelope, col_index, half_intensity) * pixel_angle, 3);
wl_FWHM = round(iProfileFwhm(wl_envelope, row_index, half_intensity) * pixel_angle, 3);

end

function widthPx = iProfileFwhm(profile, peakIdx, halfValue)
profile = double(profile(:).');
n = numel(profile);

if n == 0 || peakIdx < 1 || peakIdx > n || ~isfinite(halfValue)
    widthPx = NaN;
    return;
end

leftIdx = peakIdx;
while leftIdx > 1 && profile(leftIdx) >= halfValue
    leftIdx = leftIdx - 1;
end
if leftIdx == 1 && profile(leftIdx) >= halfValue
    leftCross = 1;
else
    leftCross = iLinearCrossing(leftIdx, profile(leftIdx), leftIdx + 1, profile(leftIdx + 1), halfValue);
end

rightIdx = peakIdx;
while rightIdx < n && profile(rightIdx) >= halfValue
    rightIdx = rightIdx + 1;
end
if rightIdx == n && profile(rightIdx) >= halfValue
    rightCross = n;
else
    rightCross = iLinearCrossing(rightIdx - 1, profile(rightIdx - 1), rightIdx, profile(rightIdx), halfValue);
end

widthPx = max(0, rightCross - leftCross);
end

function xCross = iLinearCrossing(x1, y1, x2, y2, yCross)
if ~isfinite(y1) || ~isfinite(y2) || abs(y2 - y1) <= eps(max(abs([y1, y2, yCross])) + 1)
    xCross = (x1 + x2) / 2;
else
    xCross = x1 + (yCross - y1) * (x2 - x1) / (y2 - y1);
end
end
