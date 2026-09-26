%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Script RunOPAnalysisOnAllDataInFolder by bgrosin
%
% Usage: interactive batch driver for the wavelet (CWT) OP analysis. Choose
% a parent directory; every subfolder is treated as one cohort/subject, and
% every .txt recording within it is analyzed by RunAutomatedOPAnalysis.
% Per-recording results are written to <subfolder>.xls (one sheet per
% recording), and the composite and PSD figures are saved as .jpg and
% vector .eps alongside the data.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%Constants definition and warnings suppression%%%%%%%%%%%%

warning off MATLAB:xlswrite:AddSheet;
warning off MATLAB:who

%%%%%%%%%%%%%%%%%End of constants definitions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dataPath = uigetdir(pwd, 'Choose directory for analysis');
cd(dataPath);

prompt = {'Enter notch filter frequency (Hz):'};
dlgtitle = 'Input';
fieldsize = [1 45];
definput = {'60'};
notchFrequencyHz = inputdlg(prompt,dlgtitle,fieldsize,definput);
notchFrequencyHz = cell2mat(notchFrequencyHz);
notchFrequencyHz = sscanf(notchFrequencyHz, '%d');

prompt = {'Enter highpass filter lower limit (Hz):'};
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
        xlsFileName = sprintf('%s%s', thisDirectoryName, '.xls');
        for j = 1:thisDirectoryCount
            thisFileName = thisDirectoryContent(j).name;
            thisFileNameLength = numel(thisFileName);
            if(thisFileNameLength > 4 && strcmp(thisFileName(end-3:end), '.txt')) %this is a text file
                sheetCounter = sheetCounter + 1;
                fullFileName = fullfile(dataPath, thisDirectoryName, thisFileName);
                [FSRArray, handlesArray] = RunAutomatedOPAnalysis(fullFileName, notchFrequencyHz, highPassFrequencyHz);
                writematrix(FSRArray, xlsFileName, 'Sheet', sheetCounter);
                [numOfFigures, ~] = size(handlesArray);
                for k = 1:numOfFigures
                    thisCompositeJPGFigureName = sprintf('%s_%s_%d%s', thisFileName(1:end-3), 'composite', k, '.jpg');
                    thisPowerSpectrumJPGFigureName = sprintf('%s_%s_%d%s', thisFileName(1:end-3), 'Power Spectrum', k, '.jpg');
                    thisCompositeEPSFigureName = sprintf('%s_%s_%d%s', thisFileName(1:end-3), 'composite', k, '.eps');
                    thisPowerSpectrumEPSFigureName = sprintf('%s_%s_%d%s', thisFileName(1:end-3), 'Power Spectrum', k, '.eps');
                    saveas(handlesArray(k,1), thisCompositeJPGFigureName, 'jpeg');
                    saveas(handlesArray(k,2), thisPowerSpectrumJPGFigureName, 'jpeg');
                    print(handlesArray(k,1), thisCompositeEPSFigureName, '-depsc2', '-vector');
                    print(handlesArray(k,2), thisPowerSpectrumEPSFigureName, '-depsc2', '-vector');
                    clear('thisCompositeJPGFigureName', 'thisPowerSpectrumJPGFigureName', 'thisCompositeEPSFigureName', 'thisPowerSpectrumEPSFigureName');
                end
                close all hidden;
                clear('fullFileName', 'thisFileName', 'handlesArray', 'FSRArray');
            end
            clear('thisFileName');
        end
        cd('..');
        clear('thisDirectoryName', 'thisDirectoryContent');
    end
end
