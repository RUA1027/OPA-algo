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

[height, width] = size(image);
max_intensity = max(image(:));

row_index = 0;
col_index = 0;
for i = 1:height
    for j = 1:width
        if image(i, j) == max_intensity
            row_index = i;
            col_index = j;
        end
    end
end

peak = struct();
peak.x_pixel = col_index;
peak.y_pixel = row_index;
peak.x_deg   = round(col_index * pixel_angle, 3);
peak.y_deg   = round(row_index * pixel_angle, 3);

end
