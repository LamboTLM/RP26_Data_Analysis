%% Dynamics Live-Telemetrie — Dashboard + Signal Monitor
clear; clc; close all;

% --- 1. KONFIGURATION ---
cfg.host     = "tcp://mqtt-livetele.dynamics-regensburg.de";
cfg.port     = 1883;
cfg.user     = "liveTele_winApp";
cfg.pass     = "dynamics";
cfg.clientID = "MATLAB_Live_" + randi(999);
cfg.topic    = "CAN";
cfg.dbcFile  = "RP25e_CAN1.dbc";

% --- 2. DBC AUTO-PARSER ---
fprintf('Parsing %s...\n', cfg.dbcFile);
sigList   = {};
sigLookup = containers.Map('KeyType','char','ValueType','double');

fid = fopen(cfg.dbcFile, 'r');
if fid == -1, error('DBC nicht gefunden: %s', cfg.dbcFile); end
while ~feof(fid)
    tline = strtrim(fgetl(fid));
    if ~ischar(tline), continue; end
    if startsWith(tline, 'SG_ ') && ...
            ~isempty(regexp(tline, 'TELEMETRY_SIGNALS', 'once'))
        nameMatch  = regexp(tline, 'SG_\s+(\S+)\s+', 'tokens');
        scaleMatch = regexp(tline, '\(([^,]+),([^)]+)\)', 'tokens');
        if ~isempty(nameMatch) && ~isempty(scaleMatch)
            sName  = nameMatch{1}{1};
            factor = str2double(scaleMatch{1}{1});
            offset = str2double(scaleMatch{1}{2});
            if ~isKey(sigLookup, sName)
                sigList{end+1} = {sName, factor, offset};
                sigLookup(sName) = length(sigList);
            end
        end
    end
end

fclose(fid);
fprintf('OK: %d Signale indexiert.\n', length(sigList));

% --- 3. SIGNAL-INDICES ---
IDX_APPS  = sigLookup('apps_res_can');
IDX_BRAKE = sigLookup('pbrake_rear_can');
IDX_STEER = sigLookup('steering_wheel_angle_can');
IDX_SPEED = sigLookup('speed_can');

% --- 4. FARBEN ---
BG    = [0.12 0.12 0.14];
PANEL = [0.18 0.18 0.21];
GREEN = [0.20 0.85 0.45];
RED   = [0.92 0.28 0.22];
AMBER = [0.95 0.70 0.10];
BLUE  = [0.25 0.60 0.95];
GRAY  = [0.45 0.45 0.50];
WHITE = [0.90 0.90 0.93];

% =========================================================
% --- 5. HAUPT-DASHBOARD ---
% =========================================================
figMain = figure('Name','RP25e  —  Live Telemetrie', ...
    'Color',BG, 'Position',[60 60 900 680], ...
    'MenuBar','none', 'ToolBar','none', 'NumberTitle','off');

% ── THROTTLE ─────────────────────────────────────────────
axA = axes(figMain, 'Position',[0.04 0.54 0.22 0.40]);
set(axA, 'Color',PANEL, 'XColor','none', 'YColor',WHITE, ...
    'YLim',[0 100], 'XLim',[0 1], 'XTick',[], ...
    'FontSize',9, 'FontName','Consolas', 'Box','off', ...
    'YGrid','on', 'GridColor',[0.28 0.28 0.33], 'GridAlpha',1);
title(axA, 'THROTTLE', 'Color',WHITE, 'FontSize',10, 'FontWeight','normal');
ylabel(axA, '%', 'Color',GRAY, 'FontSize',9);
hold(axA, 'on');
for yy = [25 50 75]
    patch(axA, [0 1 1 0], [yy-0.4 yy-0.4 yy+0.4 yy+0.4], ...
        [0.25 0.25 0.28], 'EdgeColor','none');
