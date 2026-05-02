function displayState = exp_update_realtime_display(displayState, measuredIntensity, sensorInfo, controlU, progressInfo)
%EXP_UPDATE_REALTIME_DISPLAY Refresh calibration display after one channel update.

arguments
    displayState (1,1) struct
    measuredIntensity (1,1) double
    sensorInfo (1,1) struct
    controlU (1,:) double
    progressInfo (1,1) struct
end

if displayState.isCcd && isfield(sensorInfo, "image") && ~isempty(sensorInfo.image)
    currentImage = sensorInfo.image;

    if max(max(currentImage)) > displayState.bestIntensity
        displayState.bestIntensity = max(max(currentImage));
        displayState.bestImage = currentImage;
        displayState.bestControlU = controlU;
        displayState.bestRoundIdx = progressInfo.roundIdx;
        displayState.bestChannelIdx = progressInfo.channelIdx;
    end
else
    if measuredIntensity > displayState.bestIntensity
        displayState.bestIntensity = measuredIntensity;
        displayState.bestControlU = controlU;
        displayState.bestRoundIdx = progressInfo.roundIdx;
        displayState.bestChannelIdx = progressInfo.channelIdx;
    end
end

displayState.intensityHistory(end + 1) = measuredIntensity;

if ~displayState.enabled
    return;
end

if isempty(displayState.figureHandle) || ~isgraphics(displayState.figureHandle)
    displayState.figureHandle = figure(displayState.figureNumber);
    set(displayState.figureHandle, 'Name', char(displayState.figureName), 'NumberTitle', 'off');
else
    figure(displayState.figureHandle);
end

if displayState.isCcd && isfield(sensorInfo, "image") && ~isempty(sensorInfo.image)
    currentImage = sensorInfo.image;

    if max(max(currentImage)) >= displayState.saturationThreshold
        disp('红外CCD过曝！请尽快处理！');
        sound(sin(2*pi*25*(1:6000)/200));
    end

    if isequal(displayState.bestControlU, controlU)

        [phaseFwhm, wlFwhm] = func_extract_FWHM(displayState.bestImage);
        peak = func_locate_peak(displayState.bestImage);
        displayState.bestPhaseFwhmDeg = phaseFwhm;
        displayState.bestWlFwhmDeg = wlFwhm;
        displayState.bestPeak = peak;
        displayState.bestPeakXPixel = peak.x_pixel;
        displayState.bestPeakYPixel = peak.y_pixel;
        displayState.bestPeakXDeg = peak.x_deg;
        displayState.bestPeakYDeg = peak.y_deg;
        displayState.bestBeamPositionDeg = peak.y_deg;
        displayState = iUpdateTargetDeviation(displayState);
        bestImageClim = iMakeDynamicImageClim(displayState.bestImage);

        subplot(1, 3, 3);
        imagesc(displayState.bestImage);
        axis image;
        clim(bestImageClim);
        drawnow;
        colorbar;
        colormap('gray');
        title(['Best Image', newline, ...
               'FWHM = ', num2str(phaseFwhm), char(176), char(215), num2str(wlFwhm), char(176), newline, ...
               'Peak = (', num2str(peak.x_pixel), ', ', num2str(peak.y_pixel), ') px', newline, ...
               'Target Error = ', num2str(displayState.bestTargetDeviationRssPixel), ' px', newline, ...
               'Best @ Round ', num2str(displayState.bestRoundIdx), ...
               ', Ch ', num2str(displayState.bestChannelIdx)]);
    end

    figure(displayState.figureHandle);
    subplot(1, 3, 1);
    plot(displayState.intensityHistory);
    grid on;
    xlabel('Channel Update Index');
    ylabel('Measured Intensity');
    title(['Intensity History', newline, ...
           char(progressInfo.methodName), ...
           ' | Round ', num2str(progressInfo.roundIdx), ...
           ' | Ch ', num2str(progressInfo.channelIdx)]);

    subplot(1, 3, 2);
    imagesc(currentImage);
    axis image;
    clim(iMakeDynamicImageClim(currentImage));
    drawnow;
    colorbar;
    colormap('gray');
    title(['Current Image', newline, ...
           char(progressInfo.methodName), ...
           ' | Round ', num2str(progressInfo.roundIdx), ...
           ' | Ch ', num2str(progressInfo.channelIdx)]);
else
    figure(displayState.figureHandle);
    subplot(1, 1, 1);
    plot(displayState.intensityHistory);
    grid on;
    xlabel('Channel Update Index');
    ylabel('Measured Intensity');
    title([char(progressInfo.methodName), ...
           ' | Round ', num2str(progressInfo.roundIdx), ...
           ' | Ch ', num2str(progressInfo.channelIdx)]);
end

end

function imageClim = iMakeDynamicImageClim(imageData)
maxValue = max(imageData(:));
if maxValue <= 0
    maxValue = 1;
end
imageClim = [0, maxValue];
end

function displayState = iUpdateTargetDeviation(displayState)
pixelAngle = 11 / 256;

if ~isfinite(displayState.targetXPixel) || ~isfinite(displayState.targetYPixel) || ...
        ~isfinite(displayState.bestPeakXPixel) || ~isfinite(displayState.bestPeakYPixel)
    return;
end

dxPx = displayState.bestPeakXPixel - displayState.targetXPixel;
dyPx = displayState.bestPeakYPixel - displayState.targetYPixel;
displayState.bestTargetDeviationXPixel = dxPx;
displayState.bestTargetDeviationYPixel = dyPx;
displayState.bestTargetDeviationRssPixel = round(hypot(dxPx, dyPx), 3);
displayState.bestTargetDeviationXDeg = round(dxPx * pixelAngle, 3);
displayState.bestTargetDeviationYDeg = round(dyPx * pixelAngle, 3);
displayState.bestTargetDeviationRssDeg = round(displayState.bestTargetDeviationRssPixel * pixelAngle, 3);
end
