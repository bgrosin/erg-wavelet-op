function [theAxis, theData] = ConvertAlkiesERGFile2(inputFile)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%File ConvertAlkieERGFile by bgrosin 17/11/18, converts the ERG system output
%file to axis and data for plot.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% Takes one parameter
% I - inputFile - the output file of the ERG system
% 
% Returns 2 parameters
% I  - theAxis - the axis for the plot in ms
% II - theData - the data for the plot in microvolts
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


try
    
%%%%%%%%%%Extract the data    
textTable = readtable(inputFile,"Delimiter","|");
dataCell = table2cell(textTable);
clear('textTable');
[arrayLenght, arrayWidth] = size (dataCell);



for i = 1:arrayLenght
    dataArray(i, :) = str2num(dataCell{i,1});
end



theAxis = dataArray(:,1);
theData = dataArray(:,2:end);

catch
    msgbox('Error data in parser', 'non-modal');
end

end

