function steeringResult = main_beam_steering(cfg)
%MAIN_BEAM_STEERING Simulate OPA beam steering over the configured angle range.
% Evaluate SMSR/SLSR, FWHM, pointing error, runtime, and sampling cost.
%
% Usage:
%   main_beam_steering
%   result = main_beam_steering(cfg)

if nargin < 1 || isempty(cfg)
    cfg = defaultConfig();
end

scanCfg = cfg.beamSteering;
if ~isfield(scanCfg, "exportMat")
    scanCfg.exportMat = false;
end
if ~isfield(scanCfg, "exportCsv")
    scanCfg.exportCsv = false;
end
if ~isfield(scanCfg, "exportDir") || strlength(string(scanCfg.exportDir)) == 0
    scanCfg.exportDir = fullfile(fileparts(fileparts(mfilename("fullpath"))), "beam_steering_outputs");
end
scanAngles = scanCfg.startThetaDeg:scanCfg.stepThetaDeg:scanCfg.endThetaDeg;
numAngles = numel(scanAngles);

% Method keys and display labels
methodKeys = {"mrev", "mrevGss", "pfpd", "fivePps", "spgd", "hillClimb"};
methodLabels = {"mREV", "mREV-GSS", "PFPD", "5PPS", "SPGD", "Hill-Climb"};
numMethods = numel(methodKeys);

% Pre-allocate
smsrAll      = zeros(numMethods, numAngles);
powerRatioAll = zeros(numMethods, numAngles);
fwhmAll = zeros(numMethods, numAngles);
pointingErrorAll = zeros(numMethods, numAngles);
evalCountAll = zeros(numMethods, numAngles);
runtimeAll = zeros(numMethods, numAngles);
targetIntensityAll = zeros(numMethods, numAngles);

if scanCfg.verbose
    fprintf("=== Start OPA beam steering simulation (%.1f deg -> %.1f deg, step %.1f deg) ===\n", ...
        scanCfg.startThetaDeg, scanCfg.endThetaDeg, scanCfg.stepThetaDeg);
end

for idx = 1:numAngles
    currentAngle = scanAngles(idx);

    if scanCfg.verbose
        fprintf("Calibrating target angle: %5.1f deg (%d/%d) ...\n", currentAngle, idx, numAngles);
    end

    runCfg = cfg;
    runCfg.sim.targetThetaDeg = currentAngle;
    runCfg.plot.showFigures = false;
    runCfg.output.printSummary = false;
    runCfg.output.exportMat = false;
    runCfg.output.exportCsv = false;
    runCfg.output.exportFigures = false;

    result = main_compare_calibration(runCfg);

    for m = 1:numMethods
        r = result.(methodKeys{m});
        smsrAll(m, idx)       = r.metrics.smsrDb;
        powerRatioAll(m, idx) = r.metrics.mainLobePowerRatio;
        fwhmAll(m, idx) = r.metrics.fwhmDeg;
        pointingErrorAll(m, idx) = r.metrics.pointingErrorDeg;
        evalCountAll(m, idx) = r.evalCount;
        runtimeAll(m, idx) = r.runtimeSec;
        targetIntensityAll(m, idx) = r.targetIntensity;
    end
end

if scanCfg.verbose
    fprintf("=== Beam steering simulation finished. Plotting curves... ===\n");
end

% Colours for plotting
colors = {[0.10,0.60,0.20], [0.10,0.35,0.80], [0.85,0.20,0.20], ...
          [0.80,0.50,0.00], [0.55,0.00,0.80], [0.00,0.70,0.70]};
markers = {'-o', '-^', '-s', '-d', '-v', '-p'};

if scanCfg.showFigures
    figure("Name", "Beam Steering Performance", "Color", "w", "Position", [100, 100, 1080, 440]);
    tl = tiledlayout(1,2, "TileSpacing", "compact", "Padding", "compact");

    nexttile;
    for m = 1:numMethods
        plot(scanAngles, smsrAll(m,:), markers{m}, "LineWidth", 1.8, ...
            "Color", colors{m}, "MarkerFaceColor", colors{m}); hold on;
    end
    grid on;
    xlim([scanCfg.startThetaDeg, scanCfg.endThetaDeg]);
    xlabel("Steering Angle \theta (deg)", "FontWeight", "bold");
    ylabel("SMSR (dB)", "FontWeight", "bold");
    title("SMSR vs. Steering Angle", "FontWeight", "bold");
    legend(methodLabels, "Location", "best");

    nexttile;
    for m = 1:numMethods
        plot(scanAngles, 100 * powerRatioAll(m,:), markers{m}, "LineWidth", 1.8, ...
            "Color", colors{m}, "MarkerFaceColor", colors{m}); hold on;
    end
    grid on;
    xlim([scanCfg.startThetaDeg, scanCfg.endThetaDeg]);
    ylim([0, 100]);
    xlabel("Steering Angle \theta (deg)", "FontWeight", "bold");
    ylabel("Main Lobe Power Ratio (%)", "FontWeight", "bold");
    title("Main Lobe Energy Ratio vs. Steering Angle", "FontWeight", "bold");
    legend(methodLabels, "Location", "best");

    title(tl, sprintf("OPA Beam Steering Summary (%.0f:%.0f:%.0f deg)", ...
        scanCfg.startThetaDeg, scanCfg.stepThetaDeg, scanCfg.endThetaDeg), "FontWeight", "bold");
end

% Build output struct
steeringResult = struct();
steeringResult.angles = scanAngles;

