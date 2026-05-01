%%%%%%%%%%%%%%%%%%%%% OPA相位校准(黄金分割法搜索+单点) %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%% APD对准角度+示波器读取APD输出电流 %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%% 初始化参数 %%%%%%%%%%%%%%%%%%%%

% 重要说明（遗留脚本）：
% 1) 本脚本是历史一体化流程，包含硬件初始化、优化循环、收尾释放。
% 2) 其依赖旧版接口（instrfind/visa 等）与本地硬编码路径，不建议日常直接运行。
% 3) 统一框架已提供 exp_quickstart / exp_run_calibration，优先使用新入口。
% 4) 出于安全考虑，本脚本默认阻断执行，必须显式放行才可运行。

warning('opa_exp:legacy:DeprecatedScript', ...
    ['phase_calibration_golden_search_for_256ch_for_CCD is legacy and not recommended for routine runs. ' ...
     'Prefer exp_quickstart / exp_run_calibration.']);

% 放行机制：
% 仅当环境变量 OPA_ALLOW_LEGACY_SCRIPT=1 时才允许继续，
% 用于防止误触旧链路导致硬件误操作。
allowLegacyScript = strcmpi(strtrim(getenv("OPA_ALLOW_LEGACY_SCRIPT")), "1");
if ~allowLegacyScript
    error('opa_exp:legacy:Blocked', ...
        ['Legacy script is blocked by default to prevent accidental hardware operations. ' ...
         'Set environment variable OPA_ALLOW_LEGACY_SCRIPT=1 only when you intentionally need this path.']);
end

%% !!!!!!!!!! 每次运行前仔细检查func_V_transition函数，采集卡采样率和点数 !!!!!!!!!!!!!

clc;
clear;
% 不要清变量，中途退出程序的话需要重新判断电压源串口是否打开
% if (exist('SerialObj','var')==1)
%     delete(SerialObj);   %删除电压源串口，instrfindall找不到
% end
delete(instrfindall);        %关闭所有打开的串口
clear SerialObj;
clear V_measure_final;
clear V_before start; 


%% 
DSO = 0  % 示波器1，
CCD = 1  % 相机
capture_card = 0 %采集卡
sample_times = 1;


if length(find([DSO,CCD,capture_card]==1))>1
    returnerror;
end

if DSO == 1
    % 分支1：示波器读数模式
    %% 示波器通信
    obj1 = instrfind('Type', 'visa-usb', 'RsrcName', 'USB0::0x0957::0x173B::MY54410002::0::INSTR', 'Tag', '');

    % Create the VISA-USB object if it does not exist
    % otherwise use the object that was found.
    if isempty(obj1) 
        obj1 = visa('NI', 'USB0::0x0957::0x173B::MY54410002::0::INSTR');
    else
        fclose(obj1);
        obj1 = obj1(1);
    end
    set(obj1, 'OutputBufferSize', 1e4);
    set(obj1,'InputBufferSize',1e4);
    % Connect to instrument object, obj1.
    fopen(obj1);
    fprintf(obj1,':WAVEFORM:SOURCE CHAN1');% 设置读取数据的通道
    % fprintf(obj1,':ACQuire:TYPE HRES');% 设置高分辨率模式（根据需要实现在示波器上手动设置模式）
    %         fprintf(obj1,':SINGle'); % 让示波器采集一次数据，再停止采集
    %         pause(0.01);
    %         fprintf(obj1,':WAVeform:POINts:MODE MAX'); % 设置波形读取模式为RAW
    fprintf(obj1,':WAVeform:POINts 250');% 读取内存波形点数      可选100、250、500、1000
    %         fprintf(obj1,':WAVEFORM:FORMAT ASC');% 设置数据返回格式：ASCII，返回char型，只能读10万以下的点，直接输出电压
    fprintf(obj1,':WAVEFORM:FORMAT WORD');    % 设置数据返回格式：WORD，读取速度快，超过10万的点用这个
    fprintf(obj1,':WAVEFORM:BYTEORDER LSBFirst');

