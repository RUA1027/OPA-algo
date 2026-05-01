function phaseRad = mapControlToPhase(controlU, simCfg)
%MAPCONTROLTOPHASE Convert heater control vector to phase with crosstalk.
%
% Input:
%   controlU (1,N) double Heater control value (proportional to V^2).
%   simCfg   (struct) State/config struct with phasePerU and crossTalkRatio.
%
% Output:
%   phaseRad (1,N) double Controlled phase in radians.

arguments
    controlU (1,:) double
    simCfg (1,1) struct
end

uEff = controlU;

% === DAC 量化（确定性操作，在热串扰之前施加） ===
% 物理顺序：DAC离散化发生在电压施加到加热器的瞬间，热串扰是之后的热扩散过程
if isfield(simCfg, 'dac') && simCfg.dac.enable
    bits = simCfg.dac.bits;
    uMin = simCfg.controlMin;
    uMax = simCfg.controlMax;
    levels = 2^bits - 1;  % 例如12位→4095个量化级别
    % 均匀量化：归一化→量化→反归一化
    uNorm = min(max((uEff - uMin) / (uMax - uMin), 0), 1);  % 归一化到[0,1]并截断越界值
    uEff = round(uNorm * levels) / levels * (uMax - uMin) + uMin;
end
% === DAC 量化 END ===

% 一阶热串扰（邻道加热功率的热扩散）
ct = simCfg.crossTalkRatio;
if ct ~= 0
    uPost = uEff;  % 保存当前值（含DAC量化），邻道感受到的是量化后的实际施加值
    uEff(2:end)   = uEff(2:end)   + ct * uPost(1:end-1); % 左邻道串扰
    uEff(1:end-1) = uEff(1:end-1) + ct * uPost(2:end);   % 右邻道串扰
end

phaseRad = simCfg.phasePerU * uEff;

end
