function [maxPower, maxFrequency,  figureHandle1, figureHandle2] = CreateCWTFigure6(thisAxis, theData, numberOfDataStrip, frequencyHz, notchFilterFrequencyHz, highPassFrequencyHz)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Function CreateCWTFigure6 by bgrosin
%   Energy-calibrated wavelet PSD. Every panel uses ApplyTimeTicks for
%   consistent, offset-free time labelling (stimulus at t = 0 on real
%   data). The raw/filtered panels are geometrically matched to the
%   spectrogram's colorbar-shrunk width so all three x-axes register.
%   NOTE: update the call in RunAutomatedOPAnalysis to CreateCWTFigure6.
%   Uses a SHARP (high-Q) iirnotch for power-line removal (see below).
%
% Returns:
% I  - maxPower     - peak wavelet spectral power density (nV^2/Hz)
% II - maxFrequency - the frequency at which max power was recorded
% III- figureHandle1- composite figure with spectrogram
% IV - figureHandle2- wavelet PSD figure
%
% Requires on path: getWaveletScales.m, getWaveletPSDConstant.m,
%                   CalibrateWaveletPSD.m, ApplyTimeTicks.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%IMPORTANT ASSUMPTION%%%%%%%%%%%%%%%%%%%


% Check if default value needs to be set to numberOfDataStrip
if (nargin<2)
  numberOfDataStrip = 1;
end

%create and prepare the figure
figureHandle1 = figure ('Visible','off');
set(figureHandle1, 'Color', 'w');

 if (notchFilterFrequencyHz > 0 || highPassFrequencyHz > 0)
     NUM_OF_PLOTS = 3;
     CUTOFF_FREQUENCY = 60;
     TIME_UPPER_CUTOFF_MS = 150;
 else
     NUM_OF_PLOTS = 2;
     CUTOFF_FREQUENCY = 5;
     TIME_UPPER_CUTOFF_MS = 1000;
 end

 PLOT_COUNTER = 1;
 axFilt = [];    % filled only when NUM_OF_PLOTS == 3

%plot the raw data
subplot(NUM_OF_PLOTS,1,PLOT_COUNTER);
thisDataStrip = theData(:, numberOfDataStrip);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Trim to the analysis window. Remove if not needed
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

TIME_LOWER_CUTOFF_MS = min(thisAxis); %keep the pre-stim data to compare to STFT
theAxis = thisAxis((thisAxis <=TIME_UPPER_CUTOFF_MS) & (thisAxis >= TIME_LOWER_CUTOFF_MS));
thisDataStrip = thisDataStrip((thisAxis <=TIME_UPPER_CUTOFF_MS) & (thisAxis >= TIME_LOWER_CUTOFF_MS));
% end of addition
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dataZeroMean = thisDataStrip - mean (thisDataStrip);
axisWidener = max(dataZeroMean) - min (dataZeroMean)/20;
dataZeroMean = smooth(dataZeroMean);
filteredData = dataZeroMean;

plot(theAxis, dataZeroMean, 'LineWidth', 3);
yMin = min (dataZeroMean) -axisWidener ;
yMax = max(dataZeroMean) + axisWidener;
ylim([yMin yMax]);
axRaw = gca; axRaw.FontSize = 16;
ylabel('Nanovolts (nV)', 'FontSize', 18, 'FontWeight', 'B');
title ('Raw Data', 'FontSize', 18, 'FontWeight', 'B');
ApplyTimeTicks(axRaw, theAxis);
hold on;
PLOT_COUNTER = PLOT_COUNTER + 1;

if (NUM_OF_PLOTS == 3)
    %apply a SHARP (narrow-band, high-Q) notch filter if specified
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
    axFilt = gca; axFilt.FontSize = 16;
    ylabel('Nanovolts (nV)', 'FontSize', 18, 'FontWeight', 'B');
    title ('Filtered Data', 'FontSize', 18, 'FontWeight', 'B');
    ApplyTimeTicks(axFilt, theAxis);
    hold on;
    PLOT_COUNTER = PLOT_COUNTER + 1;
end