elseif capture_card==1
    % 分支2：采集卡读数模式
    %% 配置数据采集卡，检查采样率和采集点数
    PATH1 = 'E:\script（请勿修改）\base_function\数据采集卡\USB-3000_Matlab\x64';
    PATH2 = 'E:\script（请勿修改）\base_function\数据采集卡\USB-3000_Matlab';
    loadlibrary([PATH1,'\USB3000'],[PATH2,'\USB3000.h']);
    libfunctions USB3000 -full
    
    open_number = 1;   % 采集的通道数
    sample_num = 1000;  % 每次采集点数
    sample_times = 1;  % 采集次数
    sapmle_range = 1.28; % 采样量程

    calllib('USB3000','USB3OpenDevice',0)             % 打开采集卡，参数不用改。  

    calllib('USB3000','SetUSB3AiSampleRate',0,1000)   % 采样周期设置，单位ns，采样周期必须是以 10ns 为步进设置。
    calllib('USB3000','SetUSB3AiSampleMode',0,0)  % 采集模式设置，设置 0 代表连续采集；设置 1 代表有限次数采集，即 OneShot 模式
    calllib('USB3000','SetUSB3AiConnectType',0,0) % 模拟输入接线方式设置，设置 0 代表 DIFF 输入接线；设置 1 代表 NRSE 输入接线。

    for i = 1 : 24
        calllib('USB3000','SetUSB3AiChanSel',0, i-1, 0)   % 模拟通道启用，1 启用，0 禁用。
        calllib('USB3000','SetUSB3AiRange',0, i-1, 5.12) % 量程设置，第二个参数为通道数，设置 10.24 代表模拟输入量程为±10.24V；5.12；2.56；1.28；0.64。
    end

    for i = 1:open_number
        calllib('USB3000','SetUSB3AiChanSel',0, i-1, 1)   % 模拟通道启用，1 启用，0 禁用。
        calllib('USB3000','SetUSB3AiRange',0, i-1, sapmle_range) % 量程设置，第二个参数为通道数，设置 10.24 代表模拟输入量程为±10.24V；5.12；2.56；1.28；0.64。
    end

    calllib('USB3000','SetUSB3AiTrigSource',0,0)  % 设置指定设备的模拟输入触发源。
    calllib('USB3000','SetUSB3AiConvSource',0,0)  % 设置指定设备的模拟输入采样时钟源。
    calllib('USB3000','SetUSB3AiPreTrigPoints',0,0)  % 设置指定设备的模拟输入预触发点数。
    calllib('USB3000','SetUSB3ClrAiFifo',0)    % 清空指定设备的模拟输入 Fifo 缓存。
    calllib('USB3000','SetUSB3AiSoftTrig',0)   % 设置指定设备的模拟输入软件触发。

else
    % 分支3：CCD图像读数模式
    %% Registration of Hamamatsu adaptor
    % If you get 'Adaptor Not Valid' Error try the following command and restart:

    s = struct('info1','info2','info3','info4');

    imaqhwinfo hamamatsu;
    s.info1 = ans.AdaptorDllName;

    imaqregister(s.info1);
    %% 连接CCD
    imaqreset % resets the image acquisition environment
    v = videoinput("hamamatsu", 1, "MONO16_320x256");
    % imaqreset % resets the image acquisition environment
    v.FramesPerTrigger = 1;
    spot_size = 4;
    % 配置CCD
    src = getselectedsource(v);
    src.ExposureTime = 0.10000e-03;
    % triggerconfig(v, 'immediate'); % waits for trigger(v) command to collect frame
    triggerconfig(v, 'manual');
    src.TriggerSource = 'internal';
    start(v);
end

%% 配置256路电压源的通信
% SerialObj = func_256_serial_open;%7.5V电压源

s = serialport('COM44', 128000);%zjy电压源
configureTerminator(s, 'CR/LF', 'CR/LF');

%% 校准开始
% format long;

tic   %计算程序运行时间

M = 128;

%%初始化
L = (sqrt(5)-1)/2;
P_2pi = 0.036;           % 2pi相移对应功率
R = 1040;               % 移相器电阻(欧姆)
delay = 0.03;
max_voltage = 7.5;   % 允许的最大电压
min_voltage = 0;     % 允许的最小电压

h = figure(1);
% r = figure();
%校准矩阵
% period = 8;
% T = zeros(M/period, M);
% for i = 1:M/period
%     T(i,(i-1)*period+1:i*period)= 1;
% end
% 
% H0 = zeros(M,M);
% for i = 1: M
%     H0(i,i) = 1;
% end

run_times =4;
v_start2 = 0*rand(1,run_times);
v_stop2 = v_start2+7.5^2;%P_2pi*R;

