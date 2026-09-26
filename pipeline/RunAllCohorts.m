%% RunAllCohorts.m
% Batch-run OP (wavelet) and FFT (STFT) analyses over every cohort folder
% in a ReRun-style directory, unattended. Replaces the interactive
% RunOPAnalysisOnAllDataInFolder / RunFFTAnalysisOnAllDataInFolder.
%
% For each cohort subfolder it processes every .txt file (found directly in
% the folder OR one level down in subfolders), runs both analyses, writes
% one workbook per cohort per method (<cohort>_OP.xlsx / <cohort>_FFT.xlsx)
% with one sheet per subject file, and optionally saves the figures.
%
% Filter settings: the folder named "Idealized" uses notch = 0, highpass = 0
% (idealized display path); every other cohort uses 60 / 60.
%
% Sampling rate is auto-derived per file inside the analysis functions, so
% rodents (2000 Hz) and humans (1000 Hz) are handled automatically, and the
% STFT_CLIM branch in CreateFFTFigure3 selects the right colour scale.
%
% Requires on path: RunAutomatedOPAnalysis, RunAutomatedFFTAnalysis,
%   ConvertAlkiesERGFile2, CreateCWTFigure6, CreateFFTFigure3,
%   ApplyTimeTicks, getWaveletScales, getWaveletPSDConstant,
%   CalibrateWaveletPSD.

clear; close all hidden;

% ============================ CONFIG ==================================
% Leave rootPath = '' to be prompted, or hard-code the ReRun path, e.g.
% rootPath = 'C:\Users\...\OP Paper\Final Analysis\ReRun';
rootPath = '';

saveFigures = true;    % set false to skip figure export (much faster)
% ======================================================================

if isempty(rootPath)
    rootPath = uigetdir(pwd, 'Select the ReRun directory');
    if isequal(rootPath, 0), error('No directory selected.'); end
end

% ---- discover cohort folders (immediate subfolders of rootPath) --------
d = dir(rootPath);
cohortNames = {};
for i = 1:numel(d)
    if d(i).isdir && ~ismember(d(i).name, {'.','..'})
        cohortNames{end+1} = d(i).name; %#ok<SAGROW>
    end
end
if isempty(cohortNames)
    error('No cohort subfolders found in %s', rootPath);
end

% ---- show the plan before running -------------------------------------
fprintf('\nRoot: %s\n', rootPath);
fprintf('Cohorts found and filter settings:\n');
for c = 1:numel(cohortNames)
    isIdeal = contains(cohortNames{c}, 'ideal', 'IgnoreCase', true);
    if isIdeal, nf = 0; hf = 0; else, nf = 60; hf = 60; end
    fprintf('  %-20s notch=%d  highpass=%d\n', cohortNames{c}, nf, hf);
end
fprintf('\n');

logLines = {};

% ============================ MAIN LOOP ===============================
for c = 1:numel(cohortNames)
    cohortName = cohortNames{c};
    cohortPath = fullfile(rootPath, cohortName);

    isIdeal = contains(cohortName, 'ideal', 'IgnoreCase', true);
    if isIdeal, notchHz = 0; highpassHz = 0; else, notchHz = 60; highpassHz = 60; end

    txtFiles = collectTxtFiles(cohortPath);
    if isempty(txtFiles)
        logLines{end+1} = sprintf('SKIP  %-20s : no .txt files found', cohortName); %#ok<SAGROW>
        continue;
    end

    fprintf('==== %s : %d file(s), notch=%d highpass=%d ====\n', ...
            cohortName, numel(txtFiles), notchHz, highpassHz);

    opXls  = fullfile(cohortPath, sprintf('%s_OP.xlsx',  cohortName));
    fftXls = fullfile(cohortPath, sprintf('%s_FFT.xlsx', cohortName));

    for k = 1:numel(txtFiles)
        thisFile = txtFiles{k};
        [~, baseName] = fileparts(thisFile);
        sheetName = matlab.lang.makeValidName(baseName);
        if numel(sheetName) > 31, sheetName = sheetName(1:31); end   % Excel limit

        % ---------- OP (wavelet) ----------
        try
            [FSRArray, handles] = RunAutomatedOPAnalysis(thisFile, notchHz, highpassHz);
            writematrix(FSRArray, opXls, 'Sheet', sheetName);
            if saveFigures, saveHandles(handles, cohortPath, [baseName '_OP']); end
            fprintf('  OP  ok  : %s\n', baseName);
        catch ME
            logLines{end+1} = sprintf('ERROR OP  %-20s %s : %s', cohortName, baseName, ME.message); %#ok<SAGROW>
            fprintf('  OP  ERR : %s (%s)\n', baseName, ME.message);
        end
        close all hidden;

        % ---------- FFT (STFT) ----------
        try
            [FSRArray, handles] = RunAutomatedFFTAnalysis(thisFile, notchHz, highpassHz);
            writematrix(FSRArray, fftXls, 'Sheet', sheetName);
            if saveFigures, saveHandles(handles, cohortPath, [baseName '_FFT']); end
            fprintf('  FFT ok  : %s\n', baseName);
        catch ME
            logLines{end+1} = sprintf('ERROR FFT %-20s %s : %s', cohortName, baseName, ME.message); %#ok<SAGROW>
            fprintf('  FFT ERR : %s (%s)\n', baseName, ME.message);
        end
        close all hidden;
    end
    fprintf('\n');
end

% ============================ SUMMARY =================================
fprintf('==================== SUMMARY ====================\n');
if isempty(logLines)
    fprintf('All files processed with no warnings.\n');
else
    fprintf('%s\n', logLines{:});
end

logPath = fullfile(rootPath, 'RunAllCohorts_log.txt');
fid = fopen(logPath, 'w');
if fid > 0
    if isempty(logLines)
        fprintf(fid, 'All files processed with no warnings.\n');
    else
        fprintf(fid, '%s\n', logLines{:});
    end
    fclose(fid);
    fprintf('\nLog written to %s\n', logPath);
end


% ======================= helper functions ============================
function files = collectTxtFiles(folderPath)
% .txt files directly in folderPath; if none, look one level down.
    files = {};
    dd = dir(fullfile(folderPath, '*.txt'));
    for i = 1:numel(dd)
        files{end+1} = fullfile(folderPath, dd(i).name); %#ok<AGROW>
    end
    if isempty(files)
        sub = dir(folderPath);
        for i = 1:numel(sub)
            if sub(i).isdir && ~ismember(sub(i).name, {'.','..'})
                dj = dir(fullfile(folderPath, sub(i).name, '*.txt'));
                for j = 1:numel(dj)
                    files{end+1} = fullfile(folderPath, sub(i).name, dj(j).name); %#ok<AGROW>
                end
            end
        end
    end
end

function saveHandles(handles, outDir, baseName)
% Save composite (col 1) and power-spectrum (col 2) figures per strip.
    [nFig, ~] = size(handles);
    for k = 1:nFig
        h1 = handles(k,1);  h2 = handles(k,2);
        if ishandle(h1)
            saveas(h1, fullfile(outDir, sprintf('%s_composite_%d.jpg', baseName, k)));
        end
        if ishandle(h2)
            saveas(h2, fullfile(outDir, sprintf('%s_PowerSpectrum_%d.jpg', baseName, k)));
        end
    end
end
