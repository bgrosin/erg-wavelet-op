function GenerateSyntheticValidation(referenceSource, outputPath)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function GenerateSyntheticValidation by bgrosin
%
% 2 September 2026
%
% Generates the synthetic OP validation dataset described in the Methods:
% OP-like Gabor bursts of known frequency embedded in AR surrogates of
% each cohort's own pre-stimulus noise, at cohort-matched amplitude.
%
% Family A - single bursts (sigma = 12 ms, centred 30 ms post-stimulus) at
%            80:5:115 Hz, 10 noise realizations per frequency per cohort.
% Family B - paired bursts (sigma = 6 ms, centred 25 and 40 ms, i.e. 15 ms
%            apart) at pairs 80/95, 90/105, 95/110 and 100/115 Hz,
%            10 realizations per pair per cohort.
%
% The cohort noise models can be obtained from either of two sources:
%   (a) a folder containing the reference recordings listed in the cohort
%       table below (one representative recording per cohort), from which
%       the parameters are derived; or
%   (b) the parameter file SyntheticNoiseParameters.mat distributed with
%       this package, which contains only aggregate, non-identifiable
%       parameters (AR coefficients, noise SD, OP amplitude) so that the
%       dataset can be regenerated without access to any recordings.
%
% Output files are tab-delimited [time_ms value_nV] text files in the same
% format as the biological recordings, written to
% <outputPath>/FamilyA/<cohort>/ and <outputPath>/FamilyB/<cohort>/.
% Seeds are fixed per (cohort, family, frequency, realization), so the
% generated dataset is exactly reproducible. Requires MATLAB R2026a with
% the Signal Processing Toolbox.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% Takes two parameters
% I  - referenceSource - EITHER a folder with the reference recordings OR
%                        the full path of SyntheticNoiseParameters.mat
% II - outputPath      - folder in which FamilyA/ and FamilyB/ are created
%
% Returns no parameters
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%Constants definition%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

NOTCH_FREQUENCY_HZ    = 60;
NOTCH_Q               = 35;
HIGHPASS_FREQUENCY_HZ = 60;
OP_WINDOW_MS          = [15 80];
AR_ORDER              = 8;
N_REALIZATIONS        = 10;

FAMILY_A_FREQS_HZ     = 80:5:115;
FAMILY_A_SIGMA_MS     = 12;
FAMILY_A_CENTER_MS    = 30;

FAMILY_B_PAIRS_HZ     = [80 95; 90 105; 95 110; 100 115];
FAMILY_B_SIGMA_MS     = 6;
FAMILY_B_CENTERS_MS   = [25 40];

cohortNames = {'BN', 'RCS', 'WT', 'REN', 'TEN', 'Control', 'Diabetic'};
cohortFiles = {'BN_rat_1.txt', 'RCS_rat_1.txt', 'WT_mouse_1.txt', ...
               'Ren_mouse_1.txt', 'Ten_mouse_1.txt', ...
               'Normal_human_control_1.txt', 'Diabetic5_-_UE.txt'};
cohortRates = [2000 2000 2000 2000 2000 1000 1000];

%%%%%%%%%%%%%%%%%End of constants definitions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || isempty(referenceSource)
    referenceSource = uigetdir(pwd, 'Choose the reference folder (or cancel to pick the parameter file)');
    if isequal(referenceSource, 0)
        [f, p] = uigetfile('*.mat', 'Choose SyntheticNoiseParameters.mat');
        referenceSource = fullfile(p, f);
    end
end
if nargin < 2 || isempty(outputPath)
    outputPath = uigetdir(pwd, 'Choose output folder for the synthetic dataset');
end

%%%%%%%%%%Assemble the per-cohort noise models from either source
theParams = AssembleCohortParameters(referenceSource, cohortNames, ...
              cohortFiles, cohortRates, AR_ORDER, NOTCH_FREQUENCY_HZ, ...
              NOTCH_Q, HIGHPASS_FREQUENCY_HZ, OP_WINDOW_MS);

%%%%%%%%%%Generate both families for every cohort
nGenerated = 0;
for cohortIdx = 1:numel(theParams)

    theCohort = theParams(cohortIdx);
    theAxis   = theCohort.timeAxisMs;

    familyAPath = fullfile(outputPath, 'FamilyA', theCohort.name);
    if ~exist(familyAPath, 'dir'); mkdir(familyAPath); end
    for theFrequency = FAMILY_A_FREQS_HZ
        for r = 1:N_REALIZATIONS
            rng(cohortIdx*1e6 + 1e5 + theFrequency*100 + r, 'twister');
            theNoise = GenerateARNoise(theCohort.arCoefs, ...
                                       theCohort.preStd, numel(theAxis));
            theBurst = GaborBurst(theAxis, theFrequency, ...
                                  FAMILY_A_CENTER_MS, FAMILY_A_SIGMA_MS, ...
                                  theCohort.opAmplitude);
            theFileName = sprintf('%s_A_inj%dHz_r%02d.txt', ...
                                  theCohort.name, theFrequency, r);
            WriteSignalFile(fullfile(familyAPath, theFileName), theAxis, ...
                            theNoise + theBurst);
            nGenerated = nGenerated + 1;
        end
    end

    familyBPath = fullfile(outputPath, 'FamilyB', theCohort.name);
    if ~exist(familyBPath, 'dir'); mkdir(familyBPath); end
    for pairIdx = 1:size(FAMILY_B_PAIRS_HZ, 1)
        f1 = FAMILY_B_PAIRS_HZ(pairIdx, 1);
        f2 = FAMILY_B_PAIRS_HZ(pairIdx, 2);
        for r = 1:N_REALIZATIONS
            rng(cohortIdx*1e6 + 2e5 + f1*1000 + f2*10 + r, 'twister');
            theNoise = GenerateARNoise(theCohort.arCoefs, ...
                                       theCohort.preStd, numel(theAxis));
            theBursts = GaborBurst(theAxis, f1, FAMILY_B_CENTERS_MS(1), ...
                                   FAMILY_B_SIGMA_MS, theCohort.opAmplitude) + ...
                        GaborBurst(theAxis, f2, FAMILY_B_CENTERS_MS(2), ...
                                   FAMILY_B_SIGMA_MS, theCohort.opAmplitude);
            theFileName = sprintf('%s_B_%d-%dHz_r%02d.txt', ...
                                  theCohort.name, f1, f2, r);
            WriteSignalFile(fullfile(familyBPath, theFileName), theAxis, ...
                            theNoise + theBursts);
            nGenerated = nGenerated + 1;
        end
    end

    fprintf('Cohort %-9s done (fs = %d Hz, OP p-p = %.0f nV)\n', ...
            theCohort.name, theCohort.fs, theCohort.opAmplitude);
