function wl_position = func_locate_wl_position(image)
%FUNC_LOCATE_WL_POSITION Locate the wavelength-direction peak position.

peak = func_locate_peak(image);
wl_position = peak.y_deg;

end
