%% KymoData scripts collection
% First load the data
preVals = who;
options.Interpreter='tex';
resolutions = inputdlg({'Movie duration (s): '; 'Spatial resolution (\mum): '}, 'Resolution', 1, {'90'; '0.4'}, options);
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
    kymoT = [];
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
    kymoT = [];
    return;
end
% collect the data
datafilter   = ~cellfun(@isempty,regexpi(xlAllSheets, '^\d{6}_[a-zA-Z_0-9\-\@]*_\w*(\d\[gr])?')); % recognize the feature date_condition_coverslip_cell as in the help
xlDataSheets = xlAllSheets(datafilter);
% check that there is at least one valid sheet
if numel(xlDataSheets) < 1
    errordlg('Invalid sheets name. Please make sure the file is named properly',...
        'Import failed');
    kymoT = [];
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
kymoT = table(CellID, VesID, Condition, Position, Velocity, axLength);
kymoT.Condition = categorical(kymoT.Condition);
close(hWait);
preVals = [preVals; {'kymoT'}];
clearvars('-except',preVals{:})
%% Calculate Directionality
% Calculate track center
options.Interpreter='tex';
mins = inputdlg({'Minimum speed (\mum/s): '; 'Minimum displacement (\mum): '; 'Minimum reversal displacement (\mum): '},...
    'Set minimum', 1, {'0.1'; '1.2'; '2'},options);
minSpeed = str2double(cell2mat(mins(1)));
minDisp = str2double(cell2mat(mins(2)));
minRDisp = str2double(cell2mat(mins(3)));
trackCenter = cellfun(@(x) nansum(x)/sum(~isnan(x)), kymoT.Position);
nTrack = size(trackCenter,1);

% as default set everything as stationary
relDirection = repmat({'Sta'},nTrack,1);
netDirection = repmat({'Sta'},nTrack,1);
for t=1:nTrack
    tempTrack = cell2mat(kymoT{t,'Position'});
    lastPoint = find(~isnan(tempTrack),1,'last');
    maxDeviation = nanmean(abs(tempTrack - trackCenter(t))) >= minDisp;
    if maxDeviation % moving vesicle
        % dummy vaue for reversal
        reverseTrack = minRDisp - 0.1;
        reversePoints = [0; diff(tempTrack)] < 0;
        reversePoints = diff([1; reversePoints; 1]);
        startIdx = find(reversePoints(2:end) < 0);
        endIdx = find(reversePoints(2:end) > 0);
        if numel(startIdx) > 1
            % potential bidirectional
            for p=1:numel(startIdx)-1
                if p == 1
                    reverseTrack = tempTrack(startIdx(p+1)-1) - tempTrack(endIdx(p));
                    reverseTrack = [reverseTrack; tempTrack(endIdx(p+1)) - tempTrack(startIdx(p+1))];
                else
                    reverseTrack = [reverseTrack; tempTrack(startIdx(p+1)-1) - tempTrack(endIdx(p))];
                    reverseTrack = [reverseTrack; tempTrack(endIdx(p+1)) - tempTrack(startIdx(p+1))];
                end
            end
        end
        if sum(find(abs(reverseTrack) >= minRDisp)) > 1
            % bidirectional
            relDirection{t} = 'Bid';
            % check the net direction
           if tempTrack(lastPoint) > tempTrack(1)
               netDirection{t} = 'Ant';
           else
               netDirection{t} = 'Ret';
           end
        else
           % check if anterograde or retrograde
           if tempTrack(lastPoint) > tempTrack(1)
               relDirection{t} = 'Ant';
               netDirection{t} = 'Ant';
           else
               relDirection{t} = 'Ret';
               netDirection{t} = 'Ret';
           end
        end
    end
end

% set direction as Categorical arrays
relDirection = categorical(relDirection);
netDirection = categorical(netDirection);

% save the direction in the table
kymoT.relDirection = relDirection;
kymoT.netDirection = netDirection;

