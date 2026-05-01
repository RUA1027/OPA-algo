function tests = wavelengthCalibrationTest
%WAVELENGTHCALIBRATIONTEST Tests for wavelength-indexed multipoint calibration.

tests = functiontests(localfunctions);
end

function testPreprocessUsesRawCsvWavelengthAndSelectsCenterTargets(testCase)
cfg = exp_default_config();
csvPath = fullfile(pwd, "smiley_coords.csv");
raw = readtable(csvPath, 'TextType', 'string');

[coords, summary] = exp_preprocess_zju_coords(csvPath, cfg.measure.ccdSpotSize);
targets = exp_select_wavelength_targets(csvPath, 1550, cfg.measure.ccdSpotSize);

verifyEqual(testCase, height(coords), height(raw));
verifyTrue(testCase, all(coords.wavelength_nm >= 1530 & coords.wavelength_nm <= 1570));
expectedWavelengths = unique(1550 + double(raw.delta_lambda_nm), "stable");
expectedGroups = numel(expectedWavelengths);
verifyEqual(testCase, summary.numWavelengthGroups, expectedGroups);
verifyEqual(testCase, summary.availableWavelengthNm, expectedWavelengths);
verifyFalse(testCase, ismember("wavelength_nm_0p1", string(coords.Properties.VariableNames)));
verifyEqual(testCase, targets.wavelength_nm, repmat(1550.0, 2, 1));
verifyEqual(testCase, string(targets.point_id), ["C5"; "C15"]);
verifyEqual(testCase, targets.x_pixel, [230; 90]);
verifyEqual(testCase, unique(targets.y_pixel), 132);
end

function testInputWavelengthUsesThousandthPrecision(testCase)
cfg = exp_default_config();
csvPath = fullfile(pwd, "smiley_coords.csv");

targets = exp_select_wavelength_targets(csvPath, 1543.151, cfg.measure.ccdSpotSize);

verifyEqual(testCase, unique(targets.wavelength_nm), 1543.151);
verifyEqual(testCase, height(targets), 2);
verifyEqual(testCase, string(targets.point_id), ["E0"; "E1"]);
verifyEqual(testCase, unique(targets.y_pixel), 107);

verifyError(testCase, @() exp_select_wavelength_targets(csvPath, 1543.2, cfg.measure.ccdSpotSize), ...
    "opa_exp:exp_select_wavelength_targets:NoTargets");
end

function testMissingWavelengthListsAvailableValues(testCase)
cfg = exp_default_config();
csvPath = fullfile(pwd, "smiley_coords.csv");

verifyError(testCase, @() exp_select_wavelength_targets(csvPath, 1530, cfg.measure.ccdSpotSize), ...
    "opa_exp:exp_select_wavelength_targets:NoTargets");
end

function testRejectsUnresolvableTargets(testCase)
csvPath = tempname + ".csv";
cleanup = onCleanup(@() iDeleteIfExists(csvPath));

T = table(["A"; "A"], [0; 1], [100; 105], [132; 132], [0; 0], [5; 10], ...
    'VariableNames', {'letter', 'index', 'x_pixel', 'y_pixel', 'delta_lambda_nm', 'eta_min_to_this_spot'});
writetable(T, csvPath);

verifyError(testCase, @() exp_preprocess_zju_coords(csvPath, 4), ...
    "opa_exp:exp_preprocess_zju_coords:UnresolvableTargets");
end

function testWavelengthRunnerWithMockSavesManifest(testCase)
cfg = iFastMockConfig();
outputRoot = tempname;
cleanup = onCleanup(@() iRemoveDirIfExists(outputRoot));

runResult = exp_run_wavelength_calibration("5PPS", 1550, cfg, ...
    'CsvPath', fullfile(pwd, "smiley_coords.csv"), ...
    'OutputRoot', outputRoot);

verifyEqual(testCase, runResult.targetCount, 2);
verifyEqual(testCase, string(runResult.targets.point_id), ["C5"; "C15"]);
verifyTrue(testCase, isfolder(runResult.outputDir));
verifyTrue(testCase, isfile(fullfile(runResult.outputDir, "run_manifest.csv")));
verifyTrue(testCase, isfile(fullfile(runResult.outputDir, "wavelength_run_result.mat")));

manifest = readtable(fullfile(runResult.outputDir, "run_manifest.csv"), 'TextType', 'string');
verifyEqual(testCase, height(manifest), 2);
verifyEqual(testCase, manifest.x_pixel, [230; 90]);
verifyTrue(testCase, all(manifest.status == "completed"));
verifyTrue(testCase, all(isfile(manifest.result_path)));
end

function testQuickstartDispatchesWavelengthModeWithConfigOverride(testCase)
cfg = iFastMockConfig();
outputRoot = tempname;
cleanup = onCleanup(@() iRemoveDirIfExists(outputRoot));

runResult = exp_quickstart("5PPS", 1550, cfg, ...
    'CsvPath', fullfile(pwd, "smiley_coords.csv"), ...
    'OutputRoot', outputRoot);

verifyEqual(testCase, runResult.targetCount, 2);
verifyEqual(testCase, string(runResult.targets.point_id), ["C5"; "C15"]);
end

function cfg = iFastMockConfig()
cfg = exp_default_config();
cfg.method = "5PPS";
cfg.numChannels = 1;
cfg.controlMin = 0;
cfg.controlMax = 1;
cfg.u2pi = 1;
cfg.initialControlU = 0.25;
cfg.channelOrder.mode = "fixed";
cfg.measure.delaySec = 0;
cfg.measure.ccdRealtimeDisplay.enabled = false;
cfg.runtime.mockMeasureFn = @iMockMeasure;
cfg.fivePps.maxRounds = 1;
cfg.fivePps.controlMin = cfg.controlMin;
cfg.fivePps.controlMax = cfg.controlMax;
end

function [y, sensorInfo] = iMockMeasure(controlU)
y = 1 - abs(controlU(1) - 0.75);
sensorInfo = struct();
end

function iDeleteIfExists(path)
if isfile(path)
    delete(path);
end
end

function iRemoveDirIfExists(path)
if isfolder(path)
    rmdir(path, 's');
end
end
