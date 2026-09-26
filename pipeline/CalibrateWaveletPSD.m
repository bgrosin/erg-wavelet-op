function [K, diagnostics] = CalibrateWaveletPSD(frequencyHz, doPlot)
%CALIBRATEWAVELETPSD  Energy-calibration constant for the wavelet PSD.
%
%   K = CALIBRATEWAVELETPSD(frequencyHz) returns the single multiplicative
%   constant K such that the corrected wavelet PSD
%
%         PSD(f) = K * mean(|CWT|.^2, 2)
%
%   conserves energy, i.e. it satisfies Parseval:
%
%         trapz(f, PSD) ≈ mean(x.^2)      (mean power of the signal)
%
%   The method: push pure sinusoids of known power (A^2/2) through the
%   EXACT same cwt path used in analysis, and find the K that makes the
%   integral of the wavelet PSD equal the signal's mean power. If the
%   normalization were truly a single constant (as the log-uniform-grid
%   theory predicts), K will be the same for every test tone. The spread
%   of K across tones is therefore the test of whether a scalar is even
%   allowed -- if K drifts with frequency, a scalar cannot fix it.
%
%   [K, diagnostics] = CALIBRATEWAVELETPSD(...) also returns a struct with
%   the per-tone K values, the coefficient of variation of K, and the
%   Parseval ratios obtained when the single median K is applied back.
%
%   NOTE: This calls cwt with the same 'morl' + 'extmode'/'extLen'
%   arguments as your analysis code, so whatever your MATLAB accepts there
%   it accepts here. It does not need any real data.

    if nargin < 2, doPlot = true; end

    waveletScales = getWaveletScales(frequencyHz);
    f = scal2frq(waveletScales, 'morl', 1/frequencyHz);
    f = f(:);
    [fSorted, order] = sort(f);          % ascending, for a clean integral

    % ---- calibration tones across (and a little beyond) the OP band ----
    testFreqs = 60:10:170;
    testFreqs = testFreqs(testFreqs < 0.45*frequencyHz);   % stay clear of Nyquist
    A       = 50;                        % nV; K is independent of amplitude
    durSec  = 0.25;                      % representative record length
    N       = round(durSec * frequencyHz);
    t       = (0:N-1).' / frequencyHz;

    nT   = numel(testFreqs);
    Kf   = zeros(nT,1);                  % K estimated from each tone
    area = zeros(nT,1);
    mp   = zeros(nT,1);

    for ii = 1:nT
        x = A*sin(2*pi*testFreqs(ii)*t);
        d = cwt(x, waveletScales, 'morl', 'extmode','sp0','extLen',200);
        Pmean   = mean(abs(d).^2, 2);
        area(ii) = trapz(fSorted, Pmean(order));   % integral of Pmean df
        mp(ii)   = mean(x.^2);                      % Parseval target (= A^2/2)
        Kf(ii)   = mp(ii) / area(ii);               % K that enforces Parseval
    end

    K   = median(Kf);
    cvK = std(Kf) / mean(Kf);

    % ---- re-apply the single median K and check Parseval per tone --------
    % (non-circular across tones: K was pooled, not fit to each tone)
    parsevalRatio = zeros(nT,1);
    for ii = 1:nT
        x = A*sin(2*pi*testFreqs(ii)*t);
        d = cwt(x, waveletScales, 'morl', 'extmode','sp0','extLen',200);
        Pmean = mean(abs(d).^2, 2);
        parsevalRatio(ii) = trapz(fSorted, K*Pmean(order)) / mean(x.^2);
    end

    diagnostics = struct( ...
        'frequencyHz',    frequencyHz, ...
        'testFreqs',      testFreqs(:), ...
        'Kf',             Kf, ...
        'K',              K, ...
        'cvK',            cvK, ...
        'parsevalRatio',  parsevalRatio, ...
        'minDf',          min(abs(gradient(f))));

    % ---- report ----------------------------------------------------------
    fprintf('\n=== Wavelet PSD calibration, fs = %d Hz ===\n', frequencyHz);
    fprintf('  Calibrated K            = %.6g  (nV^2/Hz per unit Pmean)\n', K);
    fprintf('  K spread (%d..%d Hz)   : CV = %.2f%%  ', ...
            testFreqs(1), testFreqs(end), 100*cvK);
    if cvK < 0.05
        fprintf('-> flat: a single scalar is valid.\n');
    else
        fprintf('-> NOT flat: scalar insufficient, normalization is f-dependent.\n');
    end
    fprintf('  Parseval ratio (~1 ok)  : mean %.3f, range [%.3f, %.3f]\n', ...
            mean(parsevalRatio), min(parsevalRatio), max(parsevalRatio));
    fprintf('  For reference, your old code divided by min(df) = %.6g\n', ...
            min(abs(gradient(f))));
    fprintf('  Old-to-corrected PSP rescaling factor ~ K*min(df) = %.4g\n\n', ...
            K*min(abs(gradient(f))));

    if doPlot
        figure('Color','w');
        subplot(2,1,1);
        plot(testFreqs, Kf/K, 'o-', 'LineWidth', 2); grid on;
        xlabel('Calibration tone (Hz)'); ylabel('K(f) / median K');
        title(sprintf('Constancy of K   (CV = %.2f%%)   fs = %d Hz', ...
                       100*cvK, frequencyHz));
        subplot(2,1,2);
        plot(testFreqs, parsevalRatio, 's-', 'LineWidth', 2); grid on;
        yline(1, 'k--'); ylim([0 2]);
        xlabel('Calibration tone (Hz)');
        ylabel('\int K\cdot Pmean df  /  mean(x^2)');
        title('Parseval check (target = 1)');
    end
end
