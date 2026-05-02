function peak = func_locate_peak(image)
%FUNC_LOCATE_PEAK Locate peak position in both phase and wavelength directions.
%
%   peak = func_locate_peak(image)
%
% Input:
%   image  2D image matrix (double or uint16)
%
% Output:
%   peak   struct with fields:
%         x_pixel, y_pixel  — column/row index of brightest pixel (1-indexed)
%         x_deg,   y_deg    — angular position (deg), based on 11 deg / 256 px

pixel_angle = 11 / 256;
image = double(image);

if isempty(image) || ~ismatrix(image) || all(~isfinite(image(:)))
    peak = struct("x_pixel", NaN, "y_pixel", NaN, "x_deg", NaN, "y_deg", NaN, "intensity", NaN);
    return;
end

image(~isfinite(image)) = -Inf;
[max_intensity, linearIdx] = max(image(:));
[row_index, col_index] = ind2sub(size(image), linearIdx);

peak = struct();
peak.x_pixel = col_index;
peak.y_pixel = row_index;
peak.x_deg   = round(col_index * pixel_angle, 3);
peak.y_deg   = round(row_index * pixel_angle, 3);
peak.intensity = double(max_intensity);

end
