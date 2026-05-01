function compareResult = main_compare_calibration(cfg)
%MAIN_COMPARE_CALIBRATION Compare 7 OPA calibration algorithms.
%
% Usage:
%   main_compare_calibration
%   result = main_compare_calibration(cfg)

if nargin < 1 || isempty(cfg)
    cfg = defaultConfig();
end

state = initSimulationState(cfg);

% Channel schedule (shared across channel-sequential algorithms)
maxRounds = max([cfg.mrev.maxRounds, cfg.mrevGss.maxRounds, cfg.pfpd.rounds, ...
                 cfg.fivePps.maxRounds, cfg.hybrid.pps.maxRounds, cfg.caio.maxRounds]);
schedule = makeChannelSchedule(cfg.channelOrder, state.numChannels, maxRounds, cfg.general.seed);

cfg.mrev.channelSchedule    = schedule(1:cfg.mrev.maxRounds, :);
cfg.mrevGss.channelSchedule = schedule(1:cfg.mrevGss.maxRounds, :);
cfg.pfpd.channelSchedule    = schedule(1:cfg.pfpd.rounds, :);
cfg.fivePps.channelSchedule = schedule(1:cfg.fivePps.maxRounds, :);
cfg.hybrid.pps.channelSchedule = schedule(1:cfg.hybrid.pps.maxRounds, :);
cfg.caio.channelSchedule    = schedule(1:cfg.caio.maxRounds, :);

%%计算未标定时的远场光场
initialControlU = state.initialControlU;
[thetaDeg, initField, initIntensity] = computeFarField(initialControlU, state);
initialMetrics = computeMetrics(thetaDeg, initIntensity, state.targetThetaDeg);
initialTargetIntensity = computeTargetIntensity(initialControlU, state);

%模拟噪声和量化（每种算法独立的测量函数）
measureFnMrev    = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnMrevGss = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnPfpd    = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFn5pps    = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnSpsa    = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnHybrid  = makeMeasureFunction(state, cfg, cfg.general.seed);
measureFnCaio    = makeMeasureFunction(state, cfg, cfg.general.seed);

% --- Run existing 3 algorithms ---
tStart = tic;
mrev = runMrev(state, cfg.mrev, measureFnMrev);
mrev.runtimeSec = toc(tStart);

tStart = tic;
mrevGss = runMrevGss(state, cfg.mrevGss, measureFnMrevGss);
mrevGss.runtimeSec = toc(tStart);

tStart = tic;
pfpd = runPfpd(state, cfg.pfpd, measureFnPfpd);
pfpd.runtimeSec = toc(tStart);

% --- Run 4 new algorithms ---
tStart = tic;
fivePps = run5pps(state, cfg.fivePps, measureFn5pps);
fivePps.runtimeSec = toc(tStart);

tStart = tic;
spsa = runSpsa(state, cfg.spsa, measureFnSpsa);
spsa.runtimeSec = toc(tStart);

tStart = tic;
hybrid = runHybridSpsaPps(state, cfg.hybrid, measureFnHybrid);
hybrid.runtimeSec = toc(tStart);

tStart = tic;
caio = runCaio(state, cfg.caio, measureFnCaio);
caio.runtimeSec = toc(tStart);

% Attach far-field and metrics
mrev    = iAttachFieldAndMetrics(mrev, state, thetaDeg);
mrevGss = iAttachFieldAndMetrics(mrevGss, state, thetaDeg);
pfpd    = iAttachFieldAndMetrics(pfpd, state, thetaDeg);
fivePps = iAttachFieldAndMetrics(fivePps, state, thetaDeg);
spsa    = iAttachFieldAndMetrics(spsa, state, thetaDeg);
hybrid  = iAttachFieldAndMetrics(hybrid, state, thetaDeg);
caio    = iAttachFieldAndMetrics(caio, state, thetaDeg);

compareResult = struct();
compareResult.cfg   = cfg;
compareResult.state = state;

compareResult.initial = struct();
compareResult.initial.controlU        = initialControlU;
compareResult.initial.field           = initField;
compareResult.initial.intensity       = initIntensity;
compareResult.initial.metrics         = initialMetrics;
compareResult.initial.targetIntensity = initialTargetIntensity;

compareResult.mrev    = mrev;
compareResult.mrevGss = mrevGss;
compareResult.pfpd    = pfpd;
compareResult.fivePps = fivePps;
compareResult.spsa    = spsa;
compareResult.hybrid  = hybrid;
compareResult.caio    = caio;

shouldPrintSummary = true;
if isfield(cfg, "output") && isfield(cfg.output, "printSummary")
    shouldPrintSummary = logical(cfg.output.printSummary);
