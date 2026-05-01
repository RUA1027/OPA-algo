function schedule = makeChannelSchedule(channelCfg, numChannels, numRounds, baseSeed)
%MAKECHANNELSCHEDULE Create per-round channel update order.

arguments
    channelCfg (1,1) struct
    numChannels (1,1) double {mustBeInteger, mustBePositive}
    numRounds (1,1) double {mustBeInteger, mustBePositive}
    baseSeed (1,1) double
end

schedule = zeros(numRounds, numChannels);
mode = string(channelCfg.mode);

switch mode
    case "fixed"
        schedule(:,:) = repmat(1:numChannels, numRounds, 1);
    case "random_each_round"
        rng(baseSeed + channelCfg.randomSeedOffset, "twister");
        for roundIdx = 1:numRounds
            schedule(roundIdx, :) = randperm(numChannels);
        end
    otherwise
        error("opa_sim:makeChannelSchedule:InvalidMode", ...
            "Unsupported channel order mode: %s", mode);
end

end
