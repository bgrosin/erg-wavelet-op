function [FSRArray, handlesArray] = RunAutomatedOPAnalysis(fullFileName, notchFrequencyHz, highPassFrequencyHz)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Function RunAutomatedOPAnalysis by bgrosin
%
% 26 June 2025
%
% Runs the wavelet (CWT) OP analysis on a single recording file: every data
% strip in the file is processed by CreateCWTFigure6, and the peak power
% spectral density and dominant frequency are collected per strip together
% with the handles of the generated figures.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% Takes three parameters
% I   - fullFileName        - full path of the recording file to analyze
% II  - notchFrequencyHz    - notch filter frequency (Hz), 0 for no filter
% III - highPassFrequencyHz - high-pass cutoff (Hz), 0 for no filter
%
% Returns two parameters
% I  - FSRArray     - per-strip [peak PSD, dominant frequency]
% II - handlesArray - per-strip [composite figure, PSD figure] handles
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  [theAxis, theData] = ConvertAlkiesERGFile2(fullFileName);
  frequencyHz = 1000/(theAxis(2) - theAxis(1));
  [~, numOfStrips] = size(theData);
  FSRArray = zeros(numOfStrips, 2);
  handlesArray = zeros(numOfStrips, 2);
  for i = 1:numOfStrips
     [maxPower, maxFrequency, figureHandle1, figureHandle2] = CreateCWTFigure6(theAxis, theData, i, frequencyHz, notchFrequencyHz, highPassFrequencyHz);
     FSRArray(i,1) = maxPower;
     FSRArray(i,2) = maxFrequency;
     handlesArray(i,1) = figureHandle1;
     handlesArray(i,2) = figureHandle2;
  end
