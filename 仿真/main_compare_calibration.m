function compareResult = main_compare_calibration(cfg)
%MAIN_COMPARE_CALIBRATION Compare 6 OPA calibration algorithms.
%
% Usage:
%   main_compare_calibration
%   result = main_compare_calibration(cfg)

if nargin < 1 || isempty(cfg)
    cfg = defaultConfig();
end

state = initSimulationState(cfg);

maxRounds = max([cfg.mrev.maxRounds, cfg.mrevGss.maxRounds, cfg.pfpd.rounds, ...
                 cfg.fivePps.maxRounds, cfg.spgd.numLogicalRounds, cfg.hillClimb.maxRounds]);
schedule = makeChannelSchedule(cfg.channelOrder, state.numChannels, maxRounds, cfg.general.seed);

cfg.mrev.channelSchedule = schedule(1:cfg.mrev.maxRounds, :);
cfg.mrevGss.channelSchedule = schedule(1:cfg.mrevGss.maxRounds, :);
cfg.pfpd.channelSchedule = schedule(1:cfg.pfpd.rounds, :);
cfg.fivePps.channelSchedule = schedule(1:cfg.fivePps.maxRounds, :);
cfg.hillClimb.channelSchedule = schedule(1:cfg.hillClimb.maxRounds, :);

initialControlU = state.initialControlU;
[thetaDeg, initField, initIntensity] = computeFarField(initialControlU, state);
initialMetrics = computeMetrics(thetaDeg, initIntensity, state.targetThetaDeg);
initialTargetIntensity = computeTargetIntensity(initialControlU, state);

measureFnMrev = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnMrevGss = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnPfpd = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFn5pps = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnSpgd = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnHillClimb = makeMeasureFunction(state, cfg, cfg.general.seed);

tStart = tic;
mrev = runMrev(state, cfg.mrev, measureFnMrev);
mrev.runtimeSec = toc(tStart);

tStart = tic;
mrevGss = runMrevGss(state, cfg.mrevGss, measureFnMrevGss);
mrevGss.runtimeSec = toc(tStart);

tStart = tic;
pfpd = runPfpd(state, cfg.pfpd, measureFnPfpd);
pfpd.runtimeSec = toc(tStart);

tStart = tic;
fivePps = run5pps(state, cfg.fivePps, measureFn5pps);
fivePps.runtimeSec = toc(tStart);

tStart = tic;
spgd = runSpgd(state, cfg.spgd, measureFnSpgd);
spgd.runtimeSec = toc(tStart);

tStart = tic;
hillClimb = runHillClimb(state, cfg.hillClimb, measureFnHillClimb);
hillClimb.runtimeSec = toc(tStart);

mrev = iAttachFieldAndMetrics(mrev, state, thetaDeg);
mrevGss = iAttachFieldAndMetrics(mrevGss, state, thetaDeg);
pfpd = iAttachFieldAndMetrics(pfpd, state, thetaDeg);
fivePps = iAttachFieldAndMetrics(fivePps, state, thetaDeg);
spgd = iAttachFieldAndMetrics(spgd, state, thetaDeg);
hillClimb = iAttachFieldAndMetrics(hillClimb, state, thetaDeg);

compareResult = struct();
compareResult.cfg = cfg;
compareResult.state = state;

compareResult.initial = struct();
compareResult.initial.controlU = initialControlU;
compareResult.initial.field = initField;
compareResult.initial.intensity = initIntensity;
compareResult.initial.metrics = initialMetrics;
compareResult.initial.targetIntensity = initialTargetIntensity;

compareResult.mrev = mrev;
compareResult.mrevGss = mrevGss;
compareResult.pfpd = pfpd;
compareResult.fivePps = fivePps;
compareResult.spgd = spgd;
compareResult.hillClimb = hillClimb;
compareResult.output = struct();

if iShouldPrintSummary(cfg)
    iPrintSummary(compareResult);
end

figHandles = gobjects(0);
if cfg.plot.showFigures || iShouldExportFigures(cfg)
    visibleMode = "on";
    if ~cfg.plot.showFigures
        visibleMode = "off";
    end
    figHandles = iPlotComparison(compareResult, visibleMode);
end

compareResult = iExportCompareResult(compareResult, figHandles);

if ~cfg.plot.showFigures && ~isempty(figHandles)
    close(figHandles(isgraphics(figHandles)));
end

if nargout == 0
    clear compareResult;
end

end

function methodResult = iAttachFieldAndMetrics(methodResult, state, thetaDeg)
[~, field, intensity] = computeFarField(methodResult.controlU, state);
methodResult.field = field;
methodResult.intensity = intensity;
methodResult.metrics = computeMetrics(thetaDeg, intensity, state.targetThetaDeg);
methodResult.targetIntensity = computeTargetIntensity(methodResult.controlU, state);
end

