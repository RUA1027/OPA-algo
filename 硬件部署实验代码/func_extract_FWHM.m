function [phase_FWHM, wl_FWHM] = func_extract_FWHM(image)
    % 计算光斑的发散角
    
    % 256像素点对应11°视场
    pixel_angle = 11/256;

    [height, width] = size(image);
    
    max_intensity = max(max(image));
    row_index = 0;
    coloum_index = 0;
    for i = 1: height
        for j = 1: width
            if image(i, j) == max_intensity
                row_index = i;
                coloum_index = j;
            end
        end
    end

    phase_envelope = image(row_index, :);
    wl_envelope = image(:, coloum_index);
    
    % 首先提取相位方向FWHM
    left_bound = 0;
    right_bound = 0;
    for i = 1 : coloum_index
        if phase_envelope(i) > max_intensity/2
            left_bound = i;
            break;
        end
    end
    for i = coloum_index : width
        if phase_envelope(i) < max_intensity/2
            right_bound = i-1;
            break;
        end
    end
    phase_FWHM = (right_bound - left_bound)*pixel_angle;
    phase_FWHM = round(phase_FWHM, 3);

    % 随后提取波长方向FWHM
    left_bound = 0;
    right_bound = 0;
    for i = 1 : row_index
        if wl_envelope(i) > max_intensity/2
            left_bound = i;
            break;
        end
    end
    for i = row_index : height
        if wl_envelope(i) < max_intensity/2
            right_bound = i-1;
            break;
        end
    end
    wl_FWHM = (right_bound - left_bound)*pixel_angle;
    wl_FWHM = round(wl_FWHM, 3);

end