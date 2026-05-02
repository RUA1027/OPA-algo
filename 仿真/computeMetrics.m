function metrics = computeMetrics(thetaDeg, intensity, targetThetaDeg)
%COMPUTEMETRICS Compute common 1D far-field metrics.
%
% Output fields:
%   smsrDb              Side-mode suppression ratio (dB).
%   beamwidth3dBDeg     Main-lobe 3 dB width (deg).
%   mainPeak            Main peak intensity.
%   mainPeakThetaDeg    Peak angle (deg).
%   pointingErrorDeg    mainPeakThetaDeg - targetThetaDeg.
%   targetIntensity     Intensity at target angle.
%   targetIntensityNorm Target intensity normalized by main peak.

arguments
    thetaDeg (1,:) double
    intensity (1,:) double
    targetThetaDeg (1,1) double
end
% 若输入不符合，MATLAB 会自动报错并提示。

intensity = max(double(intensity), 0);

% Find main lobe NEAR target angle (not globally) to avoid grating-lobe misidentification.
% Grating-lobe spacing: delta_sin = lambda/d. Half-spacing in degrees ≈ 11 deg for typical OPA.
searchWindowDeg = 8; % ±8 deg 搜索窗口，覆盖主瓣及其附近的潜在格栅瓣，避免远离目标角的强格栅瓣被误识为主瓣。
inWindow = abs(thetaDeg - targetThetaDeg) <= searchWindowDeg;
if any(inWindow)
    windowIntensity = intensity;
    windowIntensity(~inWindow) = -inf;
    [mainPeak, mainIdx] = max(windowIntensity);
else
    [mainPeak, mainIdx] = max(intensity);
end

if mainPeak <= 0
    metrics = struct( ...
        "smsrDb", -Inf, ...
        "slsrDb", -Inf, ...
        "mainSideContrastDb", -Inf, ...
        "beamwidth3dBDeg", NaN, ...
        "fwhmDeg", NaN, ...
        "beamDivergenceDeg", NaN, ...
        "mainPeak", 0, ...
        "sidePeak", 0, ...
        "targetIntensity", 0, ...
        "targetIntensityNorm", 0, ...
        "mainLobePowerRatio", 0, ...
        "mainPeakThetaDeg", thetaDeg(mainIdx), ...
        "targetThetaDeg", targetThetaDeg, ...
        "pointingErrorDeg", NaN, ...
        "pointingErrorAbsDeg", NaN, ...
        "fwhmLeftThetaDeg", NaN, ...
        "fwhmRightThetaDeg", NaN, ...
        "mainLobeLeftThetaDeg", NaN, ...
        "mainLobeRightThetaDeg", NaN);
    return;
end

halfPower = mainPeak / 2;
[fwhmLeftTheta, fwhmRightTheta] = iHalfPowerCrossings(thetaDeg, intensity, mainIdx, halfPower);
beamwidth3dBDeg = fwhmRightTheta - fwhmLeftTheta;

% Define main-lobe region as ±2*FWHM around peak (robust against grating lobes)
mainLobeHalfDeg = 2.0 * beamwidth3dBDeg;
inMainLobe = abs(thetaDeg - thetaDeg(mainIdx)) <= mainLobeHalfDeg;
outside = intensity;
outside(inMainLobe) = 0;
sidePeak = max(outside);

[nullLeft, nullRight] = iMainLobeNullBounds(intensity, mainIdx);
% Fallback: use the larger of the two main-lobe masks for power integration
lobeMask = inMainLobe | ((1:numel(intensity)) >= nullLeft & (1:numel(intensity)) <= nullRight);
lobeLeft = find(lobeMask, 1, 'first');
lobeRight = find(lobeMask, 1, 'last');

if sidePeak <= 0
    smsrDb = Inf;
else
    smsrDb = 10 * log10(mainPeak / sidePeak);
end

[~, targetIdx] = min(abs(thetaDeg - targetThetaDeg));
targetIntensity = intensity(targetIdx);

totalPower = trapz(thetaDeg, intensity);
if totalPower > 0 && lobeLeft <= lobeRight
    mainLobePower = trapz(thetaDeg(lobeLeft:lobeRight), intensity(lobeLeft:lobeRight));
    mainLobePowerRatio = min(max(mainLobePower / totalPower, 0), 1);
else
    mainLobePowerRatio = 0;
end
% =========================================================

metrics = struct();
metrics.smsrDb = smsrDb;
metrics.slsrDb = slsrDb;
metrics.mainSideContrastDb = smsrDb;
metrics.beamwidth3dBDeg = beamwidth3dBDeg;
metrics.fwhmDeg = beamwidth3dBDeg;
metrics.beamDivergenceDeg = beamwidth3dBDeg;
metrics.mainPeak = mainPeak;
metrics.sidePeak = sidePeak;
metrics.mainPeakThetaDeg = thetaDeg(mainIdx);
metrics.targetThetaDeg = targetThetaDeg;
metrics.pointingErrorDeg = thetaDeg(mainIdx) - targetThetaDeg;
metrics.pointingErrorAbsDeg = abs(metrics.pointingErrorDeg);
metrics.fwhmLeftThetaDeg = fwhmLeftTheta;
metrics.fwhmRightThetaDeg = fwhmRightTheta;
metrics.mainLobeLeftThetaDeg = thetaDeg(lobeLeft);
metrics.mainLobeRightThetaDeg = thetaDeg(lobeRight);
metrics.targetIntensity = targetIntensity;
metrics.targetIntensityNorm = targetIntensity / mainPeak;
metrics.mainLobePowerRatio = mainLobePowerRatio;

end

function [leftTheta, rightTheta] = iHalfPowerCrossings(thetaDeg, intensity, peakIdx, halfPower)
n = numel(intensity);

leftIdx = peakIdx;
while leftIdx > 1 && intensity(leftIdx) >= halfPower
    leftIdx = leftIdx - 1;
end
if leftIdx == 1 && intensity(leftIdx) >= halfPower
    leftTheta = thetaDeg(1);
else
    leftTheta = iLinearCrossing(thetaDeg(leftIdx), intensity(leftIdx), ...
        thetaDeg(leftIdx + 1), intensity(leftIdx + 1), halfPower);
end

rightIdx = peakIdx;
while rightIdx < n && intensity(rightIdx) >= halfPower
    rightIdx = rightIdx + 1;
end
if rightIdx == n && intensity(rightIdx) >= halfPower
    rightTheta = thetaDeg(n);
else
    rightTheta = iLinearCrossing(thetaDeg(rightIdx - 1), intensity(rightIdx - 1), ...
        thetaDeg(rightIdx), intensity(rightIdx), halfPower);
end
end

function thetaCross = iLinearCrossing(theta1, y1, theta2, y2, yCross)
if abs(y2 - y1) <= eps(max(abs([y1, y2, yCross])) + 1)
    thetaCross = (theta1 + theta2) / 2;
else
    thetaCross = theta1 + (yCross - y1) * (theta2 - theta1) / (y2 - y1);
end
end

function [nullLeft, nullRight] = iMainLobeNullBounds(intensity, peakIdx)
n = numel(intensity);

nullLeft = peakIdx;
while nullLeft > 1 && intensity(nullLeft - 1) <= intensity(nullLeft)
    nullLeft = nullLeft - 1;
end

nullRight = peakIdx;
while nullRight < n && intensity(nullRight + 1) <= intensity(nullRight)
    nullRight = nullRight + 1;
end
end