function tf = iShouldPrintSummary(cfg)
tf = true;
if isfield(cfg, "output") && isfield(cfg.output, "printSummary")
    tf = logical(cfg.output.printSummary);
end
end

function tf = iShouldExportFigures(cfg)
tf = false;
if isfield(cfg, "output") && isfield(cfg.output, "exportFigures")
    tf = logical(cfg.output.exportFigures);
end
end

function iPrintSummary(result)
initialTarget = result.initial.targetIntensity;
[methodKeys, ~] = iMethodKeysAndLabels();

fprintf("\n=== OPA Calibration Comparison Summary ===\n");
fprintf("Target angle: %.2f deg\n", result.state.targetThetaDeg);
fprintf("Channels: %d\n", result.state.numChannels);
fprintf("Initial target intensity: %.6g\n", initialTarget);

for idx = 1:numel(methodKeys)
    iPrintOneMethod(result.(methodKeys{idx}), initialTarget);
end
end

function iPrintOneMethod(methodResult, initialTarget)
fprintf("\n[%s]\n", methodResult.method);
fprintf("  Rounds: %d\n", methodResult.roundCount);
fprintf("  Eval count: %d\n", methodResult.evalCount);
fprintf("  Runtime (s): %.3f\n", methodResult.runtimeSec);
fprintf("  Target intensity: %.6g (x%.3f)\n", methodResult.targetIntensity, methodResult.targetIntensity / initialTarget);
fprintf("  SMSR/SLSR (dB): %.3f\n", methodResult.metrics.smsrDb);
fprintf("  FWHM / beam divergence (deg): %.3f\n", methodResult.metrics.fwhmDeg);
fprintf("  Pointing error (deg): %.3f\n", methodResult.metrics.pointingErrorDeg);
fprintf("  Main-lobe power ratio (%%): %.2f\n", 100 * methodResult.metrics.mainLobePowerRatio);
end

function figHandles = iPlotComparison(result, visibleMode)
cfg = result.cfg;
dbFloor = cfg.plot.dbFloor;
theta = result.state.thetaGridDeg;

[methods, labels] = iMethodKeysAndLabels();
colors = {[0.10,0.60,0.20], [0.10,0.35,0.80], [0.85,0.20,0.20], ...
          [0.80,0.50,0.00], [0.55,0.00,0.80], [0.00,0.70,0.70]};
markers = {'o', '^', 's', 'd', 'v', 'p'};

figHandles = gobjects(1, 4);

figHandles(1) = figure("Name", "OPA Far-field Comparison", "Color", "w", "Visible", visibleMode);
subplot(2,1,1);
initNorm = result.initial.intensity / max(result.initial.intensity);
plot(theta, initNorm, "k-", "LineWidth", 1.2); hold on;
for m = 1:numel(methods)
    r = result.(methods{m});
    normI = r.intensity / max(r.intensity);
    plot(theta, normI, "-", "LineWidth", 1.2, "Color", colors{m});
end
grid on;
xlabel("\theta (deg)"); ylabel("Normalized Intensity");
title("Far-field Intensity");
legend(["Initial", labels], "Location", "best");

subplot(2,1,2);
initDb = 10 * log10(max(initNorm, 10^(dbFloor/10)));
plot(theta, initDb, "k-", "LineWidth", 1.2); hold on;
for m = 1:numel(methods)
    r = result.(methods{m});
    normI = r.intensity / max(r.intensity);
    dbI = 10 * log10(max(normI, 10^(dbFloor/10)));
    plot(theta, dbI, "-", "LineWidth", 1.2, "Color", colors{m});
end
grid on;
xlabel("\theta (deg)"); ylabel("Intensity (dB)");
ylim([dbFloor, 0]);
title("Far-field Intensity (dB)");
legend(["Initial", labels], "Location", "best");

figHandles(2) = figure("Name", "Target Intensity Convergence", "Color", "w", "Visible", visibleMode);
for m = 1:numel(methods)
    r = result.(methods{m});
    plot(1:numel(r.roundTargetIntensityTrue), r.roundTargetIntensityTrue, ...
        [markers{m}, '-'], "LineWidth", 1.3, "Color", colors{m}); hold on;
end
yline(result.initial.targetIntensity, "k--", "Initial", "LineWidth", 1.2);
grid on;
xlabel("Round"); ylabel("Target Intensity");
title("Round-wise Target Intensity");
legend(labels, "Location", "best");

