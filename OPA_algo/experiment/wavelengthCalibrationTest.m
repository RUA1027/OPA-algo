function tests = wavelengthCalibrationTest
%WAVELENGTHCALIBRATIONTEST Tests for wavelength-indexed multipoint calibration.

tests = functiontests(localfunctions);
end

function testPreprocessReadsSmileyCsvAndRoundsToThousandth(testCase)
cfg = exp_default_config();

[coords, summary] = exp_preprocess_zju_coords("", cfg.measure.ccdSpotSize);
raw = readtable(summary.csvPath, "TextType", "string");
expectedWavelengthNm = iRawWavelengthNm(raw);
expectedGroups = unique(round(expectedWavelengthNm, 3), "stable");

verifyGreaterThan(testCase, height(coords), 0);
verifyEqual(testCase, height(coords), height(raw));
verifyTrue(testCase, all(coords.wavelength_nm >= 1530 & coords.wavelength_nm <= 1570));
verifyEqual(testCase, coords.wavelength_nm, expectedWavelengthNm, "AbsTol", 1e-12);
verifyEqual(testCase, summary.numWavelengthGroups, numel(expectedGroups));
verifyEqual(testCase, summary.roundingDecimals, 3);
verifyTrue(testCase, endsWith(summary.csvPath, fullfile("algo", "vision0419", "smiley_coords.csv")));
verifyEqual(testCase, coords.wavelength_nm_0p001, round(coords.wavelength_nm, 3));
verifyEqual(testCase, string(coords.point_id), string(coords.letter) + string(coords.index));
verifyEqual(testCase, coords.delta_lambda_nm, coords.wavelength_nm - 1550, "AbsTol", 1e-12);
end

function testInputWavelengthMatchesTargetGroupAtThousandth(testCase)
cfg = exp_default_config();
[coords, ~] = exp_preprocess_zju_coords("", cfg.measure.ccdSpotSize);
groupCounts = groupcounts(coords, "wavelength_nm_0p001");
[maxCount, maxIdx] = max(groupCounts.GroupCount);
selectedWave = groupCounts.wavelength_nm_0p001(maxIdx);
expected = coords(coords.wavelength_nm_0p001 == selectedWave, :);

targets = exp_select_wavelength_targets("", selectedWave + 0.0004, cfg.measure.ccdSpotSize);

verifyGreaterThan(testCase, maxCount, 0);
verifyEqual(testCase, unique(targets.wavelength_nm_0p001), selectedWave);
verifyEqual(testCase, height(targets), height(expected));
verifyEqual(testCase, targets.source_order, expected.source_order);
verifyEqual(testCase, targets.x_pixel, expected.x_pixel);
verifyEqual(testCase, targets.y_pixel, expected.y_pixel);
verifyEqual(testCase, string(targets.point_id), string(expected.point_id));
end

function testExistingWavelengthCanSelectTargets(testCase)
cfg = exp_default_config();
[coords, ~] = exp_preprocess_zju_coords("", cfg.measure.ccdSpotSize);
selectedWave = coords.wavelength_nm_0p001(1);
expected = coords(coords.wavelength_nm_0p001 == selectedWave, :);

targets = exp_select_wavelength_targets("", selectedWave, cfg.measure.ccdSpotSize);

verifyEqual(testCase, unique(targets.wavelength_nm_0p001), selectedWave);
verifyEqual(testCase, height(targets), height(expected));
verifyEqual(testCase, targets.source_order, expected.source_order);
verifyEqual(testCase, targets.x_pixel, expected.x_pixel);
verifyEqual(testCase, targets.y_pixel, expected.y_pixel);
verifyEqual(testCase, string(targets.point_id), string(expected.point_id));
end

function testMissingWavelengthListsAvailableValues(testCase)
cfg = exp_default_config();
[coords, ~] = exp_preprocess_zju_coords("", cfg.measure.ccdSpotSize);
missingWave = iFindMissingWavelength(coords.wavelength_nm_0p001);

verifyError(testCase, @() exp_select_wavelength_targets("", missingWave, cfg.measure.ccdSpotSize), ...
    "opa_exp:exp_select_wavelength_targets:NoTargets");
end

function testPreprocessAcceptsSmallFileWithoutFixedPointCount(testCase)
csvPath = tempname + ".csv";
cleanup = onCleanup(@() iDeleteIfExists(csvPath));

T = table(["F"; "F"; "F"], [0; 1; 2], [100; 120; 140], [132; 132; 132], [-0.001; 0; 0.001], [5; 10; 15], ...
    'VariableNames', {'letter', 'index', 'x_pixel', 'y_pixel', 'delta_lambda_nm', 'eta_min_to_this_spot'});
writetable(T, csvPath);

[coords, summary] = exp_preprocess_zju_coords(csvPath, 4);

verifyEqual(testCase, height(coords), 3);
verifyEqual(testCase, summary.numPoints, 3);
verifyEqual(testCase, coords.wavelength_nm, [1549.999; 1550.000; 1550.001]);
end

function testCloseTargetsWarnInsteadOfError(testCase)
csvPath = tempname + ".csv";
cleanup = onCleanup(@() iDeleteIfExists(csvPath));

T = table(["F"; "F"], [0; 1], [100; 104], [132; 132], [0; 0], [5; 10], ...
    'VariableNames', {'letter', 'index', 'x_pixel', 'y_pixel', 'delta_lambda_nm', 'eta_min_to_this_spot'});
writetable(T, csvPath);

