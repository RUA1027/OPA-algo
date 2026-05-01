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
        wlPosition = func_locate_wl_position(displayState.bestImage);
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
               'Beam Position: ', num2str(wlPosition), char(176), newline, ...
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
