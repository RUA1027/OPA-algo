function [cal_result, result] = func_phasecali(s, v, cfg)
%FUNC_PHASECALI Backward-compatible wrapper for unified experiment framework.
%
% Usage:
%   cal_result = func_phasecali()
%   cal_result = func_phasecali(s, v)
%   [cal_result, result] = func_phasecali(s, v, cfg)
%
% Inputs:
%   s   optional external serialport object for voltage source
%   v   optional external video object for CCD mode
%   cfg optional struct from exp_default_config()
%       cfg.method supports: "mREV-GSS" | "5PPS" | "PFPD" | "CAIO"
%
% Output:
%   cal_result voltage-domain calibration vector (V) for 128 active channels
%   result     full algorithm result struct from exp_run_calibration

if nargin < 1
    s = [];
end
if nargin < 2
    v = [];
end
if nargin < 3 || isempty(cfg)
    cfg = exp_default_config();
end

if ~isempty(s)
    cfg.hardware.useExternalSerial = true;
    cfg.hardware.externalSerialObj = s;
end

if ~isempty(v)
    cfg.hardware.sensorMode = "CCD";
    cfg.hardware.useExternalVideo = true;
    cfg.hardware.externalVideoObj = v;
end

result = exp_run_calibration(cfg);
cal_result = sqrt(max(result.controlU, 0));

end