verifyWarning(testCase, @() exp_preprocess_zju_coords(csvPath, 4), ...
    "opa_exp:exp_preprocess_zju_coords:CloseTargets");
end

function testWavelengthRunnerWithMockSavesManifest(testCase)
cfg = iFastMockConfig();
outputRoot = tempname;
cleanup = onCleanup(@() iRemoveDirIfExists(outputRoot));
[coords, ~] = exp_preprocess_zju_coords("", cfg.measure.ccdSpotSize);
selectedWave = coords.wavelength_nm_0p001(1);
expected = coords(coords.wavelength_nm_0p001 == selectedWave, :);

runResult = exp_run_wavelength_calibration("5PPS", selectedWave, cfg, ...
    'OutputRoot', outputRoot);

verifyEqual(testCase, runResult.targetCount, height(expected));
verifyEqual(testCase, string(runResult.targets.point_id), string(expected.point_id));
verifyEqual(testCase, runResult.matchedWavelengthNm, selectedWave);
verifyTrue(testCase, contains(runResult.outputDir, "lambda_" + strrep(compose("%.3f", selectedWave), ".", "p") + "nm"));
verifyTrue(testCase, isfolder(runResult.outputDir));
verifyTrue(testCase, isfile(fullfile(runResult.outputDir, "run_manifest.csv")));
verifyTrue(testCase, isfile(fullfile(runResult.outputDir, "wavelength_run_result.mat")));
verifyTrue(testCase, all([runResult.pointResults.fomCurveSaved]));

manifest = readtable(fullfile(runResult.outputDir, "run_manifest.csv"), 'TextType', 'string');
verifyEqual(testCase, height(manifest), height(expected));
verifyEqual(testCase, manifest.x_pixel, expected.x_pixel);
verifyEqual(testCase, manifest.y_pixel, expected.y_pixel);
verifyEqual(testCase, manifest.point_id, string(expected.point_id));
verifyEqual(testCase, manifest.status, "completed");
verifyTrue(testCase, all(isfile(manifest.result_path)));
verifyTrue(testCase, all(isfile(manifest.fom_curve_path)));
verifyTrue(testCase, all(endsWith(manifest.fom_curve_path, "_fom_curve.png")));
end

function testWavelengthRunnerWithMockUsesCsvOrderForMultipointGroup(testCase)
cfg = iFastMockConfig();
outputRoot = tempname;
cleanup = onCleanup(@() iRemoveDirIfExists(outputRoot));
[coords, ~] = exp_preprocess_zju_coords("", cfg.measure.ccdSpotSize);
groupCounts = groupcounts(coords, "wavelength_nm_0p001");
multiGroups = groupCounts(groupCounts.GroupCount > 1, :);
verifyGreaterThan(testCase, height(multiGroups), 0);
[~, maxIdx] = max(multiGroups.GroupCount);
selectedWave = multiGroups.wavelength_nm_0p001(maxIdx);
expected = coords(coords.wavelength_nm_0p001 == selectedWave, :);

runResult = exp_run_wavelength_calibration("5PPS", selectedWave, cfg, ...
    'OutputRoot', outputRoot);

verifyEqual(testCase, runResult.targetCount, height(expected));
verifyEqual(testCase, runResult.matchedWavelengthNm, selectedWave);
verifyTrue(testCase, contains(runResult.outputDir, "lambda_" + strrep(compose("%.3f", selectedWave), ".", "p") + "nm"));
verifyEqual(testCase, runResult.targets.source_order, expected.source_order);
verifyEqual(testCase, runResult.targets.x_pixel, expected.x_pixel);

manifest = readtable(fullfile(runResult.outputDir, "run_manifest.csv"), 'TextType', 'string');
verifyEqual(testCase, height(manifest), height(expected));
verifyEqual(testCase, manifest.x_pixel, expected.x_pixel);
verifyTrue(testCase, all(manifest.status == "completed"));
verifyTrue(testCase, all(isfile(manifest.fom_curve_path)));
verifyTrue(testCase, all([runResult.pointResults.fomCurveSaved]));
end

function testQuickstartDispatchesWavelengthModeWithConfigOverride(testCase)
cfg = iFastMockConfig();
outputRoot = tempname;
cleanup = onCleanup(@() iRemoveDirIfExists(outputRoot));
[coords, ~] = exp_preprocess_zju_coords("", cfg.measure.ccdSpotSize);
selectedWave = coords.wavelength_nm_0p001(1);
expected = coords(coords.wavelength_nm_0p001 == selectedWave, :);

runResult = exp_quickstart("5PPS", selectedWave, cfg, ...
    'OutputRoot', outputRoot);

verifyEqual(testCase, runResult.targetCount, height(expected));
verifyEqual(testCase, string(runResult.targets.point_id), string(expected.point_id));
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

function iRemoveDirIfExists(path)
if isfolder(path)
    rmdir(path, 's');
end
end

function iDeleteIfExists(path)
if isfile(path)
    delete(path);
end
end

function wavelengthNm = iRawWavelengthNm(raw)
vars = string(raw.Properties.VariableNames);
if ismember("wavelength_nm", vars)
    wavelengthNm = double(raw.wavelength_nm);
else
    wavelengthNm = 1550 + double(raw.delta_lambda_nm);
end
end

function missingWave = iFindMissingWavelength(existingWaves)
existingWaves = unique(existingWaves);
candidates = 1530:0.001:1570;
isTaken = ismember(round(candidates, 3), existingWaves);
missingWave = candidates(find(~isTaken, 1, "first"));
end