end
pApps = patch(axA, [0.10 0.90 0.90 0.10], [0 0 0.001 0.001], GREEN, 'EdgeColor','none');
hAppsTxt = text(axA, 0.5, 85, '0.0%', 'Color',WHITE, 'FontSize',13, ...
    'HorizontalAlignment','center', 'FontName','Consolas', 'FontWeight','bold');

% ── BRAKE ────────────────────────────────────────────────
axB = axes(figMain, 'Position',[0.28 0.54 0.22 0.40]);
set(axB, 'Color',PANEL, 'XColor','none', 'YColor',WHITE, ...
    'YLim',[0 25], 'XLim',[0 1], 'XTick',[], ...
    'FontSize',9, 'FontName','Consolas', 'Box','off', ...
    'YGrid','on', 'GridColor',[0.28 0.28 0.33], 'GridAlpha',1);
title(axB, 'BRAKE', 'Color',WHITE, 'FontSize',10, 'FontWeight','normal');
ylabel(axB, 'bar', 'Color',GRAY, 'FontSize',9);
hold(axB, 'on');
pBrake = patch(axB, [0.10 0.90 0.90 0.10], [0 0 0.001 0.001], RED, 'EdgeColor','none');
hBrakeTxt = text(axB, 0.5, 21, '0.0 bar', 'Color',WHITE, 'FontSize',13, ...
    'HorizontalAlignment','center', 'FontName','Consolas', 'FontWeight','bold');

% ── ZEITVERLAUF ──────────────────────────────────────────
axT = axes(figMain, 'Position',[0.04 0.06 0.50 0.40]);
set(axT, 'Color',PANEL, 'XColor',WHITE, 'YColor',WHITE, ...
    'FontSize',9, 'FontName','Consolas', 'Box','off', ...
    'YLim',[-110 110], ...
    'GridColor',[0.25 0.25 0.30], 'GridAlpha',1, 'XGrid','on', 'YGrid','on');
hold(axT, 'on');
lA = animatedline(axT, 'Color',GREEN, 'LineWidth',1.5, 'MaximumNumPoints',2000);
lB = animatedline(axT, 'Color',RED,   'LineWidth',1.5, 'MaximumNumPoints',2000);
lS = animatedline(axT, 'Color',AMBER, 'LineWidth',1.2, 'MaximumNumPoints',2000);
xlabel(axT, 'Zeit [s]', 'Color',GRAY);
title(axT, 'ZEITVERLAUF', 'Color',WHITE, 'FontSize',10, 'FontWeight','normal');
legend(axT, {'Throttle [%]','Brake [bar x4]','Steer [deg/2]'}, ...
    'TextColor',WHITE, 'Color',PANEL, 'EdgeColor',[0.30 0.30 0.35], ...
    'Location','northwest', 'FontSize',8);

% ── STEERING GAUGE ───────────────────────────────────────
axG = axes(figMain, 'Position',[0.55 0.30 0.28 0.62]);
set(axG, 'Color',BG, 'Visible','off', ...
    'DataAspectRatio',[1 1 1], 'XLim',[-1.3 1.3], 'YLim',[-1.3 1.3]);
hold(axG, 'on');
R_OUT = 1.15; R_IN = 0.70;
theta_c = linspace(0, 2*pi, 200);
fill(axG, R_OUT*cos(theta_c), R_OUT*sin(theta_c), PANEL, ...
    'EdgeColor',[0.30 0.30 0.36], 'LineWidth',0.8);
makeArc = @(a1, a2, ri, ro, col, alph) patch(axG, ...
    [ri*cos(linspace(deg2rad(90-a1), deg2rad(90-a2), 40)), ...
    ro*cos(linspace(deg2rad(90-a2), deg2rad(90-a1), 40))], ...
    [ri*sin(linspace(deg2rad(90-a1), deg2rad(90-a2), 40)), ...
    ro*sin(linspace(deg2rad(90-a2), deg2rad(90-a1), 40))], ...
    col, 'EdgeColor','none', 'FaceAlpha',alph);
