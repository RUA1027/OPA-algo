function m = compute_spot_metrics(image, targetX, targetY)
%COMPUTE_SPOT_METRICS Extract FWHM, peak position, and target deviation.
%
%   m = compute_spot_metrics(image, targetX, targetY)
%
% Self-contained: all image analysis logic is inlined as local functions.

pixel_angle = 11 / 256;

image = double(image);

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
m.deviation_x_px = round(devXpx, 3);
m.deviation_y_px = round(devYpx, 3);
m.deviation_x_deg = devXdeg;
m.deviation_y_deg = devYdeg;
m.deviation_rss_px  = round(sqrt(devXpx^2 + devYpx^2), 3);
m.deviation_rss_deg = round(sqrt(devXdeg^2 + devYdeg^2), 3);

end

% ========================================================================
function [phaseFwhmDeg, wlFwhmDeg] = iExtractFwhm(image, pixel_angle)
[height, width] = size(image);
maxVal = max(image(:));

rowIdx = 0;
colIdx = 0;
for i = 1:height
    for j = 1:width
        if image(i, j) == maxVal
            rowIdx = i;
            colIdx = j;
        end
    end
end

if rowIdx == 0 || colIdx == 0
    phaseFwhmDeg = NaN; wlFwhmDeg = NaN; return;
end

phaseEnv = image(rowIdx, :);
wlEnv    = image(:, colIdx);

% Phase-direction FWHM
leftB = 1;
for i = 1:colIdx
    if phaseEnv(i) > maxVal / 2, leftB = i; break; end
end
rightB = width;
for i = colIdx:width
    if phaseEnv(i) < maxVal / 2, rightB = i - 1; break; end
end
phaseFwhmDeg = round((rightB - leftB) * pixel_angle, 3);

% Wavelength-direction FWHM
leftB = 1;
for i = 1:rowIdx
    if wlEnv(i) > maxVal / 2, leftB = i; break; end
end
rightB = height;
for i = rowIdx:height
    if wlEnv(i) < maxVal / 2, rightB = i - 1; break; end
end
wlFwhmDeg = round((rightB - leftB) * pixel_angle, 3);

end

% ========================================================================
function pk = iLocatePeak(image, pixel_angle)
[height, width] = size(image);
maxVal = max(image(:));

rowIdx = 0;
colIdx = 0;
for i = 1:height
    for j = 1:width
        if image(i, j) == maxVal
            rowIdx = i;
            colIdx = j;
        end
    end
end

pk = struct();
pk.x_pixel = colIdx;
pk.y_pixel = rowIdx;
pk.x_deg   = round(colIdx * pixel_angle, 3);
pk.y_deg   = round(rowIdx * pixel_angle, 3);

end
