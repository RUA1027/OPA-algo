function schedule = exp_make_channel_schedule(channelCfg, numChannels, rounds)
%EXP_MAKE_CHANNEL_SCHEDULE Build channel visiting schedule.

arguments
    channelCfg (1,1) struct
    numChannels (1,1) double {mustBeInteger, mustBePositive}
    rounds (1,1) double {mustBeInteger, mustBePositive}
end

mode = "random_each_round"; % options: "fixed", "random_each_round"

if isfield(channelCfg, "mode") && strlength(string(channelCfg.mode)) > 0
    mode = string(channelCfg.mode);
end

switch upper(mode)
    case "FIXED"
        schedule = repmat(1:numChannels, rounds, 1);

    case "RANDOM_EACH_ROUND"
        seed = 0;
        if isfield(channelCfg, "seed")
            seed = channelCfg.seed;
        end
        stream = RandStream("mt19937ar", "Seed", seed);
        schedule = zeros(rounds, numChannels);
        for r = 1:rounds
            schedule(r, :) = randperm(stream, numChannels);
        end

    otherwise
        error("opa_exp:exp_make_channel_schedule:InvalidMode", ...
            "Unsupported channel order mode: %s", mode);
end

end
