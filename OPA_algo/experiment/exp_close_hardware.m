function exp_close_hardware(hw)
%EXP_CLOSE_HARDWARE Close and release experiment hardware resources.

% 实验结束后统一释放所有硬件资源
% 关闭并释放实验相关的所有硬件设备资源，防止硬件连接泄漏、内存占用或设备占用异常。

arguments
    hw (1,1) struct
end

% ---------------------- CCD 资源释放 ----------------------
% 仅释放“由框架创建”的 video 对象，避免误删外部注入对象。
if isfield(hw, "ownsVideo") && hw.ownsVideo && isfield(hw, "videoObj") && ~isempty(hw.videoObj)
    try
        stop(hw.videoObj);
    catch
    end
    try
        delete(hw.videoObj);
    catch
    end
end

% ---------------------- DSO 资源释放 ----------------------
% 先 fclose 再 delete，确保通信通道关闭后再销毁对象。
if isfield(hw, "ownsDso") && hw.ownsDso && isfield(hw, "dsoObj") && ~isempty(hw.dsoObj)
    try
        fclose(hw.dsoObj);
    catch
    end
    try
        delete(hw.dsoObj);
    catch
    end
end

% ---------------------- 采集卡设备关闭 ----------------------
% 与 init 阶段 USB3OpenDevice 对称，防止设备句柄残留。
if isfield(hw, "captureDeviceOpened") && hw.captureDeviceOpened
    try
        if libisloaded("USB3000")
            calllib("USB3000", "SetUSB3ClrAiTrigger", 0);
            calllib("USB3000", "SetUSB3ClrAiFifo", 0);
            calllib("USB3000", "USB3CloseDevice", 0);
        end
    catch
    end
end

% ---------------------- 采集卡库卸载 ----------------------
% 仅当库由本次流程加载时卸载，避免影响其他会话。
if isfield(hw, "ownsCaptureLib") && hw.ownsCaptureLib
    try
        if libisloaded("USB3000")
            unloadlibrary("USB3000");
        end
    catch
    end
end

% ---------------------- 串口资源释放 ----------------------
% 串口删除放在最后，保证上游设备对象先释放完成。
if isfield(hw, "ownsSerial") && hw.ownsSerial && isfield(hw, "serialObj") && ~isempty(hw.serialObj)
    try
        delete(hw.serialObj);
    catch
    end
end

end


%{
if DSO == 1
    % 示波器
    fclose(obj1);
    % Clean up all objects.
    delete(obj1);
    clear SerialObj;
    clear obj1;
elseif capture_card ==1
    % 采集卡
    calllib('USB3000','SetUSB3ClrAiTrigger',0)
    calllib('USB3000','SetUSB3ClrAiFifo',0)
    calllib('USB3000','USB3CloseDevice',0)
    unloadlibrary('USB3000');
else
    %红外ccd
    delete(v)
    clear src v
end
%}