function metrics = computeMetrics(thetaDeg, intensity, targetThetaDeg)
%COMPUTEMETRICS Compute common 1D far-field metrics.
%
% Output fields:
%   smsrDb              Side-mode suppression ratio (dB).
%   beamwidth3dBDeg     Main-lobe 3 dB width (deg).
%   mainPeak            Main peak intensity.
%   targetIntensity     Intensity at target angle.
%   targetIntensityNorm Target intensity normalized by main peak.

arguments
    thetaDeg (1,:) double
    intensity (1,:) double
    targetThetaDeg (1,1) double
end
% 若输入不符合，MATLAB 会自动报错并提示。

intensity = max(double(intensity), 0);
[mainPeak, mainIdx] = max(intensity);

if mainPeak <= 0
    metrics = struct( ...
        "smsrDb", -Inf, ...
        "beamwidth3dBDeg", NaN, ...
        "mainPeak", 0, ...
        "targetIntensity", 0, ...
        "targetIntensityNorm", 0, ...
        "mainLobePowerRatio", 0, ...
        "mainPeakThetaDeg", thetaDeg(mainIdx));
    return;
end

halfPower = mainPeak / 2;
leftIdx = mainIdx;
while leftIdx > 1 && intensity(leftIdx) >= halfPower
    leftIdx = leftIdx - 1;
end
rightIdx = mainIdx;
while rightIdx < numel(intensity) && intensity(rightIdx) >= halfPower
    rightIdx = rightIdx + 1;
end
beamwidth3dBDeg = thetaDeg(rightIdx) - thetaDeg(leftIdx);

outside = intensity;
outside(leftIdx:rightIdx) = 0;
% 将主瓣区间置零，只保留副瓣和噪声的强度。
sidePeak = max(outside);
if sidePeak <= 0
    smsrDb = Inf;
else
    smsrDb = 10 * log10(mainPeak / sidePeak);
end

[~, targetIdx] = min(abs(thetaDeg - targetThetaDeg));
targetIntensity = intensity(targetIdx);

% === 新增：计算主瓣能量占比 (Main Lobe Power Ratio) ===
% 1. 向左寻找左侧零陷点（谷底）
nullLeft = mainIdx;
while nullLeft > 1 && intensity(nullLeft - 1) <= intensity(nullLeft)
    nullLeft = nullLeft - 1;
end

% 2. 向右寻找右侧零陷点（谷底）
nullRight = mainIdx;
while nullRight < numel(intensity) && intensity(nullRight + 1) <= intensity(nullRight)
    nullRight = nullRight + 1;
end

% 3. 使用 trapz 进行数值积分计算能量
totalPower = trapz(thetaDeg, intensity);
if totalPower > 0 && nullLeft <= nullRight
    mainLobePower = trapz(thetaDeg(nullLeft:nullRight), intensity(nullLeft:nullRight));
    mainLobePowerRatio = min(max(mainLobePower / totalPower, 0), 1);
else
    mainLobePowerRatio = 0;
end
% =========================================================

metrics = struct();
metrics.smsrDb = smsrDb;
metrics.beamwidth3dBDeg = beamwidth3dBDeg;
metrics.mainPeak = mainPeak;
metrics.mainPeakThetaDeg = thetaDeg(mainIdx);
metrics.targetIntensity = targetIntensity;
metrics.targetIntensityNorm = targetIntensity / mainPeak;
metrics.mainLobePowerRatio = mainLobePowerRatio;

end
