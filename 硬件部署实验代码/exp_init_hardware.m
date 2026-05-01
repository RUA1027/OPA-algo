function hw = exp_init_hardware(cfg)
%EXP_INIT_HARDWARE Initialize experiment hardware resources.

% 标准化硬件管理，提升代码复用性和资源安全性
% 核心价值：统一硬件初始化流程、自动资源清理、支持多种设备，简化实验代码编写和维护
% 兼容外部硬件对象 + 自动创建硬件两种模式

arguments
    cfg (1,1) struct
end

hw = struct();
% sensorMode 会在后续读取阶段统一分发：CCD / DSO / CAPTURE_CARD。
hw.sensorMode = upper(string(cfg.hardware.sensorMode));
hw.serialObj = [];
hw.videoObj = [];
hw.dsoObj = [];
hw.capture = struct();

% ownsXxx 标志用于 exp_close_hardware 判定“是否由本函数创建”。
% 若对象由外部注入，则不应在 close 阶段强制释放，避免误删外部资源。
hw.ownsSerial = false;
hw.ownsVideo = false;
hw.ownsDso = false;
hw.ownsCaptureLib = false;
hw.captureDeviceOpened = false;

% Serial source meter / voltage source
% 设计思路：优先复用外部串口对象；无外部对象时才内部创建。
if isfield(cfg.hardware, "useExternalSerial") && cfg.hardware.useExternalSerial
    hw.serialObj = cfg.hardware.externalSerialObj;
else
    hw.serialObj = serialport(cfg.hardware.serialPort, cfg.hardware.serialBaud);
    configureTerminator(hw.serialObj, "CR/LF", "CR/LF");
    hw.ownsSerial = true;
end

switch hw.sensorMode
    case "CCD"
        % CCD 模式：可复用外部 video 对象，或按历史实验参数自动初始化。
        if isfield(cfg.hardware, "useExternalVideo") && cfg.hardware.useExternalVideo
            hw.videoObj = cfg.hardware.externalVideoObj;
        else
            % Keep the same adaptor and format as the original experiment script.
            adaptorInfo = imaqhwinfo("hamamatsu");
            imaqregister(adaptorInfo.AdaptorDllName);
            imaqreset;
            hw.videoObj = videoinput("hamamatsu", 1, "MONO16_320x256");
            hw.videoObj.FramesPerTrigger = 1;

            triggerconfig(hw.videoObj, "manual");
            src.TriggerSource = "internal";
            start(hw.videoObj);
            src = getselectedsource(hw.videoObj);
            src.ExposureTime = 0.10000e-03;
            hw.ownsVideo = true;
        end

    case "DSO"
        % DSO 模式：保持 legacy 仪器连接方式，兼容历史资源名。
        % 注意：该分支依赖 instrfind/visa 旧接口，后续可视需要迁移到 visadev。
        resource = cfg.hardware.dso.resource;
        legacyInstrFind = str2func("instrfind");
        legacyVisa = str2func("visa");

        obj1 = legacyInstrFind("Type", "visa-usb", "RsrcName", resource, "Tag", "");
        if isempty(obj1)
            obj1 = legacyVisa(cfg.hardware.dso.vendor, resource);
        else
            fclose(obj1);
            obj1 = obj1(1);
        end

        set(obj1, "OutputBufferSize", 1e4);
        set(obj1, "InputBufferSize", 1e4);

        fopen(obj1);
        fprintf(obj1, ":WAVEFORM:SOURCE %s", cfg.hardware.dso.channel);
        fprintf(obj1, ":WAVeform:POINts %d", cfg.hardware.dso.points);
        fprintf(obj1, ":WAVEFORM:FORMAT WORD");
        fprintf(obj1, ":WAVEFORM:BYTEORDER LSBFirst");

        hw.dsoObj = obj1;
        hw.ownsDso = true;

    case "CAPTURE_CARD"
        % 采集卡模式：加载 USB3000 动态库并完成通道/量程/触发初始化。
        % capture 配置由 cfg.hardware.capture 提供。
        capture = cfg.hardware.capture;
        if ~libisloaded("USB3000")
            loadlibrary(fullfile(capture.dllDir, "USB3000"), fullfile(capture.headerDir, "USB3000.h"));
            hw.ownsCaptureLib = true;
        end

        % 打开设备后记录标志，供 close 阶段对称调用 USB3CloseDevice。
        calllib("USB3000", "USB3OpenDevice", 0);
        hw.captureDeviceOpened = true;
        calllib("USB3000", "SetUSB3AiSampleRate", 0, capture.sampleRateNs);
        calllib("USB3000", "SetUSB3AiSampleMode", 0, 0);
        calllib("USB3000", "SetUSB3AiConnectType", 0, 0);

        for i = 1:24
            calllib("USB3000", "SetUSB3AiChanSel", 0, i - 1, 0);
            calllib("USB3000", "SetUSB3AiRange", 0, i - 1, 5.12);
        end

        for i = 1:capture.openChannels
            calllib("USB3000", "SetUSB3AiChanSel", 0, i - 1, 1);
            calllib("USB3000", "SetUSB3AiRange", 0, i - 1, capture.sampleRange);
        end

        calllib("USB3000", "SetUSB3AiTrigSource", 0, 0);
        calllib("USB3000", "SetUSB3AiConvSource", 0, 0);
        calllib("USB3000", "SetUSB3AiPreTrigPoints", 0, 0);
        calllib("USB3000", "SetUSB3ClrAiFifo", 0);
        calllib("USB3000", "SetUSB3AiSoftTrig", 0);

        hw.capture = capture;

    otherwise
        % 统一异常出口，便于调用者快速定位配置错误。
        error("opa_exp:exp_init_hardware:InvalidSensorMode", "Unsupported sensor mode: %s", hw.sensorMode);
end

end
