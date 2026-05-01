function result = run5pps(state, cfg5pps, measureFn)
%RUN5PPS Schwider-Hariharan five-point phase stepping calibration.
%
%   result = run5pps(state, cfg5pps, measureFn)
%
%   Each channel is calibrated using 5 equally-spaced intensity samples
%   spanning one full period (u2pi). The known modulation frequency omega
%   allows analytic extraction of the optimal control voltage via the
%   Schwider-Hariharan formula. Multiple rounds handle crosstalk residuals.

arguments
    state   (1,1) struct
    cfg5pps (1,1) struct
    measureFn (1,1) function_handle
end

numChannels = state.numChannels;
maxRounds   = cfg5pps.maxRounds;
omega       = state.phasePerU;          % 2*pi / u2pi
u2pi        = state.u2pi;
uMin        = cfg5pps.controlMin;
uMax        = cfg5pps.controlMax;

if isfield(cfg5pps, 'channelSchedule')
    schedule = cfg5pps.channelSchedule;
else
    schedule = repmat(1:numChannels, maxRounds, 1);
end

if size(schedule, 1) < maxRounds || size(schedule, 2) ~= numChannels
    error('opa_sim:run5pps:InvalidSchedule', 'Invalid channelSchedule size.');
end

controlU  = state.initialControlU;
evalCount = 0;

roundTargetIntensityTrue = zeros(1, maxRounds);
roundEvalCount           = zeros(1, maxRounds);
roundAccepted            = false(1, maxRounds);

prevRoundIntensity = computeTargetIntensity(controlU, state);

for roundIdx = 1:maxRounds
    channelOrder     = schedule(roundIdx, :);
    evalCountStart   = evalCount;
    controlUBeforeRound = controlU;

    for orderIdx = 1:numChannels
        channelIdx = channelOrder(orderIdx);
        [uOpt, localEval] = iFiveStepByChannel( ...
            controlU, channelIdx, omega, uMin, uMax, u2pi, measureFn);
        controlU(channelIdx) = uOpt;
        evalCount = evalCount + localEval;
    end

    % Round-wise rollback protection
    roundCandidateIntensity = computeTargetIntensity(controlU, state);
    if roundCandidateIntensity < prevRoundIntensity
        controlU = controlUBeforeRound;
        roundTargetIntensityTrue(roundIdx) = prevRoundIntensity;
        roundAccepted(roundIdx) = false;
    else
        prevRoundIntensity = roundCandidateIntensity;
        roundTargetIntensityTrue(roundIdx) = roundCandidateIntensity;
        roundAccepted(roundIdx) = true;
    end

    roundEvalCount(roundIdx) = evalCount - evalCountStart;
end

result = struct();
result.method                   = "5PPS";
result.controlU                 = controlU;
result.evalCount                = evalCount;
result.roundCount               = maxRounds;
result.roundTargetIntensityTrue = roundTargetIntensityTrue;
result.roundEvalCount           = roundEvalCount;
result.roundAccepted            = roundAccepted;

end

%% ---- internal: five-step phase stepping for one channel ----
function [uOpt, evalCount] = iFiveStepByChannel(controlU, channelIdx, omega, uMin, uMax, u2pi, measureFn)

evalCount = 5;
deltaU = u2pi / 4;                       % quarter-period step

% Centre the 5-point window on the current control value
u0 = controlU(channelIdx);
samplePoints = u0 + (-2:2) * deltaU;     % [u0-2d, u0-d, u0, u0+d, u0+2d]

% Shift window if it exceeds bounds (preserve equal spacing)
if samplePoints(1) < uMin
    samplePoints = samplePoints + (uMin - samplePoints(1));
end
if samplePoints(5) > uMax
    samplePoints = samplePoints - (samplePoints(5) - uMax);
end

% Measure 5 intensities
I = zeros(1, 5);
for j = 1:5
    candidate = controlU;
    candidate(channelIdx) = samplePoints(j);
    I(j) = measureFn(candidate);
end

% Defensive: flat response -> keep current value
if all(I == I(1))
    uOpt = controlU(channelIdx);
    return;
end

% Schwider-Hariharan formula
% u0 for the formula is the centre of the window (samplePoints(3))
u0_centre = samplePoints(3);
phi0 = atan2(2 * (I(2) - I(4)), 2 * I(3) - I(5) - I(1));

% Optimal control: make omega*u + delta = 0 (mod 2pi)
uOpt = u0_centre - phi0 / omega;

% Constrain to [uMin, uMax] using modular wrap
uOpt = mod(uOpt - uMin, u2pi) + uMin;
if uOpt > uMax
    uOpt = uMin;   % safety clamp
end

end