% clean useless things
clear options p t lastPoint trackCenter nTrack relDirection netDirection tempTrack reversePoints reverseTrack startIdx endIdx mins maxDeviation

%% Net velocities
stims = inputdlg({'Start of stimulation (s): '; 'End of stimulation(s): '},...
    'Set minimum', 1, {'30'; '54'});
if isempty(who('minSpeed'))
    options.Interpreter='tex';
    mins = inputdlg({'Minimum speed (\mum/s): '; 'Minimum displacement (\mum): '; 'Minimum reversal displacement (\mum): '},...
        'Set minimum', 1, {'0.1'; '1.2'; '2'},options);
    minSpeed = str2double(cell2mat(mins(1)));
end
if ~isempty(stims)
    startStim = str2double(cell2mat(stims(1)));
    endStim = str2double(cell2mat(stims(2)));
    nTrack = size(kymoT,1);
    netVelocity = NaN(nTrack,3);
    averageSpeed = zeros(nTrack,3);
    maxVel = zeros(nTrack,3);
    minVel = zeros(nTrack,3);
    for t=1:nTrack
        tempTrack = cell2mat(kymoT{t,'Position'});
        tempSpeed = cell2mat(kymoT{t,'Velocity'});
        point1 = tempTrack(1);
        point2 = tempTrack(startStim);
        point3 = tempTrack(endStim);
        point4 = tempTrack(end);
        %correct the points if NaN
        if isnan(point1)
            point1 = tempTrack(find(~isnan(tempTrack),1));
        end
        if isnan(point2)
            point2 = tempTrack(find(~isnan(tempTrack),1,'last'));
        end
        if isnan(point3)
            point3 = tempTrack(find(~isnan(tempTrack),1,'last'));
        end
        if isnan(point4)
            point4 = tempTrack(find(~isnan(tempTrack),1,'last'));
        end
        % calculate the net velocities
        netVelocity(t,1) = (point2 - point1) / sum(~isnan(tempTrack(1:startStim)));
        netVelocity(t,2) = (point3 - point2) / sum(~isnan(tempTrack(startStim:endStim)));
        netVelocity(t,3) = (point4 - point3) / sum(~isnan(tempTrack(endStim:end)));
        % calculate the average min and max speed
        tempSpeed1 = abs(tempSpeed(1:startStim));
        tempSpeed2 = abs(tempSpeed(startStim:endStim));
        tempSpeed3 = abs(tempSpeed(endStim:end));
        if ~isnan(nanmean(tempSpeed1(tempSpeed1 >= minSpeed)))
            averageSpeed(t,1) = nanmean(tempSpeed1(tempSpeed1 >= minSpeed));
        end
        if ~isnan(nanmean(tempSpeed2(tempSpeed2 >= minSpeed)))
            averageSpeed(t,2) = nanmean(tempSpeed2(tempSpeed2 >= minSpeed));
        end
        if ~isnan(nanmean(tempSpeed3(tempSpeed3 >= minSpeed)))
            averageSpeed(t,3) = nanmean(tempSpeed3(tempSpeed3 >= minSpeed));
        end
        maxVel(t,1) = nanmax(tempSpeed1);
        maxVel(t,2) = nanmax(tempSpeed2);
        maxVel(t,3) = nanmax(tempSpeed3);
        minVel(t,1) = nanmin(tempSpeed1);
        minVel(t,2) = nanmin(tempSpeed2);
        minVel(t,3) = nanmin(tempSpeed3);
    end
else
    % calculate only from start to end
    nTrack = size(kymoT,1);
    netVelocity = NaN(nTrack,1);
    averageSpeed = zeros(nTrack,1);
    maxVel = zeros(nTrack,1);
    minVel = zeros(nTrack,1);
    for t=1:nTrack
        tempTrack = cell2mat(kymoT{t,'Position'});
        tempSpeed = cell2mat(kymoT{t,'Velocity'});
        point1 = tempTrack(find(~isnan(tempTrack),1));
        point2 = tempTrack(find(~isnan(tempTrack),1,'last'));
        netVelocity(t,1) = (point2 - point1) / sum(~isnan(tempTrack));
        tempSpeed = abs(tempSpeed);
        if ~isnan(nanmean(tempSpeed(tempSpeed >= minSpeed)))
            averageSpeed(t,1) = nanmean(tempSpeed(tempSpeed >= minSpeed));
        end
        maxVel(t,1) = nanmax(tempSpeed);
        minVel(t,1) = nanmin(tempSpeed);
    end
