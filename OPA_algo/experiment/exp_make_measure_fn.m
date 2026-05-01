function measureFn = exp_make_measure_fn(hw, cfg)
%EXP_MAKE_MEASURE_FN Build hardware-backed measurement callback.
% Input controlU is in U-domain (U = V^2).

arguments
    hw (1,1) struct
    cfg (1,1) struct
end

measureFn = @iMeasure;

    function [y, sensorInfo] = iMeasure(controlU)
        validateattributes(controlU, {'numeric'}, {'vector', 'numel', cfg.numChannels});

        controlU = reshape(double(controlU), 1, []);
        controlU = min(max(controlU, cfg.controlMin), cfg.controlMax);

        voltage = sqrt(max(controlU, 0));
        voltageAllChannels = func_V_transition(voltage);
        ZJY_256VSRC_WRITE(hw.serialObj, voltageAllChannels);

        if cfg.measure.delaySec > 0
            pause(cfg.measure.delaySec);
        end

        [y, sensorInfo] = iReadSensor();
        if ~isfinite(y)
            error("opa_exp:exp_make_measure_fn:InvalidMeasurement", "Non-finite sensor reading.");
        end
    end

    function [y, sensorInfo] = iReadSensor()
        sensorInfo = struct();

        switch hw.sensorMode
            case "CCD"
                sampleTimes = max(1, cfg.measure.sampleTimes);
                yAcc = 0;
                lastImage = [];
                for ii = 1:sampleTimes
                    if cfg.measure.delaySec > 0
                        pause(cfg.measure.delaySec);
                    end
                    img = double(getsnapshot(hw.videoObj));
                    lastImage = img;
                    cols = iCcdCols(size(img, 2), cfg.measure.ccdCenterCol, cfg.measure.ccdSpotSize);
                    yAcc = yAcc + sum(sum(img(:, cols)));
                end
                y = yAcc / sampleTimes;
                sensorInfo.image = lastImage;
                sensorInfo.peakIntensity = max(lastImage, [], "all");

            case "DSO"
                sampleTimes = max(1, cfg.measure.sampleTimes);
                yAcc = 0;
                for ii = 1:sampleTimes
                    yAcc = yAcc + func_DSO_read(hw.dsoObj);
                end
                y = yAcc / sampleTimes;

            case "CAPTURE_CARD"
                sampleNum = hw.capture.sampleNum;
                sampleTimes = max(1, hw.capture.sampleTimes);
                data = zeros(1, sampleNum, "single");
                dataPtr = libpointer("singlePtr", data);
                allData = zeros(1, sampleTimes * sampleNum);

                for ii = 1:sampleTimes
                    calllib("USB3000", "SetUSB3ClrAiFifo", 0);
                    calllib("USB3000", "USB3GetAi", 0, sampleNum, dataPtr, 1000);
                    data = get(dataPtr, "Value");
                    allData((ii - 1) * sampleNum + 1:ii * sampleNum) = data(1:sampleNum);
                    calllib("USB3000", "SetUSB3ClrAiFifo", 0);
                end
                y = mean(allData);

            otherwise
                error("opa_exp:exp_make_measure_fn:InvalidSensorMode", "Unsupported sensor mode: %s", hw.sensorMode);
        end
    end

end

function cols = iCcdCols(totalCols, centerCol, spotSize)
halfWidth = floor(spotSize / 2);
left = max(1, round(centerCol) - halfWidth);
right = min(totalCols, round(centerCol) + halfWidth);
cols = left:right;
end
