%% BuildMasterTable.m
% Walks ReRun/<cohort>/<subject>/<subject>.xls (CWT) and <subject>_FFT.xls
% (STFT) and assembles a master workbook with sheets Rats, Patients, Mice,
% and Idealized, matching the lab's previous layout. In each per-subject
% file, Sheet 1 = OD and Sheet 2 = OS, one row of [PSD, Frequency].
% Values are nV^2/Hz (corrected, energy-calibrated pipeline).

clear;

% ============================ CONFIG ==================================
rootPath = '';   % ReRun path; leave '' to be prompted
if isempty(rootPath)
    rootPath = uigetdir(pwd, 'Select the ReRun directory');
    if isequal(rootPath,0), error('No directory selected.'); end
end
outFile = fullfile(rootPath, 'MasterTable.xlsx');
if isfile(outFile)
    delete(outFile);   % start fresh so no stale rows/duplicate notes remain
end
% ======================================================================

% master sheet  ->  cohort folders that feed it
groupNames   = {'Rats',                'Patients',                        'Mice',                       'Idealized'};
groupCohorts = { {'BN rats','RCS rats'} {'Normal patients','Diabetic patients'} {'REN Mice','TEN mice','WT mice'} {'Idealized'} };

realHdr1 = {'', 'Wavelet Transform (WT)','','','', 'Fast Fourier Transform (FFT)','','',''};
realHdr2 = {'Subject Name', ...
            'OD PSD (nV^2/Hz)','OD Frequency (Hz)','OS PSD (nV^2/Hz)','OS Frequency (Hz)', ...
            'OD PSD (nV^2/Hz)','OD Frequency (Hz)','OS PSD (nV^2/Hz)','OS Frequency (Hz)'};
idealHdr1 = {'', 'Wavelet Transform (WT)','', 'FFT 10 Hz','', 'FFT 60 Hz',''};
idealHdr2 = {'Subject Name','PSD (nV^2/Hz)','Frequency (Hz)', ...
             'PSD (nV^2/Hz)','Frequency (Hz)','PSD (nV^2/Hz)','Frequency (Hz)'};

for g = 1:numel(groupNames)
    gName    = groupNames{g};
    cohorts  = groupCohorts{g};
    isIdeal  = strcmpi(gName, 'Idealized');

    if isIdeal, C = idealHdr1; C = [C; idealHdr2]; else, C = realHdr1; C = [C; realHdr2]; end %#ok<AGROW>

    nFound = 0;
    for ci = 1:numel(cohorts)
        cohortPath = fullfile(rootPath, cohorts{ci});
        if ~isfolder(cohortPath)
            fprintf('  (missing cohort folder: %s)\n', cohorts{ci});
            continue;
        end
        subjects = listSubfolders(cohortPath);
        subjects = natSort(subjects);

        for si = 1:numel(subjects)
            subj     = subjects{si};
            subjPath = fullfile(cohortPath, subj);
            wtFile   = fullfile(subjPath, [subj '.xls']);
            fftFile  = fullfile(subjPath, [subj '_FFT.xls']);

            [wt,  nWT ] = readEyeVals(wtFile);          % CWT: no resolution ambiguity

            if isIdeal
                % Idealized: two STFT runs, 10 Hz and 60 Hz, shown side by side.
                [f10, ~, note10] = readFFTVals(fftFile, 10);
                [f60, ~, note60] = readFFTVals(fftFile, 60);
                if ~isempty(note10), fprintf('   %-16s : FFT 10Hz %s\n', subj, note10); end
                if ~isempty(note60), fprintf('   %-16s : FFT 60Hz %s\n', subj, note60); end
            else
                [fft, nFFT, fftNote] = readFFTVals(fftFile, 60);   % 60 Hz for real data
                if ~isempty(fftNote)
                    fprintf('   %-16s : FFT %s\n', subj, fftNote);
                end
            end

            % Report subjects with repeat CWT runs.
            if nWT > 2
                fprintf('   %-16s : %d WT units -> using first run only (OD, OS)\n', subj, nWT);
            end

            if isIdeal
                row = {subj, wt(1,1), wt(1,2), f10(1,1), f10(1,2), f60(1,1), f60(1,2)};
            else
                row = {subj, wt(1,1), wt(1,2), wt(2,1), wt(2,2), ...
                             fft(1,1), fft(1,2), fft(2,1), fft(2,2)};
            end
            C = [C; row]; %#ok<AGROW>
            nFound = nFound + 1;
        end
    end

    % cohort-specific notes at the bottom
    if strcmpi(gName,'Rats')
        C = [C; repmat({''},1,size(C,2))]; %#ok<AGROW>
        C = [C; [{'NOTE: RCS rats have OS treated with AAV vector, OD used as control'}, repmat({''},1,size(C,2)-1)]]; %#ok<AGROW>
    elseif strcmpi(gName,'Patients')
        C = [C; repmat({''},1,size(C,2))]; %#ok<AGROW>
        C = [C; [{'NOTE: Diabetic patient eyes not specified; first sheet assumed OD, second OS'}, repmat({''},1,size(C,2)-1)]]; %#ok<AGROW>
    end

    writecell(C, outFile, 'Sheet', gName);
    fprintf('Sheet %-10s : %d subjects\n', gName, nFound);
