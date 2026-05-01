function V = func_V_transition(V_calibration)
V = zeros(1,256);

V(160)=2.15;
V(144:159)= V_calibration(1:16);
V(176:191)=V_calibration(17:32);
V(209:224)=V_calibration(33:48);
V(241:256)=V_calibration(49:64);
% V(1:128) = V_calibration(1:128);
end