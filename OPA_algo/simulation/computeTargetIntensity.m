function intensity = computeTargetIntensity(controlU, simState)
%COMPUTETARGETINTENSITY Compute far-field intensity at target angle.

arguments
    controlU (1,:) double
    simState (1,1) struct
end

% 计算目标角度的远场强度，供优化算法评估使用。
phaseCtrl = mapControlToPhase(controlU, simState);
phaseTotal = simState.intrinsicPhaseRad + phaseCtrl + simState.k * simState.xPositionsM * simState.targetUSin;
channelFields = simState.amplitude .* exp(1i * phaseTotal);  % 各通道复电场（1×N）

% --- 光学串扰：邻道波导倏逝场耦合 ---
if isfield(simState, 'opticalCrosstalk') && simState.opticalCrosstalk.enable
    kappa = simState.opticalCrosstalk.kappaAbs * exp(1i * simState.opticalCrosstalk.kappaPhaseRad);
    coupled = zeros(size(channelFields));
    coupled(2:end)   = coupled(2:end)   + kappa * channelFields(1:end-1);  % 左邻道耦合
    coupled(1:end-1) = coupled(1:end-1) + kappa * channelFields(2:end);    % 右邻道耦合
    channelFields = channelFields + coupled;
end
% --- 光学串扰 END ---

fieldTarget = sum(channelFields);
intensity = abs(fieldTarget)^2;

end
