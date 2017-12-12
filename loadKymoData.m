function kymoTable = loadKymoData()
% LOADKYMODATA description


resolutions = inputdlg({'Movie duration (s): '; 'Spatial resolution (\mum): '}, 'Resolution', 1, {'90'; '0.4'});
movieD = str2double(cell2mat(resolutions(1)));
xRes =  str2double(cell2mat(resolutions(2)));
time = 0:movieD;
% check if there is a preference file, if so loaded
if ispref('kymograph', 'kymoPath')
    defPath = getpref('kymograph', 'kymoPath');
else
    defPath = pwd;
end

% ask for the Excel file
[kymoFile, kymoPath] = uigetfile({'*.xlsx;*.xls','Excel files (*.xlsx, *.xls)'}, 'Load Excel file', defPath);
fullKymoPath = fullfile(kymoPath, kymoFile);

if (isempty(fullKymoPath)) || (exist(fullKymoPath, 'file') ~= 2)
    errordlg('Incorrect path entered. Unable to locate the file','Import failed');
    kymoTable = [];
    return;
end

% store the new defPath
setpref('kymograph', 'kymoPath', kymoPath);

% get the sheet names
% [~, xlFile, ~]        = fileparts(fullKymoPath);
[status, xlAllSheets] = xlsfinfo(fullKymoPath);

% check that the file actually exist
if isempty(status)
    errordlg('The selected file was not a valid Excel file', 'Import failed');
    kymoTable = [];
    return;
end

% collect the data
datafilter   = ~cellfun(@isempty,regexpi(xlAllSheets, '^\d{6}_[a-zA-Z_0-9\-\@]*_\w*(\d\[gr])?')); % recognize the feature date_condition_coverslip_cell as in the help
xlDataSheets = xlAllSheets(datafilter);

% check that there is at least one valid sheet
if numel(xlDataSheets) < 1
    errordlg('Invalid sheets name. Please make sure the file is named properly',...
        'Import failed');
    kymoTable = [];
    return;
end

% procede to really collect the data
nSheets = numel(xlDataSheets);
hWait = waitbar(0, '', 'Name', 'Loading file');

for s = 1:nSheets
    waitProg = s/nSheets;
    waitbar(waitProg, hWait, sprintf('Loading %d/%d', s, nSheets));
    sheetName = xlDataSheets{s};
    nameParts = regexpi(sheetName, '_', 'split');
    conditionID = nameParts{2};
    
    % get the IDs
    [~, ~, kymoData] = xlsread(fullKymoPath, sheetName);
    kymoData = kymoData(2:end,2:end);
    
    % calculate the number of vesicles per kymograph
    nanFltr = strcmp(kymoData(:,1), 'NaN');
    nanIdx  = find(nanFltr);
    
    % check if the last raw is a NaN and remove it
    bNan = find(nanFltr, 1, 'last') == size(kymoData,1);
    if bNan
       kymoData = kymoData(1:end-1,:); 
       nanFltr = nanFltr(1:end-1);
       nanIdx = nanIdx(1:end-1);
    end
    nVes = sum(nanFltr) + 1;

    for v = 1:nVes
        if v == 1
            currVes = cell2mat(kymoData(1:(nanIdx(1)-1),:));
        elseif v < nVes
            currVes = cell2mat(kymoData(nanIdx(v-1)+1:nanIdx(v)-1,:));
        else
            currVes = cell2mat(kymoData(nanIdx(v-1)+1:end,:));
        end
        dt = [0, currVes(:,3)'];
        velocity = [NaN, currVes(:,5)'];
        lastX = velocity(end) * dt(end) / xRes; 
        position = round([currVes(:,6)', currVes(end,6)+lastX]) * xRes;
        velQX = interp1(cumsum(dt), velocity, time, 'next');
        posQX = interp1(cumsum(dt), position, time);
        if s == 1 && v == 1
            CellID{1} = sheetName;
            VesID{1} = sprintf('%03d', v);
            Condition{1} = conditionID;
            Position{1} = posQX';
            Velocity{1} = velQX';
            axLength(1) = cell2mat(kymoData(1,8));
        else
            CellID{end+1, 1} = sheetName;
            VesID{end+1, 1} = sprintf('%03d', v);
            Condition{end+1, 1} = conditionID;
            Position{end+1, 1} = posQX';
            Velocity{end+1, 1} = velQX';
            if v < nVes 
                axLength(end+1, 1) = cell2mat(kymoData(nanIdx(v)+1,8));
            else
                axLength(end+1, 1) = cell2mat(kymoData(end,8));
            end
        end
    end
end

kymoTable = table(CellID, VesID, Condition, Position, Velocity, axLength);
kymoTable.Condition = categorical(kymoTable.Condition);
close(hWait);
