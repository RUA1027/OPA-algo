function result = exp_quickstart(method, wavelengthNm, varargin)
%EXP_QUICKSTART Minimal example for unified experiment calibration.
%
% Example:
%   result = exp_quickstart("mREV-GSS");
%   result = exp_quickstart("5PPS");
%   result = exp_quickstart("PFPD");
%   result = exp_quickstart("mREV");
%   result = exp_quickstart("mREV-GSS", 1550);
%   result = exp_quickstart("5pps", 1534.658); 在命令行窗口就这样输入即可快速启动实验。


% 控制台输出校准方法、评估次数、最终测量强度等，方便查看实验结果。
% 只需传入校准方法名，就能自动完成「配置加载→执行校准→结果输出」全流程
% 无需手动配置参数，快速启动实验，自动处理默认参数，屏蔽底层复杂配置，易用性强。
%
% 推荐使用方式：
% 1) 日常实验调试：直接调用 exp_quickstart("mREV-GSS") 等。
% 2) 需要细粒度控制：先 cfg = exp_default_config(); 再修改 cfg 后调用 exp_run_calibration(cfg)。
% 3) 无硬件联调：在 cfg.runtime.mockMeasureFn 注入测量函数后再调用 exp_run_calibration(cfg)。

if nargin < 1 || strlength(string(method)) == 0
    method = "mREV-GSS"; % Default method if none provided
end

if nargin >= 2 && ~isempty(wavelengthNm)
    if ~isempty(varargin) && isstruct(varargin{1})
        cfg = varargin{1};
        extraArgs = varargin(2:end);
    else
        cfg = exp_default_config();
        extraArgs = varargin;
    end

    cfg.method = string(method);
    result = exp_run_wavelength_calibration(string(method), wavelengthNm, cfg, extraArgs{:});

    fprintf("Method: %s\n", string(method));
    fprintf("Wavelength: %.3f nm\n", result.matchedWavelengthNm);
    fprintf("Target count: %d\n", result.targetCount);
    fprintf("Output directory: %s\n", result.outputDir);
    return;
end

% 加载默认配置，并覆盖方法名。
cfg = exp_default_config();
cfg.method = string(method);

% If you need to disable rollback for speed:
% cfg.rollback.enableRoundRollback = false;

% 统一入口执行（内部会自动分发算法、初始化硬件或走 mock 回调）。
result = exp_run_calibration(cfg);

% 标准输出：便于在命令行快速确认执行情况。
fprintf("Method: %s\n", result.method);
fprintf("Eval count: %d\n", result.evalCount);
if isfield(result, "finalIntensityMeasured")
    fprintf("Final measured intensity: %.6g\n", result.finalIntensityMeasured);
end

end
