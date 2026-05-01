function loopback_data = ZJY_256VSRC_WRITE(s,float_voltage_all_channels)
    channels = 256;
    bpc = 14; %14bit DAC
    max_voltage = 12; %0-12v
    %real voltage value -> uint16
    max_int = 2^bpc-1;
    if ~isrow(float_voltage_all_channels)
        float_voltage_all_channels = float_voltage_all_channels';
    end
    
    fakeint_voltage = uint32(float_voltage_all_channels./max_voltage*max_int);
    
    half_bytes_per_channel = ceil(bpc/4);
    int8_4b_v = repmat(fakeint_voltage,half_bytes_per_channel,1);
    for i=half_bytes_per_channel:-1:2
        int8_4b_v(i-1,:) =  idivide(int8_4b_v(i,:),16);
        int8_4b_v(i,:) =  mod(int8_4b_v(i,:),16);
    end
    int8_4b_v = dec2hex(uint8(int8_4b_v));
    write_buf = ['VA ',reshape(int8_4b_v,1,channels*half_bytes_per_channel),'Z'];
    place=1;
    if strlength(write_buf)>510
        while(place<strlength(write_buf))
            if place+509<strlength(write_buf)
                % write(s,[write_buf(place:place+383)],"uint8");
                writeline(s,write_buf(place:place+509))
                ack=readline(s);
            else
                % write(s,[write_buf(place:end)],"uint8");
                writeline(s,write_buf(place:end));
                ack=readline(s);
            end
            place=place+510;
        end
    else
        writeline(s,write_buf);
        ack=readline(s);
    end
    loopback_data=readline(s);
    if loopback_data ~= sprintf('\0ACK, All Channel UPDATE')
        disp("电压源出错，重试");
        error(loopback_data);
    end
end