% ---- Wavelet spectrogram ----------------------------------------------
subplot(NUM_OF_PLOTS,1,PLOT_COUNTER);

% Scale grid from the shared helper so analysis and calibration match.
waveletScales = getWaveletScales(frequencyHz);

d = cwt(filteredData,waveletScales,'morl','extmode','sp0','extLen',200);
cla(gca);                 % wipe cwt's auto-plotted scalogram from this axes
spectFreq = scal2frq(waveletScales, 'morl', 1/frequencyHz);

% Optional shared colour scale with the STFT panel (dB, power mode only).
WT_CLIM = [];
WT_SPECTRO_DR = 40;   % dB below peak, used only in power-spectrogram mode
% Set true to display dB POWER (10*log10|W|^2), matching the STFT panel.
% Default false keeps the original signed-coefficient display.
SHOW_POWER_SPECTROGRAM = false;

if SHOW_POWER_SPECTROGRAM
    Pdb = 10*log10(abs(d).^2 + eps);
    pcolor(theAxis, spectFreq, Pdb);
    shading interp;
    if isempty(WT_CLIM), clim(max(Pdb(:)) + [-WT_SPECTRO_DR 0]); else, clim(WT_CLIM); end
else
    pcolor(theAxis, spectFreq, d);
    shading interp;
    if ~isempty(WT_CLIM), clim(WT_CLIM); end
end
colormap("jet");
colorbar;
axSpec = gca; axSpec.FontSize = 16;
ylim([0 200]);
ylabel('Frequency (Hz)', 'FontSize', 18, 'FontWeight', 'B');
xlabel ('Time (ms)', 'FontSize', 18, 'FontWeight', 'B');
title ('Wavelet spectrogram', 'FontSize', 18, 'FontWeight', 'B');
ApplyTimeTicks(axSpec, theAxis);
hold on;

% ---- Align the data panels to the spectrogram's (colorbar-shrunk) width -
% so all three x-axes register exactly. Pure geometry, no reliance on
% colorbar widths matching.
drawnow;
posSpec = get(axSpec, 'Position');
dataAxes = axRaw;
if ~isempty(axFilt), dataAxes = [dataAxes axFilt]; end
for a = dataAxes
    p = get(a, 'Position');
    p([1 3]) = posSpec([1 3]);     % copy x-position and width
    set(a, 'Position', p);
end


%%%%%%%%%%%%%%%%%% Energy-calibrated wavelet PSD %%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PSD(f) = K * mean(|W(f)|.^2, 2), with trapz(f,PSD) ~= mean(x.^2).
% K comes from CalibrateWaveletPSD via getWaveletPSDConstant.
f = scal2frq(waveletScales,'morl',1/frequencyHz);
f = f(:);

P     = abs(d).^2;              % Nscale x Ntime
Pmean = mean(P, 2);             % time-averaged scalogram power per scale

K = getWaveletPSDConstant(frequencyHz);   % nV^2/Hz per unit Pmean
PSD_wavelet = K * Pmean;                  % energy-conserving PSD (nV^2/Hz)

figureHandle2 = figure('Visible','off');
set(gcf, 'Color', 'w');
PSD_smooth = smoothdata(PSD_wavelet, 'gaussian', 15);   % display only
plot(f, PSD_smooth, 'LineWidth', 3);
xlim([0 200]);
axPSD = gca; axPSD.FontSize = 16;
xlabel('Frequency (Hz)');
ylabel('Wavelet power density (nV^2/Hz)', 'FontSize', 18, 'FontWeight', 'B');
title('Wavelet PSD (energy-calibrated)', 'FontSize', 18, 'FontWeight', 'B');

%%%%%%%%%%%%%%%% Peak spectral power and dominant frequency %%%%%%%%%%%%%%%%
% DF (argmax) is unchanged by K; only the PSP magnitude is corrected.
% Peak from the unsmoothed PSD, matching the STFT figure.
aboveCutoff          = f > CUTOFF_FREQUENCY;
fAbove               = f(aboveCutoff);
PSD_above            = PSD_wavelet(aboveCutoff);
[maxPower, maxIndex] = max(PSD_above);
maxFrequency         = fAbove(maxIndex);

end
