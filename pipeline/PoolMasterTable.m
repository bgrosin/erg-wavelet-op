%% PoolMasterTable.m
% Reads MasterTable.xlsx and creates per-group column vectors for stats,
% with CWT (wavelet) and STFT (FFT) kept as separate, explicitly-named
% variables. NaN entries (missing eyes) are dropped.
%
% For each pooled group (OD + OS combined):
%   <Group>_CWT_PSD    <Group>_CWT_Freq
%   <Group>_STFT_PSD   <Group>_STFT_Freq
% Groups pooled: Control, Diabetic, WTmice, RENmice, TENmice, BN.
%
% RCS is NOT pooled: OS = AAV-treated, OD = control are different
% experimental conditions, so it is split into:
%   RCScontrol_CWT_PSD / _CWT_Freq / _STFT_PSD / _STFT_Freq   (OD)
%   RCStreated_CWT_PSD / _CWT_Freq / _STFT_PSD / _STFT_Freq   (OS)

clear; clc;

masterFile = '';   % leave '' to be prompted
if isempty(masterFile)
    [f,p] = uigetfile({'*.xlsx';'*.xls'}, 'Select MasterTable.xlsx');
    if isequal(f,0), error('No file selected.'); end
    masterFile = fullfile(p,f);
end

% varPrefix | sheet | name-prefix | mode ('pool' or 'split')
groups = {
    'Control'   'Patients'   'Norm'      'pool'
    'Diabetic'  'Patients'   'Diabetic'  'pool'
    'WTmice'    'Mice'       'WT'        'pool'
    'RENmice'   'Mice'       'REN'       'pool'
    'TENmice'   'Mice'       'TEN'       'pool'
    'BN'        'Rats'       'BN'        'pool'
    'RCS'       'Rats'       'RCS'       'split'
};

% column map (real-world sheets):
%  CWT:  OD PSD=2  OD F=3  OS PSD=4  OS F=5
%  STFT: OD PSD=6  OD F=7  OS PSD=8  OS F=9

sheetsNeeded = unique(groups(:,2));
raw = struct();
for i = 1:numel(sheetsNeeded)
    raw.(sheetsNeeded{i}) = readcell(masterFile, 'Sheet', sheetsNeeded{i});
end

fprintf('Pooled from %s\n\n', masterFile);

for gi = 1:size(groups,1)
    vp   = groups{gi,1};
    C    = raw.(groups{gi,2});
    pref = groups{gi,3};
    mode = groups{gi,4};

    idx = [];
    for r = 3:size(C,1)                      % skip the two header rows
        name = C{r,1};
        if (ischar(name) || isstring(name)) && startsWith(string(name), pref)
            idx(end+1) = r; %#ok<AGROW>
        end
    end

    if strcmp(mode,'pool')
        assignEye(vp,          C, idx, [2 4],[3 5],[6 8],[7 9]);   % OD+OS pooled
        n = numel(poolCols(C, idx, [2 4]));
        fprintf('%-12s pooled  : n = %d (OD+OS)\n', vp, n);
    else  % split RCS into control (OD) and treated (OS)
        assignEye('RCScontrol', C, idx, 2, 3, 6, 7);              % OD
        assignEye('RCStreated', C, idx, 4, 5, 8, 9);              % OS
        nc = numel(poolCols(C, idx, 2));
        nt = numel(poolCols(C, idx, 4));
        fprintf('%-12s split   : control(OD) n=%d, treated(OS) n=%d\n', vp, nc, nt);
    end
end

fprintf(['\nVariables created: <group>_CWT_PSD, <group>_CWT_Freq,\n' ...
         '<group>_STFT_PSD, <group>_STFT_Freq.\n' ...
         'RCS is split into RCScontrol_* (OD) and RCStreated_* (OS).\n']);


function assignEye(prefix, C, idx, cwtP, cwtF, stftP, stftF)
    assignin('base', [prefix '_CWT_PSD'],   poolCols(C, idx, cwtP));
    assignin('base', [prefix '_CWT_Freq'],  poolCols(C, idx, cwtF));
    assignin('base', [prefix '_STFT_PSD'],  poolCols(C, idx, stftP));
    assignin('base', [prefix '_STFT_Freq'], poolCols(C, idx, stftF));
end

function v = poolCols(C, idx, cols)
% Collect given columns from given rows into one column vector, dropping
% empties/NaN so only real measurements remain.
    v = [];
    for r = idx(:).'
        for c = cols
            x = C{r,c};
            if isnumeric(x) && isscalar(x) && ~isnan(x)
                v(end+1,1) = x; %#ok<AGROW>
            end
        end
    end
end