figHandles(3) = figure("Name", "Key Metrics", "Color", "w", "Visible", visibleMode);
smsrVals = zeros(1, numel(methods));
evalVals = zeros(1, numel(methods));
fwhmVals = zeros(1, numel(methods));
pointErrVals = zeros(1, numel(methods));
for m = 1:numel(methods)
    r = result.(methods{m});
    smsrVals(m) = r.metrics.smsrDb;
    evalVals(m) = r.evalCount;
    fwhmVals(m) = r.metrics.fwhmDeg;
    pointErrVals(m) = r.metrics.pointingErrorAbsDeg;
end

subplot(2,2,1);
bar(categorical(string(labels), string(labels)), smsrVals);
ylabel("SMSR/SLSR (dB)");
title("Side-lobe Suppression");
grid on;

subplot(2,2,2);
bar(categorical(string(labels), string(labels)), evalVals);
ylabel("Objective Evaluations");
title("Sampling Cost");
grid on;

subplot(2,2,3);
bar(categorical(string(labels), string(labels)), fwhmVals);
ylabel("FWHM (deg)");
title("Beam Divergence");
grid on;

subplot(2,2,4);
bar(categorical(string(labels), string(labels)), pointErrVals);
ylabel("|Pointing Error| (deg)");
title("Geometric Accuracy");
grid on;

figHandles(4) = figure("Name", "Far-field Electric Field Magnitude", "Color", "w", "Visible", visibleMode);
plot(theta, abs(result.initial.field) / max(abs(result.initial.field)), "k-", "LineWidth", 1.2); hold on;
for m = 1:numel(methods)
    r = result.(methods{m});
    plot(theta, abs(r.field) / max(abs(r.field)), "-", "LineWidth", 1.2, "Color", colors{m});
end
grid on;
xlabel("\theta (deg)"); ylabel("|E| (normalized)");
title("Far-field Electric Field Magnitude");
legend(["Initial", labels], "Location", "best");
end

function result = iExportCompareResult(result, figHandles)
outCfg = iResolveOutputCfg(result.cfg);
exportInfo = struct("outputDir", "", "matPath", "", "summaryCsvPath", "", ...
    "roundCsvPath", "", "farFieldCsvPath", "", "figurePaths", strings(0, 1));

if ~(outCfg.exportMat || outCfg.exportCsv || outCfg.exportFigures)
    result.output = exportInfo;
    return;
end

if ~exist(outCfg.outputDir, "dir")
    mkdir(outCfg.outputDir);
end
timestamp = datestr(now, "yyyymmdd_HHMMSS");
runDir = fullfile(outCfg.outputDir, "compare_" + string(timestamp));
mkdir(runDir);
exportInfo.outputDir = string(runDir);

if outCfg.exportCsv
    summaryCsvPath = fullfile(runDir, "algorithm_summary.csv");
    roundCsvPath = fullfile(runDir, "round_history.csv");
    farFieldCsvPath = fullfile(runDir, "far_field_intensity.csv");
    writetable(iBuildMethodSummaryTable(result), summaryCsvPath);
    writetable(iBuildRoundHistoryTable(result), roundCsvPath);
    writetable(iBuildFarFieldTable(result), farFieldCsvPath);
    exportInfo.summaryCsvPath = string(summaryCsvPath);
    exportInfo.roundCsvPath = string(roundCsvPath);
    exportInfo.farFieldCsvPath = string(farFieldCsvPath);
end

if outCfg.exportFigures && ~isempty(figHandles)
    exportInfo.figurePaths = iSaveFigures(figHandles, runDir);
end

result.output = exportInfo;

if outCfg.exportMat
    matPath = fullfile(runDir, "compare_result.mat");
    compareResult = result;
    save(matPath, "compareResult");
    exportInfo.matPath = string(matPath);
    result.output = exportInfo;
    compareResult = result;
    save(matPath, "compareResult");
end
end

function outCfg = iResolveOutputCfg(cfg)
outCfg = struct();
outCfg.exportMat = false;
outCfg.exportCsv = false;
outCfg.exportFigures = false;
outCfg.outputDir = fullfile(fileparts(mfilename("fullpath")), "simulation_outputs");

if isfield(cfg, "output")
    if isfield(cfg.output, "exportMat"), outCfg.exportMat = logical(cfg.output.exportMat); end
    if isfield(cfg.output, "exportCsv"), outCfg.exportCsv = logical(cfg.output.exportCsv); end
    if isfield(cfg.output, "exportFigures"), outCfg.exportFigures = logical(cfg.output.exportFigures); end
    if isfield(cfg.output, "outputDir") && strlength(string(cfg.output.outputDir)) > 0
        outCfg.outputDir = char(string(cfg.output.outputDir));
    end
end
end

function figurePaths = iSaveFigures(figHandles, runDir)
names = ["far_field_comparison.png"; "target_intensity_convergence.png"; ...
         "key_metrics.png"; "electric_field_magnitude.png"];