times1 = [5,8,10,12,12,13,10,10,10,10,15,15,10];     %每一路要跑的次数
voltage_precision = round(P_2pi*R*(L.^times1),5);  %收敛精度(电压平方对应的精度)


% voltage_calibration = zeros(1,M);           % 每一路最终要加的校准电压
if (exist('voltage_calibration','var')==0)
    % voltage_calibration = [4.58565598663982	6.34774121306960	4.58565598663982	1.54748233539948	2.73253744974911	5.93479226023914	1.63626335213330	6.09582754394799	1.96842793790406	2.41082202165191	3.06661298302247	5.22471539444018	4.58565598663982	2.78377748633802	5.93479226023914	4.58565598663982	6.98449991665249	6.52026295180064	0.860234551836822	2.73253744974911	1.54748233539948	3.74417243440217	2.78377748633802	6.49855159104419	5.03590078134385	5.93479226023914	4.58565598663982	0.860234551836822	5.19759509520886	2.08135913569332	6.11896801958599	4.58565598663982	2.41082202165191	5.19759509520886	4.55473211601347	5.40694046816320	5.08110657087139	5.93479226023914	7.10196713452816	1.54748233539948	4.58565598663982	5.83304452091767	2.35146903890329	3.70623407779055	4.58565598663982	4.55473211601347	1.54748233539948	4.36931190857840	4.36931190857840	2.78377748633802	6.96423598871819	1.54748233539948	6.21603735621841	2.35146903890329	6.36996661586726	7.33861692838825	5.93479226023914	7.31933345616016	2.99111482270894	2.08135913569332	6.52026295180064	5.93479226023914	7.23707754920996];% 每一路最终要加的校准电压
    voltage_calibration = 7.5*rand(1,M);           % 每一路最终要加的校准电压
end

% 上一轮电压，用于判别模块
if (exist('V_before','var')==0)
    V_before = rand(1,256);
end

V_output = func_V_transition(voltage_calibration);
% func_Voltage_output_256ch(SerialObj,V_output,V_before);         % 未校准时电压全部设为随机,否则在跑完的基础上继续优化
ZJY_256VSRC_WRITE(s, V_output);
V_before = V_output; 
pause(1);

% 示波器/采集卡读取
if DSO == 1  % 示波器
    V_measure_final(1) = func_DSO_read(obj1);              % 读取未校准时示波器输出的PD电信号
elseif capture_card == 1   % 采集卡
    Data = zeros(1,1000);
    DataPtr = libpointer('singlePtr',Data);
    myData = zeros(1,sample_times*sample_num);
    for i = 1:sample_times
        calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
        calllib('USB3000','USB3GetAi',0,sample_num,DataPtr,1000)  % 读取指定设备采集得到的模拟输入数据。
        % 'USB3GetAi' (int DevIndex, unsigned long Points, float *Ai, long TimeOut)
        Data = get(DataPtr,'Value');
        myData((i-1)*sample_num+1:i*sample_num) = Data(1:sample_num);
        calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
    end
%     pause(0.01);
    V_measure_final(1) = mean(myData);
    if V_measure_final(1) > 0.9*sapmle_range
        sapmle_range = sapmle_range*2;
        for i = 1:open_number
            calllib('USB3000','SetUSB3AiChanSel',0, i-1, 1)   % 模拟通道启用，1 启用，0 禁用。
            calllib('USB3000','SetUSB3AiRange',0, i-1, sapmle_range) % 量程设置，第二个参数为通道数，设置 10.24 代表模拟输入量程为±10.24V；5.12；2.56；1.28；0.64。
        end
    end
else   % CCD
    V_measure_final(1) = 0;
    for i = 1:sample_times
        pause(delay);
        image1 = double(getsnapshot(v));
        % intensity = mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2)));
        % intensity = max( mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2))), image1(128,160));
        intensity = sum(sum((image1(:, 160-spot_size/2:160+spot_size/2))));
        V_measure_final(1) = intensity +  V_measure_final(1);
    end
    V_measure_final(1) = V_measure_final(1)/sample_times;
end
V_measure(1) = V_measure_final(1);                 % 读取未校准时示波器输出的PD电信号

%% 输入电压和初始比较
voltage = zeros(1,M);     % 多路电压源输出的电压
tt = 1;   % 记录总迭代次数
ttt = 1;  % 记录优化每一路的最后一次
best_intensity = 0;

