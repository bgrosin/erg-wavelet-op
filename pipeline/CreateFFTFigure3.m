function [maxPower, maxFrequency,  figureHandle1, figureHandle2, ZERO_PADDING, FREQUENCY_RESOLUTION_HZ] = CreateFFTFigure3(theAxis, theData, numberOfDataStrip, frequencyHz, notchFilterFrequencyHz, highPassFrequencyHz)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Function CreateFFTFigure3 by bgrosin
%   Uses a SHARP (high-Q) iirnotch for power-line removal (Q = 35),
%   matching CreateCWTFigure6. Update the driver call accordingly.
%   STFT power spectrum is a true PSD (nV^2/Hz) via pwelch (energy-
%   conserving, comparable to the calibrated wavelet PSD). Spectrogram is
%   drawn from explicit pspectrum outputs with a correct millisecond time
%   axis, and every panel uses ApplyTimeTicks for consistent, offset-free
%   time labelling (stimulus at t = 0 on real data).
%
% Returns:
% I  - maxPower     - peak STFT spectral power density (nV^2/Hz)
% II - maxFrequency - frequency of the peak
% III- figureHandle1- composite figure with spectrogram
% IV - figureHandle2- power spectrum figure
%
% Requires on path: ApplyTimeTicks.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%IMPORTANT ASSUMPTION%%%%%%%%%%%%%%%%%%%


% Check if default value needs to be set to numberOfDataStrip
if (nargin<2)
  numberOfDataStrip = 1;
end


 if (notchFilterFrequencyHz > 0 || highPassFrequencyHz > 0)
     NUM_OF_PLOTS = 3;
     LOWER_CUTOFF_FREQUENCY = 60;   % real OP data
     UPPER_TIME_CUTOFF_MS  = 150;
     % Real OP records are ~150 ms: a fine (10 Hz) resolution would need a
     % ~100 ms window that does not fit. Keep the coarse resolution here.
     FREQUENCY_RESOLUTION_HZ = 60;
 else
     NUM_OF_PLOTS = 2;
     LOWER_CUTOFF_FREQUENCY = 1;    % idealized data
     UPPER_TIME_CUTOFF_MS  = 1000;
     % Idealized signals are long, so a fine resolution is affordable.
     FREQUENCY_RESOLUTION_HZ = 10;
 end


 PLOT_COUNTER = 1;
 axFilt = [];    % filled only when NUM_OF_PLOTS == 3

%create and prepare the figure
figureHandle1 = figure('Visible','off');
set(figureHandle1, 'Color', 'w');
title('Frequency analysis figure', 'FontSize', 18, 'FontWeight', 'B');
hold on;

%plot the raw data
subplot(NUM_OF_PLOTS,1,PLOT_COUNTER);
thisDataStrip = theData(:, numberOfDataStrip);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Trim the plot in time. Remove if not needed
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

HIGHER_CUTOFF_FREQUENCY = 200;
LOWER_TIME_CUTOFF_MS = min(theAxis);
thisDataStrip = thisDataStrip((theAxis >= LOWER_TIME_CUTOFF_MS) & (theAxis <=UPPER_TIME_CUTOFF_MS));
theAxis = theAxis((theAxis >= LOWER_TIME_CUTOFF_MS) & (theAxis <=UPPER_TIME_CUTOFF_MS));
% end of addition
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


dataZeroMean = thisDataStrip - mean (thisDataStrip);
axisWidener = max(dataZeroMean) - min (dataZeroMean)/20;
dataZeroMean = smooth(dataZeroMean);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Zero padding (off by default).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ZERO_PADDING = 0;
DEFAULT_LEAKAGE = 2.8;
PADDING_FACTOR = 5;


if (ZERO_PADDING ~= 0)
    n_pad = round(length(dataZeroMean)/PADDING_FACTOR);
    dataZeroMean = padarray(dataZeroMean, n_pad, 'both');
    dx = theAxis(2) - theAxis(1);
    axis_pre = linspace(theAxis(1) - n_pad*dx, theAxis(1) - dx, n_pad);
    axis_post = linspace(theAxis(end) + dx, theAxis(end) + n_pad*dx, n_pad);
    theAxis = [axis_pre'; theAxis; axis_post'];
end

filteredData = dataZeroMean;

plot(theAxis, dataZeroMean, 'LineWidth', 3);
yMin = min (dataZeroMean) -axisWidener ;
yMax = max(dataZeroMean) + axisWidener;
ylim([yMin yMax]);
axRaw = gca;
ylabel('Nanovolts (nV)', 'FontSize', 14, 'FontWeight', 'B');
title ('Raw Data', 'FontSize', 14, 'FontWeight', 'B');
ApplyTimeTicks(axRaw, theAxis);
hold on;
PLOT_COUNTER = PLOT_COUNTER + 1;

