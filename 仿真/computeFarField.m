function [thetaDeg, eField, intensity] = computeFarField(controlU, simCfg)
%COMPUTEFARFIELD Compute 1D far field for a control vector.

arguments
    controlU (1,:) double
    simCfg (1,1) struct
end

% 计算全角度的强度分布

thetaDeg = simCfg.thetaGridDeg;
phaseCtrl = mapControlToPhase(controlU, simCfg);
phase0 = simCfg.intrinsicPhaseRad + phaseCtrl;
% 元器件的随机相位（intrinsic phase）和控制相位（control phase）叠加得到总相位。

u = sind(thetaDeg);
% 远场角度对应的空间频率 u = sin(theta)，单位是无量纲的。
% 计算远场时，通常使用空间频率 u 来表示不同的观察角度，因为它直接关系到相位差和干涉条件。
% 由此得到几何相位矩阵 phaseGeom，大小为 numChannels x numTheta。
phaseGeom = simCfg.k * (simCfg.xPositionsM.' * u);
phaseAll = phaseGeom + phase0.';

weightedField = simCfg.amplitude.' .* exp(1i * phaseAll);

% --- 光学串扰：邻道波导倏逝场耦合 ---
% 与热串扰不同，光学串扰作用于电场层面（同时改变幅度和相位），而非控制量层面
% 耦合系数 κ = |κ|·exp(jφ_κ)，φ_κ=π/2 为耦合模理论标准值
if isfield(simCfg, 'opticalCrosstalk') && simCfg.opticalCrosstalk.enable
    kappa = simCfg.opticalCrosstalk.kappaAbs * exp(1i * simCfg.opticalCrosstalk.kappaPhaseRad);
    coupledField = zeros(size(weightedField));
    % 来自左邻道的耦合（通道 2:N 受到通道 1:N-1 的影响）
    coupledField(2:end, :)   = coupledField(2:end, :)   + kappa * weightedField(1:end-1, :);
    % 来自右邻道的耦合（通道 1:N-1 受到通道 2:N 的影响）
    coupledField(1:end-1, :) = coupledField(1:end-1, :) + kappa * weightedField(2:end, :);
    weightedField = weightedField + coupledField;  % 弱耦合近似，直通项不做衰减修正
end
% --- 光学串扰 END ---

eField = sum(weightedField, 1);
intensity = abs(eField).^2;

end
