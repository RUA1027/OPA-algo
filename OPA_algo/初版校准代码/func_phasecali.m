%%%%%%%%%%%%%%%%%%%%% OPA相位校准(黄金分割法搜索+单点) %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%% APD对准角度+示波器读取APD输出电流 %%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%% 初始化参数 %%%%%%%%%%%%%%%%%%%%

%% !!!!!!!!!! 每次运行前仔细检查func_V_transition函数，采集卡采样率和点数 !!!!!!!!!!!!!
function [cal_result] = func_phasecali(s,v)

% clc;
DSO = 0;  % 示波器1，
CCD = 1;  % 相机
    spot_size = 4;
capture_card = 0; %采集卡
sample_times = 1;
close all;
% 不要清变量，中途退出程序的话需要重新判断电压源串口是否打开
% if (exist('SerialObj','var')==1)
%     delete(SerialObj);   %删除电压源串口，instrfindall找不到
% end
% delete(instrfindall);        %关闭所有打开的串口
% clear SerialObj;
% clear V_measure_final;
% clear V_before;
% clear 

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

times1 = [7,8,10,12,12,13,10,10,10,10,15,15,10];     %每一路要跑的次数
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
cal_result = voltage_calibration_best;
%%
% 
% filelocation=['E:\zjy\20250702_CUMEC_dualmrr1\' save_note];
% if exist(filelocation,'dir')==0
%     mkdir(filelocation);
% end
% filename = save_note;
% fullFilename = fullfile(filelocation, filename);
% save(fullFilename);
end