function GenerateSNRSweep(referenceSource, outputPath)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function GenerateSNRSweep by bgrosin
%
% 2 September 2026
%
% Generates the signal-to-noise ratio series described in the Methods:
% single OP-like Gabor bursts (sigma = 12 ms, centred 30 ms post-stimulus)
% at 80:5:115 Hz embedded in AR(8) surrogates of the diabetic-patient
% pre-stimulus noise at a fixed sampling rate of 1000 Hz, with burst
% amplitude scaled to yield SNRs of 1, 2, 3.5, 6 and 10. SNR is defined,
% as in the cohort table, as the RMS of the filtered burst within the OP
% window divided by the RMS of the filtered pre-stimulus noise; amplitude
% scaling is calibrated empirically against this definition.
%
% Ten noise realizations per frequency per SNR level (400 signals) are
% written to <outputPath>/SNR_<level>/ in the recording file format, one
% folder per SNR level, so that the standard batch driver
% (RunOPAnalysisOnAllDataInFolder) can be applied per folder unchanged.
%
% Seeds are fixed per (SNR, frequency, realization), so the generated
% dataset is exactly reproducible. Requires MATLAB R2026a with the Signal
% Processing Toolbox.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% Takes two parameters
% I  - referenceSource - EITHER a folder containing the diabetic reference
%                        recording (Diabetic5_-_UE.txt; not distributed) OR
%                        the full path of SyntheticNoiseParameters.mat
%                        distributed with this package
% II - outputPath      - folder in which the SNR_* folders are created
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

REFERENCE_FILE        = 'Diabetic5_-_UE.txt';
SAMPLING_RATE_HZ      = 1000;
SNR_TARGETS           = [1 2 3.5 6 10];
BURST_FREQS_HZ        = 80:5:115;
BURST_SIGMA_MS        = 12;
BURST_CENTER_MS       = 30;

%%%%%%%%%%%%%%%%%End of constants definitions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 1 || isempty(referenceSource)
    referenceSource = uigetdir(pwd, 'Choose the reference folder (or cancel to pick the parameter file)');
    if isequal(referenceSource, 0)
        [f, p] = uigetfile('*.mat', 'Choose SyntheticNoiseParameters.mat');
        referenceSource = fullfile(p, f);
    end
end
if nargin < 2 || isempty(outputPath)
    outputPath = uigetdir(pwd, 'Choose output folder for the SNR sweep');
end

%%%%%%%%%%Obtain the diabetic noise model from either source
[~, ~, theExtension] = fileparts(referenceSource);
if strcmpi(theExtension, '.mat')
    S = load(referenceSource);
    P = S.P;
    k = find(strcmp(cellfun(@char, P.names, 'UniformOutput', false), ...
             'Diabetic'), 1);
    theAxis       = P.t0_ms(k) + (0:P.nSamples(k)-1)' * 1000 / P.fs(k);
    arCoefs       = P.arCoefs{k}(:);
    preStd        = P.preStd(k);
    noiseRMS      = P.filteredNoiseRMS(k);
    theAmplitude0 = P.opAmplitude(k);
else
    theData   = readmatrix(fullfile(referenceSource, REFERENCE_FILE));
    theAxis   = theData(:, 1);
    theSignal = theData(:, 2) - mean(theData(:, 2));

    preStim   = theSignal(theAxis < 0);
    theOrder  = min(AR_ORDER, floor(numel(preStim) / 2) - 1);
    arCoefs   = FitARModel(preStim, theOrder);
    preStd    = std(preStim);

    filtered  = PreprocessOP(theSignal, SAMPLING_RATE_HZ, NOTCH_FREQUENCY_HZ, ...
                             NOTCH_Q, HIGHPASS_FREQUENCY_HZ);
    noiseRMS  = std(filtered(theAxis < 0));
    opWindow  = theAxis >= OP_WINDOW_MS(1) & theAxis <= OP_WINDOW_MS(2);
    theAmplitude0 = max(filtered(opWindow)) - min(filtered(opWindow));
end
opWindow = theAxis >= OP_WINDOW_MS(1) & theAxis <= OP_WINDOW_MS(2);

%%%%%%%%%%Calibrate the base SNR of a burst at the reference amplitude
theBurst0     = GaborBurst(theAxis, 100, BURST_CENTER_MS, BURST_SIGMA_MS, ...
                           theAmplitude0);
theBurst0Filt = PreprocessOP(theBurst0, SAMPLING_RATE_HZ, ...
                             NOTCH_FREQUENCY_HZ, NOTCH_Q, ...
                             HIGHPASS_FREQUENCY_HZ);
baseSNR = std(theBurst0Filt(opWindow)) / noiseRMS;
fprintf('Reference: noise RMS = %.1f, OP p-p = %.0f, base burst SNR = %.2f\n', ...
        noiseRMS, theAmplitude0, baseSNR);

%%%%%%%%%%Generate the sweep
nGenerated = 0;
for snrIdx = 1:numel(SNR_TARGETS)

    theTarget = SNR_TARGETS(snrIdx);
    theTag = sprintf('SNR_%g', theTarget);
    theTag = strrep(theTag, '.', 'p');
    theLevelPath = fullfile(outputPath, theTag);
    if ~exist(theLevelPath, 'dir'); mkdir(theLevelPath); end

    theAmplitude = theAmplitude0 * theTarget / baseSNR;

    for theFrequency = BURST_FREQS_HZ
        for r = 1:N_REALIZATIONS
            rng(3e6 + snrIdx*1e5 + theFrequency*100 + r, 'twister');
            theNoise = GenerateARNoise(arCoefs, preStd, numel(theAxis));
            theBurst = GaborBurst(theAxis, theFrequency, BURST_CENTER_MS, ...
                                  BURST_SIGMA_MS, theAmplitude);
            theFileName = sprintf('%s_inj%dHz_r%02d.txt', theTag, ...
                                  theFrequency, r);
            WriteSignalFile(fullfile(theLevelPath, theFileName), theAxis, ...
                            theNoise + theBurst);
            nGenerated = nGenerated + 1;
        end
    end
    fprintf('SNR %g done\n', theTarget);
end

fprintf('Generated %d signals in %s\n', nGenerated, outputPath);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Local functions (identical to GenerateSyntheticValidation)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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