makeArc(  90,  120, R_IN, R_OUT, AMBER, 0.25);
makeArc(-120,  -90, R_IN, R_OUT, AMBER, 0.25);
makeArc( 120,  155, R_IN, R_OUT, RED,   0.30);
makeArc(-155, -120, R_IN, R_OUT, RED,   0.30);
for deg = -150:30:180
    ml_a    = deg2rad(90 - deg);
    isMajor = mod(deg, 90) == 0;
    r2 = isMajor * 0.88 + (~isMajor) * 0.95;
    lw = isMajor * 1.5  + (~isMajor) * 0.8;
    plot(axG, [R_OUT*cos(ml_a) r2*cos(ml_a)], ...
        [R_OUT*sin(ml_a) r2*sin(ml_a)], 'Color',GRAY, 'LineWidth',lw);
    if isMajor && abs(deg) ~= 180
        text(axG, 0.58*cos(ml_a), 0.58*sin(ml_a), sprintf('%d', deg), ...
            'Color',GRAY, 'FontSize',8, 'HorizontalAlignment','center', ...
            'FontName','Consolas');
    end
end
plot(axG, [0 0], [R_IN 0.92], 'Color',[0.40 0.40 0.46], 'LineWidth',1.0);
hNeedle = plot(axG, [0 0], [0 0.88], 'Color',AMBER, 'LineWidth',4);
plot(axG, 0, 0, 'o', 'MarkerFaceColor',WHITE, 'MarkerEdgeColor',WHITE, 'MarkerSize',7);
title(axG, 'STEERING', 'Color',WHITE, 'FontSize',11, 'FontWeight','normal');
hSteerNum = text(axG, 0, -0.50, '0.0', 'Color',AMBER, ...
    'FontSize',22, 'HorizontalAlignment','center', ...
    'FontName','Consolas', 'FontWeight','bold');
text(axG, 0, -0.70, 'degrees', 'Color',GRAY, ...
    'FontSize',8, 'HorizontalAlignment','center', 'FontName','Consolas');

% ── SPEED ────────────────────────────────────────────────
axS = axes(figMain, 'Position',[0.55 0.06 0.28 0.20]);
set(axS, 'Color',PANEL, 'Visible','off', 'XLim',[0 1], 'YLim',[0 1]);
hold(axS, 'on');
patch(axS, [0 1 1 0], [0 0 1 1], PANEL, 'EdgeColor','none');
hSpeedNum = text(axS, 0.5, 0.60, '0', 'Color',BLUE, ...
    'FontSize',58, 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
    'FontName','Consolas', 'FontWeight','bold');
text(axS, 0.5, 0.14, 'km/h', 'Color',GRAY, ...
    'FontSize',12, 'HorizontalAlignment','center', 'FontName','Consolas');

% =========================================================
% --- 6. SIGNAL MONITOR FENSTER ---
% =========================================================
nSig  = length(sigList);
nCols = 3;
nRows = ceil(nSig / nCols);

figMon = figure('Name','RP25e  —  Signal Monitor', ...
    'Color',BG, 'Position',[980 60 680 880], ...
    'MenuBar','none', 'ToolBar','none', 'NumberTitle','off');

axMon = axes(figMon, 'Position',[0 0 1 1]);
set(axMon, 'Color',BG, 'Visible','off', 'XLim',[0 1], 'YLim',[0 1]);
hold(axMon, 'on');

colW = 1 / nCols;
rowH = 1 / (nRows + 1);

text(axMon, 0.5, 1 - rowH*0.3, 'SIGNAL MONITOR', ...
    'Color',WHITE, 'FontSize',11, 'FontName','Consolas', ...
    'FontWeight','bold', 'HorizontalAlignment','center');

for c = 1:nCols-1
    plot(axMon, [c*colW c*colW], [0 1], 'Color',[0.25 0.25 0.30], 'LineWidth',0.5);