end

% set the net velocities in table
kymoT.netVelocity = abs(netVelocity);
kymoT.averageSpeed = averageSpeed;
kymoT.maxSpeed = maxVel;
kymoT.minSpeed = minVel;

% clean useless things
clear tempSpeed1 tempSpeed2 tempSpeed3 t nTrack tempTrack tempVel point1 point2 point3 point4 ans netVelocity stims averageSpeed options tempSpeed maxVel minVel mins

%% Segmental analysis
% run length, pause time and percentage time in motion
options.Interpreter='tex';
speeds = inputdlg({'Low threshold (v < 0.5 \mum/s): '; 'High thresholds (v \geq 0.5 \mum/s): '},...
    'Set minimum', 1, {'0.1'; '0.3'}, options);
lowThr = str2double(cell2mat(speeds(1)));
highThr = str2double(cell2mat(speeds(2)));
nTrack = size(kymoT,1);
varToPlot = kymoT.Velocity;
bStim = size(kymoT.netVelocity,2) == 3;
pauseTime = zeros(nTrack,1);
stimPauseTime = zeros(nTrack,3);
runLength = zeros(nTrack,1);
stimRunLength = zeros(nTrack,3);
timeInMotion = nan(nTrack,1);
stimTimeInMotion = nan(nTrack,3);
timeInPause = nan(nTrack,1);
stimTimeInPause = nan(nTrack,3);

