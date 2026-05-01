function measureFn = makeMeasureFunction(simState, cfg, noiseSeed)
%MAKEMEASUREFUNCTION Build objective measurement function handle.
%
% The returned handle evaluates target-angle intensity with optional
% additive relative Gaussian noise and quantization.

arguments
    simState (1,1) struct
    cfg (1,1) struct
    noiseSeed (1,1) double
end

stream = RandStream("mt19937ar", "Seed", noiseSeed);
quantMax = cfg.measurement.quantizationMax;
if isempty(quantMax)
    quantMax = simState.maxTheoreticalIntensity;
end

measureFn = @iMeasure;%保证外部函数可直接 measureFn(controlU) 调用

    function y = iMeasure(controlU)
        % DAC 驱动电路噪声：模拟DAC输出端的随机扰动（电源纹波、热噪声等）
        % 每次调用产生独立噪声实例，符合物理现实；仅在测量路径生效，不影响真值评估
        if isfield(cfg.sim, 'dac') && cfg.sim.dac.enable && cfg.sim.dac.driverNoiseStd > 0
            controlU = controlU + cfg.sim.dac.driverNoiseStd * randn(stream, 1, numel(controlU));
            controlU = min(max(controlU, simState.controlMin), simState.controlMax);  % 截断到合法范围
        end

        y = computeTargetIntensity(controlU, simState);

        if cfg.measurement.enableNoise
            sigma = cfg.measurement.relativeNoiseStd * max(y, 1);
            y = y + sigma * randn(stream, 1, 1);
            y = max(y, 0);
        end

        if cfg.measurement.enableQuantization
            levels = 2^cfg.measurement.quantizationBits - 1;
            y = min(max(y, 0), quantMax);
            y = round(y / quantMax * levels) / levels * quantMax;
        end
    end

end