end
for c = 1:nCols
    xBase = (c-1)*colW;
    text(axMon, xBase + colW*0.02, 1 - rowH*0.75, 'Signal', ...
        'Color',GRAY, 'FontSize',7, 'FontName','Consolas');
    text(axMon, xBase + colW*0.75, 1 - rowH*0.75, 'Wert', ...
        'Color',GRAY, 'FontSize',7, 'FontName','Consolas');
    text(axMon, xBase + colW*0.98, 1 - rowH*0.75, 'Zeit', ...
        'Color',GRAY, 'FontSize',7, 'FontName','Consolas', ...
        'HorizontalAlignment','right');
end
plot(axMon, [0 1], [1-rowH 1-rowH], 'Color',[0.30 0.30 0.35], 'LineWidth',0.8);

hMonVal  = gobjects(nSig, 1);
hMonTime = gobjects(nSig, 1);

for i = 1:nSig
    c     = mod(i-1, nCols);
    row   = floor((i-1) / nCols);
    xBase = c * colW;
    yPos  = 1 - rowH - row * rowH - rowH*0.5;

    if mod(row, 2) == 0
        patch(axMon, ...
            [xBase, xBase+colW, xBase+colW, xBase], ...
            [yPos-rowH*0.5, yPos-rowH*0.5, yPos+rowH*0.5, yPos+rowH*0.5], ...
            [0.15 0.15 0.18], 'EdgeColor','none');
    end

    % Signal-Name
    name = sigList{i}{1};
    if length(name) > 20, name = [name(1:18) '..']; end
    text(axMon, xBase + colW*0.02, yPos, name, ...
        'Color',GRAY, 'FontSize',6.5, 'FontName','Consolas', ...
        'VerticalAlignment','middle');

    % Wert (separate Text-Objekte fuer Wert und Zeitstempel)
    hMonVal(i) = text(axMon, xBase + colW*0.72, yPos, '---', ...
        'Color',[0.35 0.35 0.40], 'FontSize',7, 'FontName','Consolas', ...
        'FontWeight','bold', 'VerticalAlignment','middle');

    hMonTime(i) = text(axMon, xBase + colW*0.98, yPos, '', ...
        'Color',[0.30 0.30 0.35], 'FontSize',6.5, 'FontName','Consolas', ...
        'HorizontalAlignment','right', 'VerticalAlignment','middle');
end

% =========================================================
% --- 7. MQTT ---
% =========================================================
try
    mq = mqttclient(cfg.host, 'Port',cfg.port, 'Username',cfg.user, ...
        'Password',cfg.pass, 'ClientID',cfg.clientID);
    subscribe(mq, cfg.topic);
    title(axT, 'ZEITVERLAUF  \bullet  LIVE', 'Color',GREEN, ...
        'FontSize',10, 'FontWeight','normal');
    fprintf('Verbunden. Loop laeuft...\n');
catch ME
    title(axT, ['FEHLER: ' ME.message], 'Color',RED, 'FontSize',9);
    return;
end

% =========================================================
% --- 8. MAIN LOOP ---
% =========================================================
startTime     = datetime('now');
lastVal       = nan(nSig, 1);
monBuf        = nan(nSig, 1);
monTimeStr    = repmat({''}, nSig, 1);
monTime       = NaT(nSig, 1);
drawTimer     = tic;
monTimer      = tic;
loopCount     = 0;
pktCount      = 0;
rateTimer     = tic;
DRAW_INTERVAL = 0.05;   % 20 FPS
MON_INTERVAL  = 1.0;    % 1 Hz Signal Monitor