% since there is quite a lot to comput add a wait bar
hWait = waitbar(0, '', 'Name', 'Segment analysis');
for t=1:nTrack
    waitProg = t/nTrack;
    waitbar(waitProg, hWait, sprintf('Analize vesicle %d/%d', t, nTrack));
    tempTrack = cell2mat(kymoT{t,'Position'});
    tempVel = varToPlot{t};
    bPresent = ~isnan(tempVel);
    firstP = find(bPresent,1);
    lastP = find(bPresent,1,'last');
    segments = nan(size(tempVel));
    sCount = 1;
    
    % define the segments
    for v=firstP:lastP
        vNow = tempVel(v);
        if abs(vNow) > minSpeed
            if v == firstP
                vOri = tempVel(v);
                segments(v) = sCount;
            else
                if abs(vOri) >= 0.5
                    thr = abs(highThr*vOri);
                    if (vOri-thr <= vNow) && (vNow <= vOri+thr)
                        vOri = mean([vOri vNow]);
                        segments(v) = sCount;
                    else
                        vOri = vNow;
                        sCount = max(segments)+1;
                        segments(v) = sCount;
                    end
                else
                    thr = abs(lowThr*vOri);
                    if (vOri-thr <= vNow) && (vNow <= vOri+thr)
                        vOri = mean([vOri vNow]);
                        segments(v) = sCount;
                    else
                        vOri = vNow;
                        sCount = max(segments)+1;
                        segments(v) = sCount;
                    end
                end
            end
        else
            segments(v) = 0;
            vOri = tempVel(v);
        end
    end
    
    % store and use the segments
    kymoT.Segments(t) = {segments};
    listSeg = unique(segments(~isnan(segments)));
    nSeg = numel(listSeg);
    s1 = 1;
    s2 = 1;
    s3 = 1;
    RL = 0;
    stimRL = cell(1,3);
    for s=1:nSeg
        currSeg = listSeg(s);
        segFltr = segments == currSeg;
        if currSeg == 0
            % get the total pause time
            pauseTime(t) = sum(segFltr);
            if bStim
                % get the total pause time diveded in stimulation
                stimPauseTime(t,1) = sum(segFltr(1:startStim));
                stimPauseTime(t,2) = sum(segFltr(startStim:endStim));
                stimPauseTime(t,3) = sum(segFltr(endStim:end));
            end
        else
            % get the run length
            tempRun = tempTrack(segFltr); 
            if currSeg == 1
                RL = tempRun(end) - tempRun(1);
            else
                RL = [RL; tempRun(end) - tempRun(1)];
            end
            if bStim
                if find(segFltr,1) < startStim
                    stimRL{s1,1} = RL(end);
                    s1=s1+1;
                elseif find(segFltr,1) < endStim
                    stimRL{s2,2} = RL(end);
                    s2=s2+1;
                else
                    stimRL{s3,3} = RL(end);
                    s3=s3+1;
                end
            end
        end
    end
    
    % get the percentage time in motion
    timeInMotion(t,1) = 100*((sum(bPresent) - pauseTime(t)) / sum(bPresent));
    timeInPause(t,1) = 100*(pauseTime(t) / sum(bPresent));
    if bStim
        stimTimeInMotion(t,1) = 100*((sum(bPresent(1:startStim)) - stimPauseTime(t,1)) / sum(bPresent(1:startStim)));
        stimTimeInMotion(t,2) = 100*((sum(bPresent(startStim:endStim)) - stimPauseTime(t,2)) / sum(bPresent(startStim:endStim)));
        stimTimeInMotion(t,3) = 100*((sum(bPresent(endStim:end)) - stimPauseTime(t,3)) / sum(bPresent(endStim:end)));
        stimTimeInPause(t,1) = 100 - stimTimeInMotion(t,1);
        stimTimeInPause(t,2) = 100 - stimTimeInMotion(t,2);
        stimTimeInPause(t,3) = 100 - stimTimeInMotion(t,3);
    end
    
    % Store the individual RunLegth
    kymoT.RL(t) = {RL};
    if bStim
        kymoT.stimRL{t} = stimRL;
    end
    
    % calculate the average runLength
    runLength(t) = nanmean(RL);
    if bStim
        stimRunLength(t,1) = nanmean(abs(cell2mat(stimRL(:,1))));
        stimRunLength(t,2) = nanmean(abs(cell2mat(stimRL(:,2))));
        stimRunLength(t,3) = nanmean(abs(cell2mat(stimRL(:,3))));
    end
end

% Store the values
kymoT.runLength = runLength;
kymoT.pauseTime = pauseTime;
kymoT.timeInMotion = timeInMotion;
kymoT.timeInPause = timeInPause;
if bStim
    kymoT.stimRunLength = stimRunLength;
    kymoT.stimPauseTime = stimPauseTime;
    kymoT.stimTimeInMotion = stimTimeInMotion;
    kymoT.stimTimeInPause = stimTimeInPause;
end
close(hWait);
clear hWait waitProg timeInPause timeInMotion stimTimeInPause stimTimeInMotion options ans stimPauseTime pauseTime RL segFltr segments tempRun tempTrack thr s listSeg currSeg nSeg s1 s2 s3 stimRL runLength stimRunLength lowThr highThr nTrack vel bStim t tempVel tempVel bPresent firstP lastP sCount v vOri vNow

