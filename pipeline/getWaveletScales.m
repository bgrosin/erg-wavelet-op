function waveletScales = getWaveletScales(frequencyHz)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function getWaveletScales by bgrosin
%
% 2 September 2026
%
% Single source of truth for the CWT scale grid. Both the analysis
% (CreateCWTFigure6) and the energy calibration (CalibrateWaveletPSD, via
% getWaveletPSDConstant) call this function, so the analysis and the
% calibration can never use different grids. The calibration cache is
% keyed on the grid returned here, so any change to the grid forces
% automatic recalibration.
%
% Grids: 512 logarithmically spaced scales per sampling rate. At 2000 Hz
% (rodents) the grid spans scales 10^0.8 to 10^3 (~1.6 to ~1290 Hz). At
% 1000 Hz (humans) the maximum scale is capped at 200 (~4 Hz), which
% covers the full 0-200 Hz display band while avoiding thousands of
% scales far below the OP band that only slow the transform.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% Takes one parameter
% I - frequencyHz - sampling rate of the recording (Hz)
%
% Returns one parameter
% I - waveletScales - the scale grid for cwt with the real Morlet wavelet
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if frequencyHz == 2000
        % rat / mouse: frequencies up to ~257 Hz, 2^9 scales
        waveletScales = logspace(3, 0.8, 2^9);
    else
        % human (1000 Hz): scale 200 -> ~4 Hz, scale ~2.5 -> ~324 Hz
        waveletScales = logspace(log10(200), 0.4, 2^9);
    end
end