end
if shouldPrintSummary
    iPrintSummary(compareResult);
end

if cfg.plot.showFigures
    iPlotComparison(compareResult);
end

if nargout == 0
    clear compareResult;
end

end

%计算指标
function methodResult = iAttachFieldAndMetrics(methodResult, state, thetaDeg)
[~, field, intensity] = computeFarField(methodResult.controlU, state);
methodResult.field = field;
methodResult.intensity = intensity;
methodResult.metrics = computeMetrics(thetaDeg, intensity, state.targetThetaDeg);
methodResult.targetIntensity = computeTargetIntensity(methodResult.controlU, state);
end

%输出函数
function iPrintSummary(result)
initialTarget = result.initial.targetIntensity;

fprintf("\n=== OPA Calibration Comparison Summary ===\n");
fprintf("Target angle: %.2f deg\n", result.state.targetThetaDeg);
fprintf("Channels: %d\n", result.state.numChannels);
fprintf("Initial target intensity: %.6g\n", initialTarget);

iPrintOneMethod(result.mrev, initialTarget);
iPrintOneMethod(result.mrevGss, initialTarget);
iPrintOneMethod(result.pfpd, initialTarget);
iPrintOneMethod(result.fivePps, initialTarget);
iPrintOneMethod(result.spsa, initialTarget);
iPrintOneMethod(result.hybrid, initialTarget);
iPrintOneMethod(result.caio, initialTarget);

end

function iPrintOneMethod(methodResult, initialTarget)
fprintf("\n[%s]\n", methodResult.method);
fprintf("  Rounds: %d\n", methodResult.roundCount);
fprintf("  Eval count: %d\n", methodResult.evalCount);
fprintf("  Runtime (s): %.3f\n", methodResult.runtimeSec);
fprintf("  Target intensity: %.6g (x%.3f)\n", methodResult.targetIntensity, methodResult.targetIntensity / initialTarget);
fprintf("  SMSR (dB): %.3f\n", methodResult.metrics.smsrDb);
fprintf("  3dB beamwidth (deg): %.3f\n", methodResult.metrics.beamwidth3dBDeg);
fprintf("  Main-lobe power ratio (%%): %.2f\n", 100 * methodResult.metrics.mainLobePowerRatio);
end

function iPlotComparison(result)
cfg = result.cfg;
dbFloor = cfg.plot.dbFloor;
theta = result.state.thetaGridDeg;

% Method list for iteration
methods = {"mrev", "mrevGss", "pfpd", "fivePps", "spsa", "hybrid", "caio"};
labels  = {"mREV", "mREV-GSS", "PFPD", "5PPS", "SPSA", "Hybrid-SPSA-PPS", "CAIO"};
colors  = {[0.10,0.60,0.20], [0.10,0.35,0.80], [0.85,0.20,0.20], ...
           [0.80,0.50,0.00], [0.55,0.00,0.80], [0.00,0.70,0.70], [0.90,0.10,0.60]};
markers = {'o', '^', 's', 'd', 'v', 'p', 'h'};

%% Figure 1: Far-field intensity (linear + dB)
figure("Name", "OPA Far-field Comparison", "Color", "w");

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

%% Figure 2: Convergence
figure("Name", "Target Intensity Convergence", "Color", "w");
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

%% Figure 3: Key metrics bar charts
figure("Name", "Key Metrics", "Color", "w");

smsrVals = zeros(1, numel(methods));
evalVals = zeros(1, numel(methods));
for m = 1:numel(methods)
    r = result.(methods{m});
    smsrVals(m) = r.metrics.smsrDb;
    evalVals(m) = r.evalCount;
end

subplot(1,3,1);
bar(categorical(string(labels), string(labels)), smsrVals);
ylabel("SMSR (dB)");
title("Side-mode Suppression");
grid on;

subplot(1,3,2);
bar(categorical(string(labels), string(labels)), evalVals);
ylabel("Objective Evaluations");
title("Sampling Cost");
grid on;

%% 主瓣能量占比补充
powerRatioVals = zeros(1, numel(methods));
for m = 1:numel(methods)
    r = result.(methods{m});
    powerRatioVals(m) = r.metrics.mainLobePowerRatio * 100;
end
subplot(1,3,3);
bar(categorical(string(labels), string(labels)), powerRatioVals);
ylabel("Main-Lobe Power Ratio (%)");
title("Main-Lobe Power Ratio");
grid on;

%% Figure 4: Electric field magnitude
figure("Name", "Far-field Electric Field Magnitude", "Color", "w");
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
