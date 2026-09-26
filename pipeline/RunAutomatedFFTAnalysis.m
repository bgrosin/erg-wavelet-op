function [FSRArray, handlesArray, paramsArray] = RunAutomatedFFTAnalysis(fullFileName, notchFrequencyHz, highPassFrequencyHz)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function RunAutomatedFFTAnalysis by bgrosin
%
% 27 May 2025
%
% Runs the STFT analysis on a single recording file: every data strip in
% the file is processed by CreateFFTFigure3, and the peak power spectral
% density and dominant frequency are collected per strip together with the
% figure handles and the analysis parameters (zero padding, frequency
% resolution).
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% Takes three parameters
% I   - fullFileName        - full path of the recording file to analyze
% II  - notchFrequencyHz    - notch filter frequency (Hz), 0 for no filter
% III - highPassFrequencyHz - high-pass cutoff (Hz), 0 for no filter
%
% Returns three parameters
% I   - FSRArray     - per-strip [peak PSD, dominant frequency]
% II  - handlesArray - per-strip [composite figure, PSD figure] handles
% III - paramsArray  - per-strip [zero padding, frequency resolution]
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  [theAxis, theData] = ConvertAlkiesERGFile2(fullFileName);
  frequencyHz = 1000/(theAxis(2) - theAxis(1));
  [~, numOfStrips] = size(theData);
  FSRArray = zeros(numOfStrips, 2);
  handlesArray = zeros(numOfStrips, 2);
  paramsArray = zeros(numOfStrips, 2);
  for i = 1:numOfStrips
    [maxPower, maxFrequency, figureHandle1, figureHandle2, zeroPadding, frequencyResolution] = CreateFFTFigure3(theAxis, theData, i, frequencyHz, notchFrequencyHz, highPassFrequencyHz);
     FSRArray(i,1) = maxPower;
     FSRArray(i,2) = maxFrequency;
     handlesArray(i,1) = figureHandle1;
     handlesArray(i,2) = figureHandle2;
     paramsArray(i,1) = zeroPadding;
     paramsArray(i,2) = frequencyResolution;
  end