if (NUM_OF_PLOTS == 3)
    %apply a SHARP (narrow-band, high-Q) notch filter to the line frequency if specified
    if (notchFilterFrequencyHz > 0)
        NOTCH_Q = 35;                                   % quality factor (higher = sharper)
        w0 = notchFilterFrequencyHz / (frequencyHz/2);  % normalized notch freq (0..1)
        bw = w0 / NOTCH_Q;                              % -3 dB bandwidth (normalized)
        [bNotch, aNotch] = iirnotch(w0, bw);            % 2nd-order IIR notch
        filteredData = filtfilt(bNotch, aNotch, filteredData);  % zero-phase apply
    end

     %apply the high pass filter if specified
     if (highPassFrequencyHz > 0)
        [b,a] = butter (4, highPassFrequencyHz/(frequencyHz/2), 'high');
        filteredData = filtfilt (b, a, filteredData);
     end

    subplot (NUM_OF_PLOTS,1,PLOT_COUNTER);
    plot(theAxis, filteredData, 'LineWidth', 3, 'Color', 'r');
    ylim([yMin yMax]);
    axFilt = gca;
    ylabel('Nanovolts (nV)', 'FontSize', 14, 'FontWeight', 'B');
    title ('Filtered Data', 'FontSize', 14, 'FontWeight', 'B');
    ApplyTimeTicks(axFilt, theAxis);
    hold on;
    PLOT_COUNTER= PLOT_COUNTER + 1;
end


% ---- STFT spectrogram --------------------------------------------------
subplot(NUM_OF_PLOTS,1,PLOT_COUNTER);
windowSize = round(frequencyHz/FREQUENCY_RESOLUTION_HZ);
overlap = windowSize;
nfft = 2^nextpow2(windowSize);
kaiserBeta = 40*(1-DEFAULT_LEAKAGE);
kaiserWindow = kaiser(windowSize, max(0,kaiserBeta));

% Display controls
SPECTRO_DR = 40;    % dB below peak to display (keeps the ridge visible)

if (notchFilterFrequencyHz == 0 && highPassFrequencyHz == 0)     % idealized signals: unit amplitude ->
    STFT_CLIM = [];                  %   autoscale (empty => per-plot scaling)
elseif frequencyHz > 1500            % rodents + mice (2000 Hz)
    STFT_CLIM = [20 91];
else                                 % humans (1000 Hz)
    STFT_CLIM = [11 77];
end

if (ZERO_PADDING == 1)
    [S,F,T] = spectrogram(filteredData,kaiserWindow,overlap,nfft,frequencyHz, 'onesided');
    PdB = 20*log10(abs(S)+eps);
else
    [P,F,T] = pspectrum(filteredData, frequencyHz, "spectrogram", ...
                        "FrequencyResolution", FREQUENCY_RESOLUTION_HZ, ...
                        "OverlapPercent", 99, "FrequencyLimits", [0 200]);
    PdB = 10*log10(P + eps);
end


% Physically correct ms axis: pspectrum/spectrogram T is seconds elapsed
% from the start of filteredData, which begins at min(theAxis) ms. Small
% empty margins at the edges are the (legitimate) region where no analysis
% window is centred -- the STFT analogue of the wavelet cone of influence.
tMs = min(theAxis) + T(:).'*1000;

imagesc(tMs, F, PdB);
set(gca, 'YDir', 'normal');
colormap("jet");
ylim([0 200]);
if isempty(STFT_CLIM), clim(max(PdB(:)) + [-SPECTRO_DR 0]); else, clim(STFT_CLIM); end
colorbar;
axSpec = gca;
ylabel('Frequency (Hz)', 'FontSize', 14, 'FontWeight', 'B');
xlabel ('Time (ms)', 'FontSize', 14, 'FontWeight', 'B');
title ('STFT spectrogram', 'FontSize', 14, 'FontWeight', 'B');
ApplyTimeTicks(axSpec, theAxis);
hold off;

% ---- Align the data panels to the spectrogram's (colorbar-shrunk) width -
% so all three x-axes register exactly. Pure geometry.
drawnow;
posSpec = get(axSpec, 'Position');
dataAxes = axRaw;
if ~isempty(axFilt), dataAxes = [dataAxes axFilt]; end
for a = dataAxes
    p = get(a, 'Position');
    p([1 3]) = posSpec([1 3]);     % copy x-position and width
    set(a, 'Position', p);
end


%%%%%%%%%%%%%%%%%%%%% Power spectral density (pwelch) %%%%%%%%%%%%%%%%%%%%%%
% Welch PSD in nV^2/Hz. Conserves energy (trapz(f,pxx) ~= mean(x.^2)).
figureHandle2 = figure('Visible','off');
set(gcf, 'Color', 'w');

segLen   = max(8, round(frequencyHz / FREQUENCY_RESOLUTION_HZ));
segLen   = min(segLen, numel(filteredData));
win      = hamming(segLen);
noverlap = floor(0.5 * segLen);
nfft     = max(256, 2^nextpow2(segLen));
[pxx, f] = pwelch(filteredData, win, noverlap, nfft, frequencyHz);  % one-sided, nV^2/Hz

pxxSmooth = smoothdata(pxx, 'gaussian', 15);   % display only
plot(f, pxxSmooth, 'LineWidth', 3);
xlim([0 HIGHER_CUTOFF_FREQUENCY])
xlabel('Frequency (Hz)', 'FontSize', 14, 'FontWeight', 'B');
ylabel('nV^2/Hz', 'FontSize', 14, 'FontWeight', 'B');
title('STFT PSD', 'FontSize', 18, 'FontWeight', 'B');

% Peak from the UNSMOOTHED PSD, matching the wavelet figure.
theAxisForResult   = f((f > LOWER_CUTOFF_FREQUENCY) & (f < HIGHER_CUTOFF_FREQUENCY));
thePowerForResult  = pxx((f > LOWER_CUTOFF_FREQUENCY) & (f < HIGHER_CUTOFF_FREQUENCY));

[maxPower, maxIndex] = max(thePowerForResult);
maxFrequency = theAxisForResult(maxIndex);

end
