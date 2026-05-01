function [wl_position] = func_locate_wl_position(image)
    % 定位光斑的相位方向位置
    
    % 256像素点对应11°视场
    pixel_angle = 11/256;

    [height, width] = size(image);
    
    max_intensity = max(max(image));
    row_index = 0;
    for i = 1: height
        for j = 1: width
            if image(i, j) == max_intensity
                row_index = i;
            end
        end
    end

    wl_position = row_index * pixel_angle;
    wl_position = round(wl_position, 3);

end