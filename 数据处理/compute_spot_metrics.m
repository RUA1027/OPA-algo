function m = compute_spot_metrics(image, targetX, targetY)
%COMPUTE_SPOT_METRICS Extract FWHM, peak position, and target deviation.
%
%   m = compute_spot_metrics(image, targetX, targetY)
%
% Self-contained: all image analysis logic is inlined as local functions.

pixel_angle = 11 / 256;
image = double(image);
image(~isfinite(image)) = 0;

[phaseFwhmDeg, wlFwhmDeg] = iExtractFwhm(image, pixel_angle);
pk = iLocatePeak(image, pixel_angle);

phaseFwhmPx = phaseFwhmDeg / pixel_angle;
wlFwhmPx    = wlFwhmDeg    / pixel_angle;

devXpx = pk.x_pixel - double(targetX);
devYpx = pk.y_pixel - double(targetY);
devXdeg = round(pk.x_deg - double(targetX) * pixel_angle, 3);
devYdeg = round(pk.y_deg - double(targetY) * pixel_angle, 3);

m = struct();
m.phase_FWHM_deg = phaseFwhmDeg;
m.wl_FWHM_deg    = wlFwhmDeg;
m.phase_FWHM_px  = round(phaseFwhmPx, 3);
m.wl_FWHM_px     = round(wlFwhmPx, 3);
m.peak_x_px      = pk.x_pixel;
m.peak_y_px      = pk.y_pixel;
m.peak_x_deg     = pk.x_deg;
m.peak_y_deg     = pk.y_deg;
m.peak_intensity = pk.intensity;
m.deviation_x_px = round(devXpx, 3);
m.deviation_y_px = round(devYpx, 3);
m.deviation_x_deg = devXdeg;
m.deviation_y_deg = devYdeg;
m.deviation_rss_px  = round(sqrt(devXpx^2 + devYpx^2), 3);
m.deviation_rss_deg = round(sqrt(devXdeg^2 + devYdeg^2), 3);

end

% ========================================================================
function [phaseFwhmDeg, wlFwhmDeg] = iExtractFwhm(image, pixel_angle)
if isempty(image) || all(~isfinite(image(:)))
    phaseFwhmDeg = NaN; wlFwhmDeg = NaN; return;
end

[maxVal, linearIdx] = max(image(:));
if maxVal <= 0
    phaseFwhmDeg = NaN; wlFwhmDeg = NaN; return;
end
[rowIdx, colIdx] = ind2sub(size(image), linearIdx);

phaseEnv = image(rowIdx, :);
wlEnv    = image(:, colIdx).';
halfVal = maxVal / 2;

phaseFwhmDeg = round(iProfileFwhm(phaseEnv, colIdx, halfVal) * pixel_angle, 3);
wlFwhmDeg = round(iProfileFwhm(wlEnv, rowIdx, halfVal) * pixel_angle, 3);

end

% ========================================================================
function pk = iLocatePeak(image, pixel_angle)
if isempty(image) || all(~isfinite(image(:)))
    pk = struct("x_pixel", NaN, "y_pixel", NaN, "x_deg", NaN, "y_deg", NaN, "intensity", NaN);
    return;
end

[maxVal, linearIdx] = max(image(:));
[rowIdx, colIdx] = ind2sub(size(image), linearIdx);

pk = struct();
pk.x_pixel = colIdx;
pk.y_pixel = rowIdx;
pk.x_deg   = round(colIdx * pixel_angle, 3);
pk.y_deg   = round(rowIdx * pixel_angle, 3);
pk.intensity = double(maxVal);

end

% ========================================================================
function widthPx = iProfileFwhm(profile, peakIdx, halfValue)
profile = double(profile(:).');
n = numel(profile);
if n == 0 || peakIdx < 1 || peakIdx > n
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

% ========================================================================
function xCross = iLinearCrossing(x1, y1, x2, y2, yCross)
if ~isfinite(y1) || ~isfinite(y2) || abs(y2 - y1) <= eps(max(abs([y1, y2, yCross])) + 1)
    xCross = (x1 + x2) / 2;
else
    xCross = x1 + (yCross - y1) * (x2 - x1) / (y2 - y1);
end
end