for NN = 1:run_times  %校准次数
    % 每一轮的校准矩阵随机生成，从随机路优化，行数代表第几轮，列数代表该轮哪一路被校准
    Lrand = randperm(M);
    H = zeros(M,M);
    for i = 1: M
        H(i,Lrand(i)) = 1;
    end
    times = zeros(1,size(H,1));   %记录H矩阵每一行调相的次数
    for xx = 1:size(H,1)   %从H矩阵第一行开始调相
        disp(['第',num2str(NN),'轮第',num2str(xx),'路校准']);
        start = v_start2(NN);    %初始下区间
        stop = v_stop2(NN);  %初始上区间，改变2pi相位对应的电压平方
        D = round(abs(stop-start),5);

        voltage = voltage_calibration;
        list = find(H(xx,:)==1);

        while (1)
            voltage2_1 = stop - L*(stop - start);     %电压平方
            voltage2_2 = start + L*(stop - start);    %电压平方    
            
            if D > voltage_precision(NN)   % stop-start小于收敛精度时退出循环
                if times(xx) == 0
                    times(xx) =  times(xx)+1;
                    %% 256通道电压源电压输入
                    voltage(list) = sqrt(voltage2_1)*ones(1,length(list));

                    % 输出电压超过限定值，报错
                    if max(voltage) > max_voltage || min(voltage) < min_voltage
                        disp('电压超过阈值！');
                        returnerror;
                    end

                    V_output = func_V_transition(voltage);
                    % func_Voltage_output_256ch(SerialObj,V_output,V_before);         % 未校准时电压全部设为随机,否则在跑完的基础上继续优化
                    ZJY_256VSRC_WRITE(s, V_output);
                    V_before = V_output;

                    pause(delay);

                    %% 示波器/采集卡读取
                    if DSO == 1
                        V_measure_1 = func_DSO_read(obj1);   % 读取示波器输出的PD电信号
                    elseif capture_card ==1
                        for i = 1:sample_times
                            calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                            calllib('USB3000','USB3GetAi',0,sample_num,DataPtr,1000)  % 读取指定设备采集得到的模拟输入数据。
                            % 'USB3GetAi' (int DevIndex, unsigned long Points, float *Ai, long TimeOut)
                            Data = get(DataPtr,'Value');
                            myData((i-1)*sample_num+1:i*sample_num) = Data(1:sample_num);
                            calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                        end
                        %     pause(0.01);
                        V_measure_1 = mean(myData);
                        if V_measure_1 > 0.9*sapmle_range
                            sapmle_range = sapmle_range*2;
                            for i = 1:open_number
                                calllib('USB3000','SetUSB3AiChanSel',0, i-1, 1)   % 模拟通道启用，1 启用，0 禁用。
                                calllib('USB3000','SetUSB3AiRange',0, i-1, sapmle_range) % 量程设置，第二个参数为通道数，设置 10.24 代表模拟输入量程为±10.24V；5.12；2.56；1.28；0.64。
                            end
                        end
                    else   % CCD
                        %  读取图像中心 11×11像素
                        V_measure_1 = 0;
                        for i = 1:sample_times
                            pause(delay);
                            image1 = double(getsnapshot(v));
                            % intensity = mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2)));
                            % intensity = max( mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2))), image1(128,160));
                            intensity = sum(sum((image1(:, 160-spot_size/2:160+spot_size/2))));
                            V_measure_1 = intensity +  V_measure_1;
                        end
                        V_measure_1 = V_measure_1/sample_times;
                    end

                    %% 256通道电压源电压输入
                    voltage(list) = sqrt(voltage2_2)*ones(1,length(list));

                    % 输出电压超过限定值，报错
                    if max(voltage) > max_voltage || min(voltage) < min_voltage
                        returnerror;  %电压超过限定值
                    end

                    V_output = func_V_transition(voltage);
                    % func_Voltage_output_256ch(SerialObj,V_output,V_before);         % 未校准时电压全部设为随机,否则在跑完的基础上继续优化
                    ZJY_256VSRC_WRITE(s, V_output);
                    V_before = V_output;
                    pause(delay);

                    %% 示波器/采集卡读取
                    if DSO == 1
                        V_measure_2 = func_DSO_read(obj1);   % 读取示波器输出的PD电信号
                    elseif capture_card ==1
                        for i = 1:sample_times
                            calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                            calllib('USB3000','USB3GetAi',0,sample_num,DataPtr,1000)  % 读取指定设备采集得到的模拟输入数据。
                            % 'USB3GetAi' (int DevIndex, unsigned long Points, float *Ai, long TimeOut)
                            Data = get(DataPtr,'Value');
                            myData((i-1)*sample_num+1:i*sample_num) = Data(1:sample_num);
                            calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                        end
                        %     pause(0.01);
                        V_measure_2 = mean(myData);
                        if V_measure_2 > 0.9*sapmle_range
                            sapmle_range = sapmle_range*2;
                            for i = 1:open_number
                                calllib('USB3000','SetUSB3AiChanSel',0, i-1, 1)   % 模拟通道启用，1 启用，0 禁用。
                                calllib('USB3000','SetUSB3AiRange',0, i-1, sapmle_range) % 量程设置，第二个参数为通道数，设置 10.24 代表模拟输入量程为±10.24V；5.12；2.56；1.28；0.64。
                            end
                        end
                    else   % CCD
                        V_measure_2 = 0;
                        for i = 1:sample_times
                            pause(delay);
                            image2 = double(getsnapshot(v));
                            % intensity = mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2)));
                            % intensity = max( mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2))), image1(128,160));
                            intensity = sum(sum((image2(:, 160-spot_size/2:160+spot_size/2))));
                            V_measure_2 = intensity +  V_measure_2;
                        end
                        V_measure_2 = V_measure_2/sample_times;
                    end

                    %% 比较两个不同电压的输出电信号大小
                    if V_measure_1 > V_measure_2
                        V_measure(tt+1) = V_measure_1;
                        stop = voltage2_2;
                        match = 1;
                    else
                        V_measure(tt+1) = V_measure_2;
                        start = voltage2_1;
                        match = 0;
                    end
                    tt = tt +1;
                    D = round(abs(stop-start),5);
                else
                    times(xx) =  times(xx)+1;
                    if match == 1
                        V_measure_2 = V_measure_1;
                        %% 256通道电压源电压输入
                        voltage(list) = sqrt(voltage2_1)*ones(1,length(list));

                        % 输出电压超过限定值，报错
                        if max(voltage) > max_voltage || min(voltage) < min_voltage
                            returnerror;  %电压超过限定值
                        end

                        V_output = func_V_transition(voltage);
                        % func_Voltage_output_256ch(SerialObj,V_output,V_before);         % 未校准时电压全部设为随机,否则在跑完的基础上继续优化
                        ZJY_256VSRC_WRITE(s, V_output);
                        V_before = V_output;
                        pause(delay);

                        %% 示波器/采集卡读取
                        if DSO == 1
                            V_measure_1 = func_DSO_read(obj1);   % 读取示波器输出的PD电信号
                        elseif capture_card ==1
                            for i = 1:sample_times
                                calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                                calllib('USB3000','USB3GetAi',0,sample_num,DataPtr,1000)  % 读取指定设备采集得到的模拟输入数据。
                                % 'USB3GetAi' (int DevIndex, unsigned long Points, float *Ai, long TimeOut)
                                Data = get(DataPtr,'Value');
                                myData((i-1)*sample_num+1:i*sample_num) = Data(1:sample_num);
                                calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                            end
                            %     pause(0.01);
                            V_measure_1 = mean(myData);
                            if V_measure_1 > 0.9*sapmle_range
                                sapmle_range = sapmle_range*2;
                                for i = 1:open_number
                                    calllib('USB3000','SetUSB3AiChanSel',0, i-1, 1)   % 模拟通道启用，1 启用，0 禁用。
                                    calllib('USB3000','SetUSB3AiRange',0, i-1, sapmle_range) % 量程设置，第二个参数为通道数，设置 10.24 代表模拟输入量程为±10.24V；5.12；2.56；1.28；0.64。
                                end
                            end
                        else   % CCD
                            V_measure_1 = 0;
                            for i = 1:sample_times
                                pause(delay);
                                image1 = double(getsnapshot(v));
                                % intensity = mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2)));
                                % intensity = max( mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2))), image1(128,160));
                                intensity = sum(sum((image1(:, 160-spot_size/2:160+spot_size/2))));
                                V_measure_1 = intensity +  V_measure_1;
                            end
                            V_measure_1 = V_measure_1/sample_times;
                        end

                        %% 比较两个不同电压的输出电信号大小
                        if V_measure_1 > V_measure_2
                            V_measure(tt+1) = V_measure_1;
                            stop = voltage2_2;
                            match = 1;
                        else
                            V_measure(tt+1) = V_measure_2;
                            start = voltage2_1;
                            match = 0;
                        end
                        tt = tt+1;
                        D = round(abs(stop-start),5);
                    else
                        V_measure_1 = V_measure_2;
                        %% 256通道电压源电压输入
                        voltage(list) = sqrt(voltage2_2)*ones(1,length(list));

                        % 输出电压超过限定值，报错
                        if max(voltage) > max_voltage || min(voltage) < min_voltage
                            returnerror;  %电压超过限定值
                        end

                        V_output = func_V_transition(voltage);
                        % func_Voltage_output_256ch(SerialObj,V_output,V_before);         % 未校准时电压全部设为随机,否则在跑完的基础上继续优化
                        ZJY_256VSRC_WRITE(s, V_output);
                        V_before = V_output;
                        pause(delay);

                        %% 示波器/采集卡读取
                        if DSO == 1
                            V_measure_2 = func_DSO_read(obj1);   % 读取示波器输出的PD电信号
                        elseif capture_card ==1
                            for i = 1:sample_times
                                calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                                calllib('USB3000','USB3GetAi',0,sample_num,DataPtr,1000)  % 读取指定设备采集得到的模拟输入数据。
                                % 'USB3GetAi' (int DevIndex, unsigned long Points, float *Ai, long TimeOut)
                                Data = get(DataPtr,'Value');
                                myData((i-1)*sample_num+1:i*sample_num) = Data(1:sample_num);
                                calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                            end
                            %     pause(0.01);
                            V_measure_2 = mean(myData);
                            if V_measure_2 > 0.9*sapmle_range
                                sapmle_range = sapmle_range*2;
                                for i = 1:open_number
                                    calllib('USB3000','SetUSB3AiChanSel',0, i-1, 1)   % 模拟通道启用，1 启用，0 禁用。
                                    calllib('USB3000','SetUSB3AiRange',0, i-1, sapmle_range) % 量程设置，第二个参数为通道数，设置 10.24 代表模拟输入量程为±10.24V；5.12；2.56；1.28；0.64。
                                end
                            end
                        else   % CCD
                            V_measure_2 = 0;
                            for i = 1:sample_times
                                pause(delay);
                                image2 = getsnapshot(v);
                                % intensity = mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2)));
                                % intensity = max( mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2))), image1(128,160));
                                intensity = sum(sum((image2(:, 160-spot_size/2:160+spot_size/2))));
                                V_measure_2 = intensity +  V_measure_2;
                            end
                            V_measure_2 = V_measure_2/sample_times;
                        end

                        %% 比较两个不同电压的输出电信号大小
                        if V_measure_1 > V_measure_2
                            V_measure(tt+1) = V_measure_1;
                            stop = voltage2_2;
                            match = 1;
                        else
                            V_measure(tt+1) = V_measure_2;
                            start = voltage2_1;
                            match = 0;
                        end
                        tt = tt+1;
                        D = round(abs(stop-start),5);     
                    end
                end
            else       % stop-start小于收敛精度时退出循环 
                ttt = ttt +1;
                V_output = func_V_transition(voltage_calibration);
                % func_Voltage_output_256ch(SerialObj,V_output,V_before);         % 未校准时电压全部设为随机,否则在跑完的基础上继续优化
                ZJY_256VSRC_WRITE(s, V_output);
                V_before = V_output;               
                pause(delay);

                %% 示波器/采集卡读取
                if DSO == 1
                    V_b = func_DSO_read(obj1);          % 读取PD电信号
                elseif capture_card ==1
                    for i = 1:sample_times
                        calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                        calllib('USB3000','USB3GetAi',0,sample_num,DataPtr,1000)  % 读取指定设备采集得到的模拟输入数据。
                        % 'USB3GetAi' (int DevIndex, unsigned long Points, float *Ai, long TimeOut)
                        Data = get(DataPtr,'Value');
                        myData((i-1)*sample_num+1:i*sample_num) = Data(1:sample_num);
                        calllib('USB3000','SetUSB3ClrAiFifo',0)       % 清空模拟输入 Fifo 缓存
                    end
                    %     pause(0.01);
                    V_b = mean(myData);
                    if V_b > 0.9*sapmle_range
                        sapmle_range = sapmle_range*2;
                        for i = 1:open_number
                            calllib('USB3000','SetUSB3AiChanSel',0, i-1, 1)   % 模拟通道启用，1 启用，0 禁用。
                            calllib('USB3000','SetUSB3AiRange',0, i-1, sapmle_range) % 量程设置，第二个参数为通道数，设置 10.24 代表模拟输入量程为±10.24V；5.12；2.56；1.28；0.64。
                        end
                    end
                else   % CCD
                        V_b = 0;
                        for i = 1:sample_times
                            pause(delay);
                            image3 = double(getsnapshot(v));
                            % intensity = mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2)));
                            % intensity = max( mean(mean(image1(128-spot_size/2:128+spot_size/2, 160-spot_size/2:160+spot_size/2))), image1(128,160));
                            intensity = sum(sum((image3(:, 160-spot_size/2:160+spot_size/2))));
                            V_b = intensity +  V_b;
                        end
                        V_b = V_b/sample_times;
                end

                if max(V_measure_1,V_measure_2) <= (V_b+V_measure_final(ttt-1))/2
                    %                 if max(V_measure_1,V_measure_2) <= max(V_b,V_measure_final(ttt-1))
                    V_measure_final(ttt) = (V_b+V_measure_final(ttt-1))/2;
                    %                        V_measure_final(ttt) = max(V_b,V_measure_final(ttt-1));
                    %                     V_measure_final(ttt) = max(V_measure_1,V_measure_2);
                    image = image3;
                else
                    if V_measure_1 > V_measure_2
                        voltage_calibration(list) = sqrt(voltage2_1)*ones(1,length(list));
                        V_measure_final(ttt) = V_measure_1;
                        image = image1;
                    else
                        voltage_calibration(list) = sqrt(voltage2_2)*ones(1,length(list));
                        V_measure_final(ttt) = V_measure_2;
                        image = image2;
                    end 
                end

                if CCD == 1
                    if max(max(image)) >= 16000
                        % 红外CCD过曝，报警
                        disp('红外CCD过曝！请尽快处理！');
                        sound(sin(2*pi*25*(1:6000)/200));
                    end
                end

                % 输出
                if CCD == 1
                    if max(max(image)) > best_intensity
                        best_intensity = max(max(image));
                        best_image = image;
                        voltage_calibration_best = voltage_calibration;

                        % 计算FWHM
                        [phase_FWHM, wl_FWHM] = func_extract_FWHM(best_image);
                        % 计算光斑波长方向位置
                        wl_position = func_locate_wl_position(best_image);
                        
                        subplot(1,3,3);
                        imagesc(best_image);
                        drawnow;
                        colorbar;
                        colormap('gray');
                        title(['Best Image', newline, ...
                               'FWHM = ', num2str(phase_FWHM), '°×', num2str(wl_FWHM), '°', newline, ...
                               'Beam Position: ', num2str(wl_position), '°']);
                    end

                    figure(h);
                    subplot(1,3,1);
                    plot(V_measure_final);
    
                    subplot(1,3,2);
                    imagesc(image);
                    drawnow;
                    colorbar;
                    colormap('gray');
                    title('Current Image');
                else
                    if V_measure_final(end) > best_intensity
                        best_intensity = V_measure_final;
                        voltage_calibration_best = voltage_calibration;
                    end
                    
                    figure(h);
                    subplot(1,1,1);
                    plot(V_measure_final);
                end
                break;
            end
        end
    end
%     pause(3);
end

toc
disp( ['运行时间: ',num2str(toc) ] );

delta_V_measure = diff(V_measure);
delta_V_measure_final = diff(V_measure_final);

% 输入校准电压
V_output = func_V_transition(voltage_calibration);
% func_Voltage_output_256ch(SerialObj,V_output,V_before);
ZJY_256VSRC_WRITE(s, V_output);        
V_before = V_output;

% plot
figure;
plot(V_measure_final);
xlabel('校准次数（从2开始）'); ylabel('V_measure');
title('FOM变化值');

figure;
plot(voltage_calibration);
xlabel('M'); ylabel('voltage_calibration');
title('校准电压');

disp('程序运行结束');
sound(sin(2*pi*25*(1:6000)/100));
pause(1);
sound(sin(2*pi*25*(1:6000)/100));
pause(1);
sound(sin(2*pi*25*(1:6000)/100));
pause(1);


%% 关闭串口
% 电压源
% func_256_serial_close(SerialObj);
clear s;    % 电压源

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