%% Calculate speed over time
tempVel = kymoT.Velocity;
tempVel = abs(cell2mat(tempVel')');
% tempBase = kymoT.netVelocity(:,1);
tempBase = nanmean(tempVel(:,24:29),2);
tempChange = tempVel ./ repmat(abs(tempBase),1,size(tempVel,2));
tempChange = num2cell(tempChange,2);
kymoT.SpeedChange = tempChange;

clear tempVel tempBase tempChange

% %% Create a table per cell
% % first make everything absolute (runLength = |runLength|)
% uniFltr = kymoT.netDirection == 'Ant' | kymoT.netDirection == 'Ret';
% startFltr = kymoT.netVelocity(:,1) > minSpeed;
% uniFltr = uniFltr & startFltr;
% workT = kymoT(uniFltr,:);
% workT.runLength = abs(workT.runLength);
% workT.stimRunLength = abs(workT.stimRunLength);
% 
% % ask for which variable to calculate the mean
% varNames = workT.Properties.VariableNames;
% [whoVars, OKed] = listdlg('PromptString','Select variables for averge:',...
%     'ListString',varNames);
% if OKed == 0
%     clear retFltr antFltr tempAx a tempFlux tempDensity nAxons axLengths tempT tempFltr tempCell c flux density nCells tempCells tempName whoConds OKed whoVars varNames workT
%     return
% end
% [whoConds, OKed] = listdlg('PromptString','Select Conditions:',...
%     'ListString',varNames);
% if OKed == 0
%     clear retFltr antFltr tempAx a tempFlux tempDensity nAxons axLengths tempT tempFltr tempCell c flux density nCells tempCells tempName whoConds OKed whoVars varNames workT
%     return
% end
% 
% cellT = varfun(@nanmean, workT, 'InputVariables', whoVars, 'GroupingVariables', whoConds);
% tempName = cellT.Properties.VariableNames;
% tempName = cellfun(@(x) regexprep(x,'nanmean_', ''),tempName,'UniformOutput',false);
% cellT.Properties.VariableNames = tempName;
% tempCells = unique(workT.CellID);
% nCells = numel(tempCells);
% density = nan(nCells,3);
% flux = nan(nCells,3);
% % Calculate density and flux in the cellT
% for c = 1:nCells
%     tempCell = tempCells(c);
%     tempFltr = strcmp(workT.CellID, tempCell);
%     tempT = workT(tempFltr,:);
%     axLengths = unique(tempT.axLength,'stable');
%     nAxons = numel(axLengths);
%     tempDensity = zeros(nAxons,3);
%     tempFlux = zeros(nAxons,3);
%     for a = 1:nAxons
%         tempAx = axLengths(a);
%         tempFltr = tempT.axLength == tempAx;
%         antFltr = tempT.netDirection == 'Ant';
%         retFltr = tempT.netDirection == 'Ret';
%         tempDensity(a,1) = sum(tempFltr) / tempAx;
%         tempDensity(a,2) = sum(tempFltr & antFltr) / tempAx;
%         tempDensity(a,3) = sum(tempFltr & retFltr) / tempAx;
%         tempFlux(a,1) = sum(tempFltr & (antFltr | retFltr)) / (tempAx * numel(cell2mat(tempT{1,'Velocity'})));
%         tempFlux(a,2) = sum(tempFltr & antFltr) / (tempAx * numel(cell2mat(tempT{1,'Velocity'})));
%         tempFlux(a,3) = sum(tempFltr & retFltr) / (tempAx * numel(cell2mat(tempT{1,'Velocity'})));
%     end
%     density(c,:) = mean(tempDensity,1);
%     flux(c,:) = mean(tempFlux,1);
% end
% cellT.allDensity = density(:,1);
% cellT.antDensity = density(:,2);
% cellT.retDensity = density(:,3);
% cellT.allFlux = flux(:,1);
% cellT.antFlux = flux(:,2);
% cellT.retFlux = flux(:,3);
% 
% clear retFltr antFltr tempAx a tempFlux tempDensity nAxons axLengths tempT tempFltr tempCell c flux density nCells tempCells tempName whoConds OKed whoVars varNames workT
% 
% %% Create a condition table
% aa = varfun(@(x) nanmean(cell2mat(x)), kymoT(uniFltr,:), 'InputVariables', 'SpeedChange', 'GroupingVariable', {'Condition'});
% aa.Properties.VariableNames{3} = 'mean_SpeedChange';
% ab = varfun(@(x) sem(cell2mat(x)), kymoT(uniFltr,:), 'InputVariables', 'SpeedChange', 'GroupingVariable', {'Condition'});
% ab.Properties.VariableNames{3} = 'sem_SpeedChange';
% condT = [aa, ab(:,3)];

clear ab aa
%% Plot function
preVals = who;

% get the direction for plotting
useDir = questdlg('Which direction to use?', 'Choose direction', 'Anterograde', 'Retrograde', 'Both', 'Both');
switch useDir
    case 'Anterograde'
        uniFltr = kymoT.netDirection == 'Ant';
    case 'Retrograde'
        uniFltr = kymoT.netDirection == 'Ret';
    case 'Both'
        uniFltr = kymoT.netDirection == 'Ant' | kymoT.netDirection == 'Ret';
end

% get the minumin speed
if isempty(who('minSpeed'))
    options.Interpreter='tex';
    minSpeed = inputdlg({'Minimum speed (\mum/s): '}, 'Set minimum', 1, {'0.1'},options);
    minSpeed = str2double(cell2mat(minSpeed(1)));
end
startFltr = kymoT.averageSpeed(:,1) > minSpeed;
uniFltr = uniFltr & startFltr;

% adjust condition and set useful functions
myCond = kymoT{uniFltr,'Condition'};
uniT = kymoT(uniFltr,:);
uniqCond = unique(myCond);
nCond = numel(uniqCond);
cmap = [0.000 0.000 0.000;
        0.678 0.251 0.149;
        0.058 0.506 0.251;
        0.196 0.600 0.600;
        0.942 0.401 0.250;
        0.700 0.900 1.000];
sem = @(x) nanstd(x) ./ sqrt(sum(~isnan(x)));

% get what to plot
varNames = kymoT.Properties.VariableNames;
[whoVar, OKed] = listdlg('PromptString','Select variable(s):',...
    'ListString',varNames);
if OKed == 0
    clearvars('-except',preVals{:})
    return
end
varX = varNames(whoVar);
figure('WindowStyle', 'docked');
h1 = axes;

% start plotting
varToPlot = abs(uniT{:,varX});
secSize = size(varToPlot,2);
if secSize > 1
    myCond = repmat(myCond,1,3);
    scGrp = repmat({'B' 'S' 'R'}, size(varToPlot,1), 1);
    boxplot(varToPlot, {myCond(:); scGrp(:)}, 'color', cmap(1:nCond,:), 'colorgroup', myCond(:), 'symbol', '')
    title(sprintf('%s %s', varX{:}, useDir))
else
    boxplot(varToPlot, myCond(:), 'color', cmap(1:nCond,:), 'symbol', '')
end
hold on
hF = figure('WindowStyle', 'docked');
if secSize > 1
    hs(1) = subplot(2,2,1);
    hold on
    hs(2) = subplot(2,2,2);
    hold on
    hs(3) = subplot(2,2,3);
    hold on
else
    hs(1) = subplot(1,1,1);
    hold on
end
w = 1;
for c = 1:nCond
    condFltr = myCond(:,1) == uniqCond(c);
    condCell = unique(uniT.CellID(condFltr));
    nCell = numel(condCell);
    f = nan(nCell,100);
    for g = 1:secSize
        for cell=1:nCell
            tempCell = condCell(cell);
            cellFltr = strcmp(uniT.CellID, tempCell);
            tempData = varToPlot(condFltr & cellFltr,g);
            [f(cell,:), xi] = ksdensity(tempData,'bandwidth',0.05);
        end
        set(hF, 'currentaxes', hs(g));
        meanF = nanmean(f,1);
        semF = nanstd(f,[],1) ./ sqrt(nCell);
        fillX = [xi fliplr(xi)];
        fillY = [meanF+semF fliplr(meanF-semF)];
        fill(fillX,fillY, cmap(c,:), 'facealpha', .3, 'EdgeColor', 'none');
        hLeg(c) = plot(hs(g),xi,meanF,'color',cmap(c,:));
        tempData = varToPlot(condFltr,g);
        tempM = nanmean(tempData);
        tempS = sem(tempData);
        %         plot(h1,w,tempData,'o','color',cmap(c,:))
        plot(h1,w+0.1,tempM,'o','MarkerEdgeColor', cmap(c,:), 'MarkerFaceColor', 'none', 'MarkerSize',4)
        plot(h1,[w+0.1 w+0.1],[tempM-tempS tempM+tempS],'Color', cmap(c,:))
        w = w+1;
        if secSize > 1
            title(hs(g),sprintf('%s %s', varX{:}, scGrp{1,g}))
        else
            title(hs(g),varX{:})
        end
        if g == 1
            ylabel(hs(g),'EDF');
        elseif g == 2
            xlabel(hs(g),varX{:});
        elseif g == secSize
            ylabel(hs(g),'EDF');
            xlabel(hs(g),varX{:});
        end
    end
end
legend(hs(g),hLeg, char(uniqCond))
legend boxoff
ylim(h1,'auto')
ylabel(h1,varX{:})
box(h1, 'off')

clearvars('-except',preVals{:})

%% Export summary table
preVals = who;
if isempty(who('minSpeed'))
    options.Interpreter='tex';
    minSpeed = inputdlg('Minimum speed (\mum/s): ', 'Set minimum', 1, {'0.1'}, options);
    minSpeed = str2double(cell2mat(minSpeed(1)));
end 
antFltr = kymoT.netDirection == 'Ant';
retFltr = kymoT.netDirection == 'Ret';
movFltr = kymoT.netVelocity(:,1) > minSpeed;
movAnt = antFltr & movFltr;
movRet = retFltr & movFltr;
myCond = kymoT.Condition;
uniqCond = unique(myCond);
nCond = numel(uniqCond);
allSave = {'minSpeed'; 'averageSpeed'; 'maxSpeed'; 'stimRunLength'; 'stimPauseTime'};
saveAll = zeros(30,nCond*2);
sem = @(x) nanstd(x) ./ sqrt(sum(~isnan(x)));
cM = 1:2:nCond*2;
cS = 2:2:nCond*2;
for c=1:nCond
    tempCond = uniqCond(c);
    condFltr = kymoT.Condition == tempCond;
    condAnt = condFltr & movAnt;
    condRet = condFltr & movRet;
    w = 1;
    for s=1:5
        toSave = allSave(s);
        tempAnt = kymoT{condAnt,toSave};
        tempRet = kymoT{condRet,toSave};
        tempAntM = nanmean(tempAnt);
        tempRetM = nanmean(tempRet);
        tempAntS = sem(tempAnt);
        tempRetS = sem(tempRet);
        saveAll(w:w+2,cM(c)) = tempAntM;
        saveAll(w+3:w+5,cM(c)) = tempRetM;
        saveAll(w:w+2,cS(c)) = tempAntS;
        saveAll(w+3:w+5,cS(c)) = tempRetS;
        w = w + 6;
    end
end

% now save to txt
fileID = fopen('kymoSummary.txt', 'w');
stimName = repmat({'Baseline'; 'Stimulation'; 'Recovery'}, 10, 1);
dirName = repmat({''; 'Anterograde'; ''; ''; 'Retrograde'; ''}, 5, 1);
allSave(:,2:6) = repmat({''},5,5);
condName = cellstr(uniqCond)';
condName(2,:) = repmat({'S.E.M.'}, 1,nCond);
condName = reshape(condName,8,1);
condName = [{'';'';''}; condName]';
whoName = horzcat(allSave(1,:), allSave(2,:), allSave(3,:), allSave(4,:), allSave(5,:));
whoName = whoName';
for c = 1:numel(condName)
    if c == numel(condName)
        fprintf(fileID, '%s\r\n', condName{c});
    else
        fprintf(fileID, '%s\t', condName{c});
    end
end
for r=1:30
    fprintf(fileID, '%s\t%s\t%s\t', whoName{r}, dirName{r}, stimName{r});
    for c=1:nCond*2
        if c < nCond*2
            fprintf(fileID, '%.4f\t',saveAll(r,c));
        else
            fprintf(fileID, '%.4f\r\n',saveAll(r,c));
        end
    end
end

fclose(fileID);
clearvars('-except',preVals{:})