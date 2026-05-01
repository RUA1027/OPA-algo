function state = exp_build_state(cfg)
%EXP_BUILD_STATE Build algorithm state for experiment-side runners.

arguments
    cfg (1,1) struct
end

state = struct();
state.numChannels = cfg.numChannels;
state.controlMin = cfg.controlMin;
state.controlMax = cfg.controlMax;
state.u2pi = cfg.u2pi;
state.phasePerU = 2 * pi / state.u2pi;

if isempty(cfg.initialControlU)
    state.initialControlU = state.controlMin + ...
        (state.controlMax - state.controlMin) .* rand(1, state.numChannels);
else
    validateattributes(cfg.initialControlU, {'numeric'}, {'vector', 'numel', state.numChannels});
    state.initialControlU = reshape(double(cfg.initialControlU), 1, []);
    state.initialControlU = min(max(state.initialControlU, state.controlMin), state.controlMax);
end

end