smsrStruct = struct();
powerRatioStruct = struct();
fwhmStruct = struct();
pointingErrorStruct = struct();
evalCountStruct = struct();
runtimeStruct = struct();
targetIntensityStruct = struct();
for m = 1:numMethods
    smsrStruct.(methodKeys{m})       = smsrAll(m, :);
    powerRatioStruct.(methodKeys{m}) = powerRatioAll(m, :);
    fwhmStruct.(methodKeys{m}) = fwhmAll(m, :);
    pointingErrorStruct.(methodKeys{m}) = pointingErrorAll(m, :);
    evalCountStruct.(methodKeys{m}) = evalCountAll(m, :);
    runtimeStruct.(methodKeys{m}) = runtimeAll(m, :);
    targetIntensityStruct.(methodKeys{m}) = targetIntensityAll(m, :);
end
steeringResult.smsr       = smsrStruct;
steeringResult.powerRatio = powerRatioStruct;
steeringResult.fwhmDeg = fwhmStruct;
steeringResult.pointingErrorDeg = pointingErrorStruct;
steeringResult.evalCount = evalCountStruct;
steeringResult.runtimeSec = runtimeStruct;
steeringResult.targetIntensity = targetIntensityStruct;
steeringResult.meta = struct("stepThetaDeg", scanCfg.stepThetaDeg, ...
    "targetRangeDeg", [scanCfg.startThetaDeg, scanCfg.endThetaDeg]);

exportInfo = struct("matPath", '', "csvPath", '');
if scanCfg.exportMat || scanCfg.exportCsv
    if ~exist(scanCfg.exportDir, "dir")
        mkdir(scanCfg.exportDir);
    end

    timestamp = datestr(now, "yyyymmdd_HHMMSS");
    fileStem = sprintf('beam_steering_%s', timestamp);

    if scanCfg.exportMat
        matPath = fullfile(scanCfg.exportDir, [fileStem, '.mat']);
        save(matPath, "steeringResult");
        exportInfo.matPath = matPath;
    end

    if scanCfg.exportCsv
        csvPath = fullfile(scanCfg.exportDir, [fileStem, '.csv']);
        T = table(scanAngles(:), ...
            smsrAll(1,:).', smsrAll(2,:).', smsrAll(3,:).', ...
            smsrAll(4,:).', smsrAll(5,:).', smsrAll(6,:).', ...
            fwhmAll(1,:).', fwhmAll(2,:).', fwhmAll(3,:).', ...
            fwhmAll(4,:).', fwhmAll(5,:).', fwhmAll(6,:).', ...
            pointingErrorAll(1,:).', pointingErrorAll(2,:).', pointingErrorAll(3,:).', ...
            pointingErrorAll(4,:).', pointingErrorAll(5,:).', pointingErrorAll(6,:).', ...
            evalCountAll(1,:).', evalCountAll(2,:).', evalCountAll(3,:).', ...
            evalCountAll(4,:).', evalCountAll(5,:).', evalCountAll(6,:).', ...
            runtimeAll(1,:).', runtimeAll(2,:).', runtimeAll(3,:).', ...
            runtimeAll(4,:).', runtimeAll(5,:).', runtimeAll(6,:).', ...
            targetIntensityAll(1,:).', targetIntensityAll(2,:).', targetIntensityAll(3,:).', ...
            targetIntensityAll(4,:).', targetIntensityAll(5,:).', targetIntensityAll(6,:).', ...
            powerRatioAll(1,:).', powerRatioAll(2,:).', powerRatioAll(3,:).', ...
            powerRatioAll(4,:).', powerRatioAll(5,:).', powerRatioAll(6,:).', ...
            'VariableNames', {'angleDeg', ...
            'smsr_mrev_db', 'smsr_mrevGss_db', 'smsr_pfpd_db', ...
            'smsr_5pps_db', 'smsr_spgd_db', 'smsr_hillClimb_db', ...
            'fwhm_mrev_deg', 'fwhm_mrevGss_deg', 'fwhm_pfpd_deg', ...
            'fwhm_5pps_deg', 'fwhm_spgd_deg', 'fwhm_hillClimb_deg', ...
            'pointingError_mrev_deg', 'pointingError_mrevGss_deg', 'pointingError_pfpd_deg', ...
            'pointingError_5pps_deg', 'pointingError_spgd_deg', 'pointingError_hillClimb_deg', ...
            'evalCount_mrev', 'evalCount_mrevGss', 'evalCount_pfpd', ...
            'evalCount_5pps', 'evalCount_spgd', 'evalCount_hillClimb', ...
            'runtime_mrev_sec', 'runtime_mrevGss_sec', 'runtime_pfpd_sec', ...
            'runtime_5pps_sec', 'runtime_spgd_sec', 'runtime_hillClimb_sec', ...
            'targetIntensity_mrev', 'targetIntensity_mrevGss', 'targetIntensity_pfpd', ...
            'targetIntensity_5pps', 'targetIntensity_spgd', 'targetIntensity_hillClimb', ...
            'mainLobeRatio_mrev', 'mainLobeRatio_mrevGss', 'mainLobeRatio_pfpd', ...
            'mainLobeRatio_5pps', 'mainLobeRatio_spgd', 'mainLobeRatio_hillClimb'});
        writetable(T, csvPath);
        exportInfo.csvPath = csvPath;
    end

    if scanCfg.verbose
        if ~isempty(exportInfo.matPath)
            fprintf("Saved MAT result: %s\n", exportInfo.matPath);
        end
        if ~isempty(exportInfo.csvPath)
            fprintf("Saved CSV result: %s\n", exportInfo.csvPath);
        end
    end
end

steeringResult.export = exportInfo;

end