while ishandle(figMain)

    loopCount = loopCount + 1;
    if mod(loopCount, 500) == 0
        fprintf('Loop: %d  |  pkt/s: %.1f\n', loopCount, pktCount / toc(rateTimer));
        pktCount  = 0;
        rateTimer = tic;
    end

    % Pakete lesen
    for batchStep = 1:10
        data = read(mq);
        if isempty(data) 
            pause(0.005); 
            break
        end

        rawBytes = uint8(char(data{1, end}));
        if length(rawBytes) < 2 
            continue 
        end

        sigIdx = rawBytes(1);
        rawVal = rawBytes(2);
        if sigIdx == 255
            continue
        end
        if sigIdx < 1 || sigIdx > nSig
            continue
        end

        sig = sigList{sigIdx};
        val = double(rawVal) * sig{2} + sig{3};
        t   = seconds(datetime('now') - startTime);

        % Monitor-Puffer immer schreiben — unabhaengig ob Wert sich geaendert hat
        monBuf(sigIdx)     = val;
        monTimeStr{sigIdx} = char(datetime('now', 'Format', 'HH:mm:ss'));
        monTime(sigIdx)    = datetime('now');
        pktCount           = pktCount + 1;

        % Fuer Dashboard-Plots: nur bei echter Aenderung neu zeichnen
        changed = isnan(lastVal(sigIdx)) || abs(val - lastVal(sigIdx)) > 1e-4;
        lastVal(sigIdx) = val;
        if ~changed, continue; end

        % ── Throttle ─────────────────────────────────────
        if sigIdx == IDX_APPS
            val = max(0, min(100, val));
            if val > 95,     col = RED;
            elseif val > 80, col = AMBER;
            else,            col = GREEN;
            end
            set(pApps, 'YData',[0 0 val val], 'FaceColor',col);
            set(hAppsTxt, 'String',sprintf('%.1f%%', val));
            addpoints(lA, t, val);

            % ── Brake ────────────────────────────────────────
        elseif sigIdx == IDX_BRAKE
            val = max(0, val);
            set(pBrake, 'YData',[0 0 val val]);
            set(hBrakeTxt, 'String',sprintf('%.1f bar', val));
            addpoints(lB, t, val * 4);

            % ── Steering ─────────────────────────────────────
        elseif sigIdx == IDX_STEER
            if val < -95, continue; end
            ml_a = deg2rad(90 - val);
            set(hNeedle, 'XData',[0, 0.88*cos(ml_a)], ...
                'YData',[0, 0.88*sin(ml_a)]);
            if abs(val) > 120
                set(hNeedle,'Color',RED); set(hSteerNum,'Color',RED);
            else
                set(hNeedle,'Color',AMBER); set(hSteerNum,'Color',AMBER);
            end
            set(hSteerNum, 'String',sprintf('%+.1f', val));
            addpoints(lS, t, val / 2);

            % ── Speed ─────────────────────────────────────────
        elseif sigIdx == IDX_SPEED
            val = max(0, val);
            set(hSpeedNum, 'String',sprintf('%.0f', val));
            if val > 100,    set(hSpeedNum,'Color',RED);
            elseif val > 60, set(hSpeedNum,'Color',GREEN);
            else,            set(hSpeedNum,'Color',BLUE);
            end
        end
    end

    % Haupt-Dashboard rendern
    if toc(drawTimer) >= DRAW_INTERVAL && ishandle(figMain)
        drawnow limitrate;
        drawTimer = tic;
    end

    % Signal Monitor rendern (1 Hz)
    if toc(monTimer) >= MON_INTERVAL && ishandle(figMon)
        nowT = datetime('now');
        for i = 1:nSig
            if ~isnan(monBuf(i))
                age = seconds(nowT - monTime(i));
                if age < 2,     col = WHITE;
                elseif age < 10, col = [0.7 0.7 0.75];
                else,            col = [0.40 0.40 0.45];
                end
                set(hMonVal(i),  'String', sprintf('%.3f', monBuf(i)), 'Color', col);
                set(hMonTime(i), 'String', monTimeStr{i},               'Color', col);
            end
        end
        drawnow limitrate;
        monTimer = tic;
    end

    pause(0.001);
end