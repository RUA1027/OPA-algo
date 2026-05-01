s = serialport('COM6', 128000);%zjy电压源
configureTerminator(s, 'CR/LF', 'CR/LF');

V=4*rand(1,64);
v_1=func_V_transition(V);

ZJY_256VSRC_WRITE(s,v_1);
clear s;