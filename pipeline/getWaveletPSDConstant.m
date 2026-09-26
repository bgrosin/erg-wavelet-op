function K = getWaveletPSDConstant(frequencyHz)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function getWaveletPSDConstant by bgrosin
%
% 2 September 2026
%
% Cached energy-calibration constant for the wavelet PSD. Returns K for a
% given sampling rate, computing it once via CalibrateWaveletPSD and
% caching it for the rest of the MATLAB session, so the synthetic
% calibration runs only the first time a given configuration is seen and
% not on every trace.
%
% The cache is keyed on the sampling rate AND the current scale grid from
% getWaveletScales, so any change to the grid forces automatic
% recalibration; no manual clearing is required. Clear manually
% ("clear getWaveletPSDConstant") only if CalibrateWaveletPSD itself is
% modified.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% Takes one parameter
% I - frequencyHz - sampling rate of the recording (Hz)
%
% Returns one parameter
% I - K - the energy-calibration constant for the wavelet PSD
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    persistent Kmap
    if isempty(Kmap)
        Kmap = containers.Map('KeyType','char','ValueType','double');
    end
    s   = getWaveletScales(frequencyHz);
    key = sprintf('%g_%d_%.6g_%.6g', frequencyHz, numel(s), s(1), s(end));
    if ~isKey(Kmap, key)
        Kmap(key) = CalibrateWaveletPSD(frequencyHz, false);
    end
    K = Kmap(key);
end