end

fprintf('Generated %d synthetic signals in %s\n', nGenerated, outputPath);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Local functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function theParams = AssembleCohortParameters(referenceSource, ...
    cohortNames, cohortFiles, cohortRates, arOrder, notchHz, notchQ, ...
    highPassHz, opWindowMs)
% Build the per-cohort noise-model struct array from either a parameter
% file (.mat) or a folder of reference recordings.

[~, ~, theExtension] = fileparts(referenceSource);

if strcmpi(theExtension, '.mat')
    %%%%%%%%%%Parameter-file mode - no recordings required
    S = load(referenceSource);
    P = S.P;
    for k = 1:numel(P.fs)
        theParams(k).name        = char(P.names{k});                     %#ok<*AGROW>
        theParams(k).fs          = P.fs(k);
        theParams(k).timeAxisMs  = P.t0_ms(k) + ...
                                   (0:P.nSamples(k)-1)' * 1000 / P.fs(k);
        theParams(k).arCoefs     = P.arCoefs{k}(:);
        theParams(k).preStd      = P.preStd(k);
        theParams(k).opAmplitude = P.opAmplitude(k);
    end
else
    %%%%%%%%%%Recording mode - derive the parameters per cohort
    for k = 1:numel(cohortNames)
        theData   = readmatrix(fullfile(referenceSource, cohortFiles{k}));
        theAxis   = theData(:, 1);
        theSignal = theData(:, 2) - mean(theData(:, 2));

        preStim   = theSignal(theAxis < 0);
        theOrder  = min(arOrder, floor(numel(preStim) / 2) - 1);

        filtered  = PreprocessOP(theSignal, cohortRates(k), notchHz, ...
                                 notchQ, highPassHz);
        opWindow  = theAxis >= opWindowMs(1) & theAxis <= opWindowMs(2);

        theParams(k).name        = cohortNames{k};
        theParams(k).fs          = cohortRates(k);
        theParams(k).timeAxisMs  = theAxis(:);
        theParams(k).arCoefs     = FitARModel(preStim, theOrder);
        theParams(k).preStd      = std(preStim);
        theParams(k).opAmplitude = max(filtered(opWindow)) - ...
                                   min(filtered(opWindow));
    end
end
end


function theCoefs = FitARModel(theSegment, theOrder)
theSegment = theSegment(:);
n = numel(theSegment);
X = zeros(n - theOrder, theOrder);
for k = 1:theOrder
    X(:, k) = theSegment(theOrder + 1 - k : n - k);
end
theCoefs = X \ theSegment(theOrder + 1 : n);
end


function theNoise = GenerateARNoise(theCoefs, theStd, nSamples)
theOrder = numel(theCoefs);
z = zeros(nSamples + theOrder, 1);
e = randn(nSamples + theOrder, 1) * theStd;
for i = theOrder + 1 : nSamples + theOrder
    z(i) = theCoefs.' * z(i-1 : -1 : i-theOrder) + e(i);
end
z = z(theOrder + 1 : end);
theNoise = z * theStd / (std(z) + 1e-12);
end


function theBurst = GaborBurst(theAxisMs, theFrequencyHz, theCenterMs, ...
                               theSigmaMs, theAmplitudePP)
theAxisMs = theAxisMs(:);
theEnvelope = exp(-0.5 * ((theAxisMs - theCenterMs) / theSigmaMs).^2);
theCarrier  = sin(2 * pi * theFrequencyHz * theAxisMs / 1000);
theBurst    = theEnvelope .* theCarrier;
theBurst    = theBurst * (theAmplitudePP / 2) / (max(abs(theBurst)) + 1e-12);
end


function theFiltered = PreprocessOP(theSignal, theRateHz, theNotchHz, ...
                                    theNotchQ, theHighPassHz)
w0 = theNotchHz / (theRateHz / 2);
[bN, aN] = iirnotch(w0, w0 / theNotchQ);
theFiltered = filtfilt(bN, aN, theSignal(:));
[bH, aH] = butter(4, theHighPassHz / (theRateHz / 2), 'high');
theFiltered = filtfilt(bH, aH, theFiltered);
end


function WriteSignalFile(theFileName, theAxisMs, theSignal)
fid = fopen(theFileName, 'w');
for i = 1:numel(theAxisMs)
    fprintf(fid, '%g\t%.9g\r\n', theAxisMs(i), theSignal(i));
end
fclose(fid);
end
