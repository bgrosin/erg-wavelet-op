function diagnostics = CrossCheckParseval(frequencyHz, x)
%CROSSCHECKPARSEVAL  Verify WT and STFT PSDs conserve the same energy.
%
%   diagnostics = CROSSCHECKPARSEVAL(frequencyHz) runs a built-in two-tone
%   test signal through both the energy-calibrated wavelet PSD and the
%   Welch (pwelch) STFT PSD, integrates each over frequency, and compares
%   both to the signal's mean power, mean(x.^2). All three numbers should
%   agree to within a few percent; the residual is edge / cone-of-influence
%   leakage, not a scaling error.
%
%   CROSSCHECKPARSEVAL(frequencyHz, x) uses your own column-vector signal x
%   (e.g. one real filtered OP trace) instead of the synthetic test tone.
%
%   Requires on the path: getWaveletScales.m, getWaveletPSDConstant.m,
%                         CalibrateWaveletPSD.m
%
%   Parseval targets:
%     WT   :  trapz(fW, K*mean(|W|.^2,2))      ~= mean(x.^2)
%     STFT :  trapz(fF, pwelch PSD)            ~= mean(x.^2)

    fs = frequencyHz;

    % ---- test signal -----------------------------------------------------
    if nargin < 2 || isempty(x)
        N = round(0.25*fs);
        t = (0:N-1).'/fs;
        x = 50*sin(2*pi*110*t) + 20*sin(2*pi*150*t);   % two in-band tones
    else
        x = x(:);
    end
    target = mean(x.^2);            % Parseval ground truth (nV^2)

    % ---- wavelet PSD -----------------------------------------------------
    scales = getWaveletScales(fs);
    d      = cwt(x, scales, 'morl', 'extmode','sp0','extLen',200);
    fW     = scal2frq(scales, 'morl', 1/fs).';
    [fW, order] = sort(fW);                     % ascending for the integral
    K      = getWaveletPSDConstant(fs);
    Pw     = K * mean(abs(d).^2, 2);
    Pw     = Pw(order);
    areaWT = trapz(fW, Pw);

    % ---- STFT PSD via Welch (true nV^2/Hz density) -----------------------
    segLen   = max(8, round(fs/50));            % ~50 Hz resolution, as in pipeline
    segLen   = min(segLen, numel(x));
    win      = hamming(segLen);
    noverlap = floor(0.5*segLen);
    nfft     = max(256, 2^nextpow2(segLen));
    [pxx, fF] = pwelch(x, win, noverlap, nfft, fs);   % one-sided, nV^2/Hz
    areaSTFT  = trapz(fF, pxx);

    % ---- report ----------------------------------------------------------
    fprintf('\n=== Cross-transform Parseval check, fs = %d Hz ===\n', fs);
    fprintf('  mean(x^2)        = %.4g nV^2   (target)\n', target);
    fprintf('  int WT   PSD df  = %.4g nV^2   (ratio %.3f)\n', areaWT,   areaWT/target);
    fprintf('  int STFT PSD df  = %.4g nV^2   (ratio %.3f)\n', areaSTFT, areaSTFT/target);
    fprintf('  WT / STFT integral ratio = %.3f  (should be ~1)\n\n', areaWT/areaSTFT);

    diagnostics = struct( ...
        'frequencyHz',   fs, ...
        'target',        target, ...
        'areaWT',        areaWT, ...
        'areaSTFT',      areaSTFT, ...
        'ratioWT',       areaWT/target, ...
        'ratioSTFT',     areaSTFT/target, ...
        'ratioWTtoSTFT', areaWT/areaSTFT);
end