end

fprintf('\nMaster table written to %s\n', outFile);
fprintf('(If an empty "Sheet1" remains, delete it in Excel.)\n');


% ======================= helper functions ============================
function names = listSubfolders(p)
    d = dir(p);
    names = {};
    for i = 1:numel(d)
        if d(i).isdir && ~ismember(d(i).name, {'.','..'})
            names{end+1} = d(i).name; %#ok<AGROW>
        end
    end
end

function [vals, nUnits] = readEyeVals(xlsFile)
% Returns 2x2 [PSD Freq; PSD Freq] for (OD; OS), NaN where missing, plus a
% count of how many eye/run units were present (for the multi-run report).
%
% Two storage layouts are auto-detected and both reduced to the FIRST run:
%   ROW layout (diabetics): one file has both eyes (and any repeats) stacked
%     as rows in a single sheet -> Row 1 = OD1, Row 2 = OS1, Row 3 = OD2 ...
%     Take rows 1 and 2.
%   SHEET layout (rodents / normal patients): Sheet 1 = OD (first run),
%     Sheet 2 = OS (first run), Sheets 3,4,... = later runs (ignored).
    vals = nan(2,2);
    nUnits = 0;
    if ~isfile(xlsFile), return; end
    try, sn = sheetnames(xlsFile); catch, return; end
    if isempty(sn), return; end

    m1 = safeRead(xlsFile, 1);
    if isempty(m1), return; end

    if size(m1,1) >= 2
        % ROW layout: both eyes live in sheet 1 (rows). First run = rows 1,2.
        vals(1,:) = m1(1,1:2);          % OD
        vals(2,:) = m1(2,1:2);          % OS
        nUnits = size(m1,1);            % total rows = eyes x runs
    else
        % SHEET layout: OD = sheet 1, OS = sheet 2, extra sheets = later runs.
        vals(1,:) = m1(1,1:2);          % OD, first run
        if numel(sn) >= 2
            m2 = safeRead(xlsFile, 2);
            if ~isempty(m2), vals(2,:) = m2(1,1:2); end   % OS, first run
        end
        nUnits = numel(sn);             % total sheets = eyes x runs
    end
end

function [vals, nUnits, note] = readFFTVals(xlsFile, canonRes)
% Like readEyeVals, but for FFT files whose sheets are named
% 'FreqRes_<res>_#<k>'. Selects the run at canonRes Hz: #1 = OD, #2 = OS
% (idealized signals have only #1). If that resolution is absent it falls
% back to the generic reader and flags it, so a wrong-resolution number
% never enters the table silently.
    if nargin < 2, canonRes = 60; end
    vals = nan(2,2);
    nUnits = 0;
    note = '';
    if ~isfile(xlsFile), return; end
    try, sn = sheetnames(xlsFile); catch, return; end
    if isempty(sn), return; end
    nUnits = numel(sn);

    odName = sprintf('FreqRes_%d_#1', canonRes);
    osName = sprintf('FreqRes_%d_#2', canonRes);
    hasOD = any(strcmp(sn, odName));
    hasOS = any(strcmp(sn, osName));

    if hasOD || hasOS
        m1 = [];
        if hasOD
            m1 = safeRead(xlsFile, odName);
            if ~isempty(m1), vals(1,:) = m1(1,1:2); end     % OD = row 1 of #1
        end
        if hasOS
            m2 = safeRead(xlsFile, osName);
            if ~isempty(m2), vals(2,:) = m2(1,1:2); end     % OS = row 1 of #2 (sheet layout)
        elseif ~isempty(m1) && size(m1,1) >= 2
            % ROW layout (diabetics): OD and OS are stacked as rows in the
            % single #1 sheet. Row 1 = OD (taken above), Row 2 = OS.
            vals(2,:) = m1(2,1:2);
        end
        % Stray sheets at other resolutions are harmless -- selection is by
        % name, so they are simply not read. No note needed.
    else
        % Requested resolution absent -> fall back, but flag it.
        [vals, nUnits] = readEyeVals(xlsFile);
        note = sprintf('NO %d Hz run found (sheets: %s) -> used first sheets, VERIFY', ...
                       canonRes, strjoin(sn, ', '));
    end
end


function m = safeRead(f, s)
    m = [];
    try
        m = readmatrix(f, 'Sheet', s);
        if ~isempty(m)
            m = m(~all(isnan(m),2), :);     % drop fully-empty rows
        end
    catch
    end
end

function s = natSort(names)
% Natural sort: BN1 < BN2 < ... < BN10 (zero-pad digit runs for the key).
    if isempty(names), s = names; return; end
    keys = cell(size(names));
    for i = 1:numel(names)
        keys{i} = regexprep(names{i}, '\d+', '${sprintf(''%010d'',str2double($0))}');
    end
    [~, ord] = sort(keys);
    s = names(ord);
end
