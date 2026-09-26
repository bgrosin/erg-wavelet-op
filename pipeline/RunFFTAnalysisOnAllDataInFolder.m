%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Script RunFFTAnalysisOnAllDataInFolder by bgrosin
%
% Usage: interactive batch driver for the STFT analysis. Choose a parent
% directory; every subfolder is treated as one cohort/subject, and every
% .txt recording within it is analyzed by RunAutomatedFFTAnalysis.
% Per-recording results are written to <subfolder>_FFT.xls (one sheet per
% recording, named by frequency resolution), and the composite and PSD
% figures are saved as .jpg and vector .eps alongside the data.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%Constants definition and warnings suppression%%%%%%%%%%%%

warning off MATLAB:xlswrite:AddSheet;
warning off MATLAB:who

%%%%%%%%%%%%%%%%%End of constants definitions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dataPath = uigetdir(pwd, 'Choose directory for analysis');
cd(dataPath);

prompt = {'Enter notch filter frequency (Hz): , 0 if no filter'};
dlgtitle = 'Input';
fieldsize = [1 45];
definput = {'60'};
notchFrequencyHz = inputdlg(prompt,dlgtitle,fieldsize,definput);
notchFrequencyHz = cell2mat(notchFrequencyHz);
notchFrequencyHz = sscanf(notchFrequencyHz, '%d');

prompt = {'Enter highpass filter lower limit (Hz): , 0 if no filter'};
dlgtitle = 'Input';
fieldsize = [1 45];
definput = {'60'};
highPassFrequencyHz = inputdlg(prompt,dlgtitle,fieldsize,definput);
highPassFrequencyHz = cell2mat(highPassFrequencyHz);
highPassFrequencyHz = sscanf(highPassFrequencyHz, '%d');

parentDirectoryContent = dir;
parentDirectoryCount = length(parentDirectoryContent);

for i = 1:parentDirectoryCount
    sheetCounter = 0;
    if(parentDirectoryContent(i).isdir && ~strcmp(parentDirectoryContent(i).name, '.') && ~strcmp(parentDirectoryContent(i).name, '..'))
        thisDirectoryName = parentDirectoryContent(i).name;
        cd(thisDirectoryName);
        thisDirectoryContent = dir;
        thisDirectoryCount = length(thisDirectoryContent);
        xlsFileName = sprintf('%s%s', thisDirectoryName, '_FFT.xls');
        for j = 1:thisDirectoryCount
            thisFileName = thisDirectoryContent(j).name;
            thisFileNameLength = numel(thisFileName);
            if(thisFileNameLength > 4 && strcmp(thisFileName(end-3:end), '.txt')) %this is a text file
                sheetCounter = sheetCounter + 1;
                fullFileName = fullfile(dataPath, thisDirectoryName, thisFileName);
                [FSRArray, handlesArray, paramsArray] = RunAutomatedFFTAnalysis(fullFileName, notchFrequencyHz, highPassFrequencyHz);
                sheetName = sprintf('%s_%d_#%d', 'FreqRes', paramsArray(1,2), sheetCounter); %assumes all analyses done on same res
                writematrix(FSRArray, xlsFileName, 'Sheet', sheetName);
                [numOfFigures, ~] = size(handlesArray);
                for k = 1:numOfFigures
                    thisCompositeFigureName = sprintf('%s_%s_%s_%d_%s_%d_%d%s', thisFileName(1:end-3), 'composite_FFT', 'zeroPadding', paramsArray(k,1), 'frequencyResolution', paramsArray(k,2), k, '.jpg');
                    thisPowerSpectrumFigureName = sprintf('%s_%s_%s_%d_%s_%d_%d%s', thisFileName(1:end-3), 'Power Spectrum_FFT', 'zeroPadding', paramsArray(k,1), 'frequencyResolution', paramsArray(k,2), k, '.jpg');
                    compositeEPSName = sprintf('%s_%s_%s_%d_%s_%d_%d%s', thisFileName(1:end-3), 'composite_FFT', 'zeroPadding', paramsArray(k,1), 'frequencyResolution', paramsArray(k,2), k, '.eps');
                    powerSpectrumEPSName = sprintf('%s_%s_%s_%d_%s_%d_%d%s', thisFileName(1:end-3), 'Power Spectrum_FFT', 'zeroPadding', paramsArray(k,1), 'frequencyResolution', paramsArray(k,2), k, '.eps');
                    saveas(handlesArray(k,1), thisCompositeFigureName, 'jpeg');
                    saveas(handlesArray(k,2), thisPowerSpectrumFigureName, 'jpeg');
                    print(handlesArray(k,1), compositeEPSName, '-depsc2', '-vector');
                    print(handlesArray(k,2), powerSpectrumEPSName, '-depsc2', '-vector');
                    clear('thisCompositeFigureName', 'thisPowerSpectrumFigureName', 'compositeEPSName', 'powerSpectrumEPSName');
                end
                close all hidden;
                clear('fullFileName', 'sheetName');
            end
            clear('thisFileName');
        end
        cd('..');
        clear('thisDirectoryName', 'thisDirectoryContent');
    end
end
