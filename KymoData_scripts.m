%% KymoData scripts collection
% First load the data
kymoT = loadKymoData;

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
        startIdx = find(reversePoints < 0);
        endIdx = find(reversePoints > 0) - 1;
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
if ~isempty(stims)
    startStim = str2double(cell2mat(stims(1)));
    endStim = str2double(cell2mat(stims(2)));
    nTrack = size(kymoT,1);
    netVelocity = NaN(nTrack,3);
    for t=1:nTrack
        tempTrack = cell2mat(kymoT{t,'Position'});
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
    end
else
    % calculate only from start to end
    nTrack = size(kymoT,1);
    netVelocity = NaN(nTrack,1);
    for t=1:nTrack
        tempTrack = cell2mat(kymoT{t,'Position'});
        point1 = tempTrack(find(~isnan(tempTrack),1));
        point2 = tempTrack(find(~isnan(tempTrack),1,'last'));
        netVelocity(t,1) = (point2 - point1) / sum(~isnan(tempTrack));
    end
end

% set the net velocities in table
kymoT.netVelocity = abs(netVelocity);

% clean useless things
clear t nTrack tempTrack tempVel point1 point2 point3 point4 ans netVelocity stims

%% Segmental analysis
% run length, pause time and percentage time in motion
options.Interpreter='tex';
speeds = inputdlg({'Low threshold (v < 0.5 \mum/s): '; 'High thresholds (v \geq 0.5 \mum/s): '},...
    'Set minimum', 1, {'0.1'; '0.3'}, options);
lowThr = str2double(cell2mat(speeds(1)));
highThr = str2double(cell2mat(speeds(2)));
nTrack = size(kymoT,1);
vel = kymoT.Velocity;
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
    tempVel = vel{t};
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
        stimRunLength(t,1) = nanmean(cell2mat(stimRL(:,1)));
        stimRunLength(t,2) = nanmean(cell2mat(stimRL(:,2)));
        stimRunLength(t,3) = nanmean(cell2mat(stimRL(:,3)));
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


%% Create a table per cell


%% get conditions
uniFltr = kymoT.netDirection == 'Ant' | kymoT.netDirection == 'Ret';
myCond = kymoT{uniFltr,'Condition'};
uniqCond = unique(myCond);

%% Plot combined boxplot of velocity
figure('WindowStyle', 'docked');
h1 = axes;
uniFltr = kymoT.netDirection == 'Ant' | kymoT.netDirection == 'Ret';
vel = abs(kymoT{uniFltr,'stimRunLength'});
myCond = kymoT{uniFltr,'Condition'};
myCond = repmat(myCond,1,3);
uniqCond = unique(myCond);
scGrp = repmat({'B' 'S' 'R'}, size(vel,1), 1);
boxplot(vel, {myCond(:); scGrp(:)}, 'color', cmap(1:4,:), 'colorgroup', myCond(:), 'symbol', '')
hold on
figure('WindowStyle', 'docked');
hs(1) = subplot(2,2,1);
hold on
hs(2) = subplot(2,2,2);
hold on
hs(3) = subplot(2,2,3);
hold on
hs(4) = subplot(2,2,4);
hold on
w = 1;
ll = {'-','--',':'};
for c = 1:numel(uniqCond)
    for g = 1:3
        condFltr = myCond(:,1) == uniqCond(c);
        tempData = vel(condFltr,g);
        tempM = nanmean(tempData);
        tempS = sem(tempData);
        [f, xi] = ksdensity(tempData);
        hLeg(g) = plot(hs(c),xi,f,'color',cmap(c,:),'LineStyle',ll{g});
%         plot(h1,w,tempData,'o','color',cmap(c,:))
        plot(h1,w+0.1,tempM,'o','MarkerEdgeColor', cmap(c,:), 'MarkerFaceColor', 'none', 'MarkerSize',6)
        plot(h1,[w+0.1 w+0.1],[tempM-tempS tempM+tempS],'Color', cmap(c,:))
        w = w+1;
    end
    if c == 1
        ylabel(hs(c),'EDF');
    elseif c == 3
        xlabel(hs(c),'Speed (\mum/s)');
        ylabel(hs(c),'EDF');
    elseif c == numel(uniqCond)
        legend(hs(c),hLeg, {'Baseline','Stimulation','Recovery'})
        xlabel(hs(c),'Speed (\mum/s)');
        legend boxoff
    end
    title(hs(c),sprintf('Motion group %s',char(uniqCond(c))))
end
ylim(h1,'auto')
ylabel(h1,'Velocity (\mu/s)')
box(h1, 'off')


%% Plot stimulations histograms
figure('WindowStyle' ,'docked');
for s = 1:3
    subplot(1, 3, s);
    hold on
    for c = 1:numel(uniqCond)
        condFltr = myCond == uniqCond(c);
        tempData = stm(condFltr,s);
        hLeg(c) = histogram(tempData, 20, 'DisplayStyle', 'stairs', 'normalization', 'probability', 'EdgeColor', cmap(c,:));
    end
    if s == 1
        ylabel('Nobs/Ntot');
        title('Baseline')
    elseif s == 2
        xlabel('Time in motion (%)');
        title('Stimulation')
    else
        legend(hLeg, char(uniqCond))
        title('Recovery')
    end
end
legend boxoff

%% Other way of plotting
figure('WindowStyle' ,'docked');
ll = {'-','-.',':'};
for c = 1:numel(uniqCond)
    subplot(2,2,c);
    hold on
    for s = 1:3
        condFltr = myCond == uniqCond(c);
        tempData = stm(condFltr,s);
        [n,edges] = histcounts(tempData, 20, 'normalization', 'probability');
        hLeg(s) = stairs(edges(1:end-1)+2.5,n,'color',cmap(c,:), 'lineStyle', ll{s}, 'linewidth', 2-1/s);
    end
    if c == 1
        ylabel('Nobs/Ntot');
    elseif c == 3
        xlabel('Time in motion (%)');
        ylabel('Nobs/Ntot');
    elseif c == numel(uniqCond)
        legend(hLeg, {'Baseline','Stimulation','Recovery'})
        xlabel('Time in motion (%)');
        legend boxoff
    end
    title(sprintf('Motion group %s',char(uniqCond(c))))
end