figurePaths = strings(0, 1);
for idx = 1:min(numel(figHandles), numel(names))
    if isgraphics(figHandles(idx))
        outPath = fullfile(runDir, names(idx));
        saveas(figHandles(idx), outPath);
        figurePaths(end + 1, 1) = string(outPath);
    end
end
end

function T = iBuildMethodSummaryTable(result)
[methods, labels] = iMethodKeysAndLabels();
n = numel(methods);

method = strings(n, 1);
roundCount = zeros(n, 1);
evalCount = zeros(n, 1);
runtimeSec = zeros(n, 1);
targetIntensity = zeros(n, 1);
mainPeak = zeros(n, 1);
sidePeak = zeros(n, 1);
smsrDb = zeros(n, 1);
slsrDb = zeros(n, 1);
fwhmDeg = zeros(n, 1);
beamDivergenceDeg = zeros(n, 1);
mainPeakThetaDeg = zeros(n, 1);
targetThetaDeg = zeros(n, 1);
pointingErrorDeg = zeros(n, 1);
pointingErrorAbsDeg = zeros(n, 1);
mainLobePowerRatio = zeros(n, 1);
actualIter = NaN(n, 1);

for idx = 1:n
    r = result.(methods{idx});
    method(idx) = labels(idx);
    roundCount(idx) = r.roundCount;
    evalCount(idx) = r.evalCount;
    runtimeSec(idx) = r.runtimeSec;
    targetIntensity(idx) = r.targetIntensity;
    mainPeak(idx) = r.metrics.mainPeak;
    sidePeak(idx) = r.metrics.sidePeak;
    smsrDb(idx) = r.metrics.smsrDb;
    slsrDb(idx) = r.metrics.slsrDb;
    fwhmDeg(idx) = r.metrics.fwhmDeg;
    beamDivergenceDeg(idx) = r.metrics.beamDivergenceDeg;
    mainPeakThetaDeg(idx) = r.metrics.mainPeakThetaDeg;
    targetThetaDeg(idx) = r.metrics.targetThetaDeg;
    pointingErrorDeg(idx) = r.metrics.pointingErrorDeg;
    pointingErrorAbsDeg(idx) = r.metrics.pointingErrorAbsDeg;
    mainLobePowerRatio(idx) = r.metrics.mainLobePowerRatio;
    if isfield(r, "actualIter")
        actualIter(idx) = r.actualIter;
    end
end

T = table(method, roundCount, evalCount, runtimeSec, actualIter, ...
    targetIntensity, mainPeak, sidePeak, smsrDb, slsrDb, fwhmDeg, ...
    beamDivergenceDeg, mainPeakThetaDeg, targetThetaDeg, ...
    pointingErrorDeg, pointingErrorAbsDeg, mainLobePowerRatio);
end

function T = iBuildRoundHistoryTable(result)
[methods, labels] = iMethodKeysAndLabels();
totalRows = 0;
for idx = 1:numel(methods)
    totalRows = totalRows + numel(result.(methods{idx}).roundTargetIntensityTrue);
end

method = strings(totalRows, 1);
roundIndex = zeros(totalRows, 1);
roundTargetIntensityTrue = zeros(totalRows, 1);
roundEvalCount = zeros(totalRows, 1);
roundAccepted = false(totalRows, 1);

row = 0;
for idx = 1:numel(methods)
    r = result.(methods{idx});
    for roundIdx = 1:numel(r.roundTargetIntensityTrue)
        row = row + 1;
        method(row) = labels(idx);
        roundIndex(row) = roundIdx;
        roundTargetIntensityTrue(row) = r.roundTargetIntensityTrue(roundIdx);
        roundEvalCount(row) = r.roundEvalCount(roundIdx);
        roundAccepted(row) = r.roundAccepted(roundIdx);
    end
end

T = table(method, roundIndex, roundTargetIntensityTrue, roundEvalCount, roundAccepted);
end

function T = iBuildFarFieldTable(result)
[methods, ~] = iMethodKeysAndLabels();
thetaDeg = result.state.thetaGridDeg(:);
T = table(thetaDeg, result.initial.intensity(:), 'VariableNames', {'theta_deg', 'initial_intensity'});

for idx = 1:numel(methods)
    r = result.(methods{idx});
    rawName = char(string(methods{idx}) + "_intensity");
    normName = char(string(methods{idx}) + "_norm_intensity");
    T.(rawName) = r.intensity(:);
    T.(normName) = r.intensity(:) ./ max(r.intensity(:));
end
end

function [methodKeys, methodLabels] = iMethodKeysAndLabels()
methodKeys = {"mrev", "mrevGss", "pfpd", "fivePps", "spgd", "hillClimb"};
methodLabels = ["mREV", "mREV-GSS", "PFPD", "5PPS", "SPGD", "Hill-Climb"];
end
