%% RP25e  Live Telemetrie Dashboard
%  Tabs: Fahrpedal | Antrieb | Batterie | Reifen | System | Raw Monitor
%
%  Protokoll : MQTT, 2 Bytes pro Nachricht  [Signal-Index | Rohwert]
%  Scroll    : Live-Button pro Tab deaktivieren, dann MATLAB Pan/Zoom nutzen
%  Session   : wird automatisch alle cfg.saveInterval Sekunden gespeichert

clear; clc; close all;

% =========================================================
%% 1. KONFIGURATION
% =========================================================
cfg.host         = "tcp://mqtt-livetele.dynamics-regensburg.de";
cfg.port         = 1883;
cfg.user         = "liveTele_winApp";
cfg.pass         = "dynamics";
cfg.clientID     = "MATLAB_Dash_" + randi(9999);
cfg.topic        = "CAN";
cfg.dbcFile      = "RP25e_CAN1.dbc";
cfg.captureTime  = inf;     % [s]  inf = laeuft bis Fenster geschlossen
cfg.windowSec    = 60;      % [s]  sichtbares Zeitfenster in Plots
cfg.drawInterval = 0.05;    % [s]  Plot-Update = 20 FPS
cfg.monInterval  = 1.0;     % [s]  Raw-Monitor + Titel-Status Update
cfg.saveInterval = 60;      % [s]  Auto-Save Intervall

% =========================================================
%% 2. FARBEN
% =========================================================
BG    = [0.10 0.10 0.12];
PANEL = [0.16 0.16 0.19];
GREEN = [0.20 0.85 0.45];
RED   = [0.92 0.28 0.22];
AMBER = [0.95 0.70 0.10];
BLUE  = [0.30 0.65 0.95];
PURP  = [0.75 0.40 0.95];
CYAN  = [0.20 0.85 0.85];
GRAY  = [0.50 0.50 0.55];
WHITE = [0.90 0.90 0.93];
DIM   = [0.30 0.30 0.35];

% Palette fuer multi-Signal Plots (FL, FR, RL, RR / ist, soll, ...)
PAL = [GREEN; BLUE; AMBER; RED; PURP; CYAN; WHITE; 0.9 0.6 0.3];

% =========================================================
%% 3. DBC LADEN
% =========================================================
fprintf('Lade DBC: %s ...\n', cfg.dbcFile);

sigMap     = containers.Map('KeyType','uint32','ValueType','any');
sigNameMap = containers.Map('KeyType','char',  'ValueType','uint32');
sigIndex   = 0;

fid = fopen(cfg.dbcFile, 'r');
if fid == -1, error('DBC nicht gefunden: %s', cfg.dbcFile); end

while ~feof(fid)
    zeile = strtrim(fgetl(fid));
    if ~ischar(zeile), continue; end
    if startsWith(zeile, 'SG_ ') || startsWith(zeile, ' SG_')
        tok = regexp(zeile, ...
            'SG_\s+(\S+)\s+[M\s]*:\s*\d+\|\d+@\d+[+-]\s*\(([^,]+),([^)]+)\)\s*\[[^\]]*\]\s*"([^"]*)"', ...
            'tokens');
        if isempty(tok), continue; end
        sigIndex            = sigIndex + 1;
        t                   = tok{1};
        sigMap(uint32(sigIndex))  = {t{1}, str2double(t{2}), str2double(t{3}), t{4}};
        sigNameMap(t{1})          = uint32(sigIndex);
    end
end
fclose(fid);
fprintf('OK  %d Signale geladen.\n\n', sigIndex);

% =========================================================
%% 4. SIGNAL-INDICES VORBERECHNEN
% =========================================================
% Tab 1  Fahrpedal
IDX.apps   = getIdx('apps_res_can',            sigNameMap);
IDX.brake  = getIdx('pbrake_rear_can',          sigNameMap);
IDX.steer  = getIdx('steering_wheel_angle_can', sigNameMap);
IDX.speed  = getIdx('speed_can',                sigNameMap);

% Tab 2  Antrieb
IDX.tqFL_ist  = getIdx('unitek_fl_torque_motor_ist_can',  sigNameMap);
IDX.tqFR_ist  = getIdx('unitek_fr_torque_motor_ist_can',  sigNameMap);
IDX.tqRL_ist  = getIdx('unitek_rl_torque_motor_ist_can',  sigNameMap);
IDX.tqRR_ist  = getIdx('unitek_rr_torque_motor_ist_can',  sigNameMap);
IDX.tqFL_soll = getIdx('unitek_fl_torque_motor_soll_can', sigNameMap);
IDX.tqFR_soll = getIdx('unitek_fr_torque_motor_soll_can', sigNameMap);
IDX.tqRL_soll = getIdx('unitek_rl_torque_motor_soll_can', sigNameMap);
IDX.tqRR_soll = getIdx('unitek_rr_torque_motor_soll_can', sigNameMap);
IDX.tqTarget  = getIdx('tqTarget_can',                    sigNameMap);

% Tab 3  Batterie
IDX.ivt_I    = getIdx('IVT_Result_I_can',             sigNameMap);
IDX.ivt_U1   = getIdx('IVT_Result_U1_Pre_Airs_can',   sigNameMap);
IDX.ivt_U2   = getIdx('IVT_Result_U2_Post_Airs_can',  sigNameMap);
IDX.cellTemp = getIdx('battery_cell_temp_01_can',      sigNameMap);
IDX.cellVmax = getIdx('ams_cell_max_voltage_can',      sigNameMap);

% Tab 4  Reifen  (inner / middle / outer pro Ecke)
IDX.tmpFL = [getIdx('ttmd_tire_temp_fl_inner_can',  sigNameMap), ...
             getIdx('ttmd_tire_temp_fl_middle_can', sigNameMap), ...
             getIdx('ttmd_tire_temp_fl_outer_can',  sigNameMap)];
IDX.tmpFR = [getIdx('ttmd_tire_temp_fr_inner_can',  sigNameMap), ...
             getIdx('ttmd_tire_temp_fr_middle_can', sigNameMap), ...
             getIdx('ttmd_tire_temp_fr_outer_can',  sigNameMap)];
IDX.tmpRL = [getIdx('ttmd_tire_temp_rl_inner_can',  sigNameMap), ...
             getIdx('ttmd_tire_temp_rl_middle_can', sigNameMap), ...
             getIdx('ttmd_tire_temp_rl_outer_can',  sigNameMap)];
IDX.tmpRR = [getIdx('ttmd_tire_temp_rr_inner_can',  sigNameMap), ...
             getIdx('ttmd_tire_temp_rr_middle_can', sigNameMap), ...
             getIdx('ttmd_tire_temp_rr_outer_can',  sigNameMap)];
IDX.rocker = [getIdx('rocker_fl_can', sigNameMap), ...
              getIdx('rocker_fr_can', sigNameMap), ...
              getIdx('rocker_rl_can', sigNameMap), ...
              getIdx('rocker_rr_can', sigNameMap)];

% Tab 5  System
IDX.vcuState    = getIdx('VCU_Statemachine_can', sigNameMap);
IDX.tsState     = getIdx('ts_state_can',         sigNameMap);
IDX.invFL       = getIdx('unitek_state_fl_can',  sigNameMap);
IDX.invFR       = getIdx('unitek_state_fr_can',  sigNameMap);
IDX.invRL       = getIdx('unitek_state_rl_can',  sigNameMap);
IDX.invRR       = getIdx('unitek_state_rr_can',  sigNameMap);
IDX.amsOk       = getIdx('ams_ok_pst_b_can',     sigNameMap);
IDX.imdOk       = getIdx('imd_ok_b_can',         sigNameMap);
IDX.drs         = getIdx('drs_state_can',        sigNameMap);
IDX.tsActive    = getIdx('ts_active_b_can',      sigNameMap);

% =========================================================
%% 5. HISTORY + STATUS INITIALISIEREN
% =========================================================
sigT     = cell(sigIndex, 1);   % Zeitstempel [s seit Start]
sigV     = cell(sigIndex, 1);   % dekodierte Werte
sigCount = zeros(sigIndex, 1);  % Empfangs-Zaehler

for k = 1:sigIndex
    sigT{k} = zeros(1, 0, 'double');
    sigV{k} = zeros(1, 0, 'double');
end

% =========================================================
%% 6. FIGURE UND TABS AUFBAUEN
% =========================================================
fig = figure('Name', 'RP25e  Live Telemetrie', ...
    'Color', BG, 'Position', [30 30 1860 990], ...
    'MenuBar', 'none', 'ToolBar', 'figure', 'NumberTitle', 'off');

tg = uitabgroup(fig, 'Position', [0 0 1 1]);

for k = 1:6
    tabH(k) = uitab(tg);  %#ok<AGROW>
    tabH(k).BackgroundColor = BG;
end
tabH(1).Title = 'Fahrpedal';
tabH(2).Title = 'Antrieb';
tabH(3).Title = 'Batterie';
tabH(4).Title = 'Reifen';
tabH(5).Title = 'System';
tabH(6).Title = 'Raw Monitor';

% ── Axes-Stil-Template (wird auf alle Plot-Axes angewandt) ──────────
function styleAx(axH, BG, PANEL, WHITE, GRAY)
    set(axH, 'Color', PANEL, 'XColor', WHITE, 'YColor', WHITE, ...
        'FontName', 'Consolas', 'FontSize', 8, 'Box', 'off', ...
        'GridColor', [0.22 0.22 0.27], 'XGrid', 'on', 'YGrid', 'on', ...
        'GridAlpha', 1, 'Parent', axH.Parent);
    xlabel(axH, 'Zeit [s]', 'Color', GRAY, 'FontSize', 7);
    hold(axH, 'on');
end

% ── Live-Buttons (Tab 1-5) ───────────────────────────────────────────
BTNPOS = [0.43 0.965 0.14 0.024];
for k = 1:5
    liveBtn(k) = uicontrol(tabH(k), 'Style', 'togglebutton', ...
        'String', 'Live folgen', 'Value', 1, ...
        'Units', 'normalized', 'Position', BTNPOS, ...
        'BackgroundColor', [0.15 0.50 0.25], 'ForegroundColor', WHITE, ...
        'FontName', 'Consolas', 'FontSize', 8); %#ok<AGROW>
end

% ──────────────────────────────────────────────────────────────────────
% TAB 1  FAHRPEDAL  (2x2 Layout)
% ──────────────────────────────────────────────────────────────────────
ax.apps  = axes('Parent', tabH(1), 'Position', [0.05 0.53 0.43 0.41]);
ax.brake = axes('Parent', tabH(1), 'Position', [0.53 0.53 0.43 0.41]);
ax.steer = axes('Parent', tabH(1), 'Position', [0.05 0.06 0.43 0.41]);
ax.speed = axes('Parent', tabH(1), 'Position', [0.53 0.06 0.43 0.41]);

styleAx(ax.apps,  BG, PANEL, WHITE, GRAY);
styleAx(ax.brake, BG, PANEL, WHITE, GRAY);
styleAx(ax.steer, BG, PANEL, WHITE, GRAY);
styleAx(ax.speed, BG, PANEL, WHITE, GRAY);

ylabel(ax.apps,  '%',   'Color', GRAY, 'FontSize', 8);
ylabel(ax.brake, 'bar', 'Color', GRAY, 'FontSize', 8);
ylabel(ax.steer, 'deg', 'Color', GRAY, 'FontSize', 8);
ylabel(ax.speed, 'km/h','Color', GRAY, 'FontSize', 8);

ln.apps  = plot(ax.apps,  nan, nan, 'Color', GREEN, 'LineWidth', 1.8);
ln.brake = plot(ax.brake, nan, nan, 'Color', RED,   'LineWidth', 1.8);
ln.steer = plot(ax.steer, nan, nan, 'Color', AMBER, 'LineWidth', 1.8);
ln.speed = plot(ax.speed, nan, nan, 'Color', BLUE,  'LineWidth', 1.8);

% ──────────────────────────────────────────────────────────────────────
% TAB 2  ANTRIEB  (3 Zeilen)
% ──────────────────────────────────────────────────────────────────────
ax.tqFront  = axes('Parent', tabH(2), 'Position', [0.05 0.68 0.91 0.26]);
ax.tqRear   = axes('Parent', tabH(2), 'Position', [0.05 0.37 0.91 0.26]);
ax.tqTarget = axes('Parent', tabH(2), 'Position', [0.05 0.06 0.91 0.25]);

styleAx(ax.tqFront,  BG, PANEL, WHITE, GRAY);
styleAx(ax.tqRear,   BG, PANEL, WHITE, GRAY);
styleAx(ax.tqTarget, BG, PANEL, WHITE, GRAY);

ylabel(ax.tqFront,  'Nm', 'Color', GRAY, 'FontSize', 8);
ylabel(ax.tqRear,   'Nm', 'Color', GRAY, 'FontSize', 8);
ylabel(ax.tqTarget, 'Nm', 'Color', GRAY, 'FontSize', 8);

% FL ist / soll  (solid / dashed)
ln.tqFL_ist  = plot(ax.tqFront, nan, nan, '-',  'Color', GREEN, 'LineWidth', 1.6);
ln.tqFR_ist  = plot(ax.tqFront, nan, nan, '-',  'Color', BLUE,  'LineWidth', 1.6);
ln.tqFL_soll = plot(ax.tqFront, nan, nan, '--', 'Color', GREEN, 'LineWidth', 1.0);
ln.tqFR_soll = plot(ax.tqFront, nan, nan, '--', 'Color', BLUE,  'LineWidth', 1.0);

ln.tqRL_ist  = plot(ax.tqRear, nan, nan, '-',  'Color', AMBER, 'LineWidth', 1.6);
ln.tqRR_ist  = plot(ax.tqRear, nan, nan, '-',  'Color', RED,   'LineWidth', 1.6);
ln.tqRL_soll = plot(ax.tqRear, nan, nan, '--', 'Color', AMBER, 'LineWidth', 1.0);
ln.tqRR_soll = plot(ax.tqRear, nan, nan, '--', 'Color', RED,   'LineWidth', 1.0);

ln.tqTarget = plot(ax.tqTarget, nan, nan, 'Color', WHITE, 'LineWidth', 1.6);

legend(ax.tqFront, {'FL ist','FR ist','FL soll','FR soll'}, ...
    'TextColor', WHITE, 'Color', PANEL, 'EdgeColor', DIM, ...
    'Location', 'northwest', 'FontSize', 7);
legend(ax.tqRear, {'RL ist','RR ist','RL soll','RR soll'}, ...
    'TextColor', WHITE, 'Color', PANEL, 'EdgeColor', DIM, ...
    'Location', 'northwest', 'FontSize', 7);

% ──────────────────────────────────────────────────────────────────────
% TAB 3  BATTERIE  (2x2 Layout)
% ──────────────────────────────────────────────────────────────────────
ax.ivtI    = axes('Parent', tabH(3), 'Position', [0.05 0.53 0.43 0.41]);
ax.ivtU    = axes('Parent', tabH(3), 'Position', [0.53 0.53 0.43 0.41]);
ax.cellT   = axes('Parent', tabH(3), 'Position', [0.05 0.06 0.43 0.41]);
ax.cellVmx = axes('Parent', tabH(3), 'Position', [0.53 0.06 0.43 0.41]);

styleAx(ax.ivtI,    BG, PANEL, WHITE, GRAY);
styleAx(ax.ivtU,    BG, PANEL, WHITE, GRAY);
styleAx(ax.cellT,   BG, PANEL, WHITE, GRAY);
styleAx(ax.cellVmx, BG, PANEL, WHITE, GRAY);

ylabel(ax.ivtI,    'A',  'Color', GRAY, 'FontSize', 8);
ylabel(ax.ivtU,    'V',  'Color', GRAY, 'FontSize', 8);
ylabel(ax.cellT,   'C',  'Color', GRAY, 'FontSize', 8);
ylabel(ax.cellVmx, 'mV', 'Color', GRAY, 'FontSize', 8);

ln.ivtI    = plot(ax.ivtI,    nan, nan, 'Color', CYAN,  'LineWidth', 1.8);
ln.ivtU1   = plot(ax.ivtU,    nan, nan, 'Color', BLUE,  'LineWidth', 1.8);
ln.ivtU2   = plot(ax.ivtU,    nan, nan, 'Color', AMBER, 'LineWidth', 1.8);
ln.cellT   = plot(ax.cellT,   nan, nan, 'Color', RED,   'LineWidth', 1.8);
ln.cellVmx = plot(ax.cellVmx, nan, nan, 'Color', GREEN, 'LineWidth', 1.8);

legend(ax.ivtU, {'U1 pre-Air','U2 post-Air'}, ...
    'TextColor', WHITE, 'Color', PANEL, 'EdgeColor', DIM, ...
    'Location', 'northwest', 'FontSize', 7);

% ──────────────────────────────────────────────────────────────────────
% TAB 4  REIFEN  (4 Temp-Plots oben + Rocker unten)
% ──────────────────────────────────────────────────────────────────────
ax.tmpFL  = axes('Parent', tabH(4), 'Position', [0.04 0.53 0.21 0.41]);
ax.tmpFR  = axes('Parent', tabH(4), 'Position', [0.28 0.53 0.21 0.41]);
ax.tmpRL  = axes('Parent', tabH(4), 'Position', [0.52 0.53 0.21 0.41]);
ax.tmpRR  = axes('Parent', tabH(4), 'Position', [0.76 0.53 0.21 0.41]);
ax.rocker = axes('Parent', tabH(4), 'Position', [0.05 0.06 0.91 0.40]);

for axH = [ax.tmpFL, ax.tmpFR, ax.tmpRL, ax.tmpRR, ax.rocker]
    styleAx(axH, BG, PANEL, WHITE, GRAY);
    ylabel(axH, 'C', 'Color', GRAY, 'FontSize', 8);
end
ylabel(ax.rocker, 'mm', 'Color', GRAY, 'FontSize', 8);

TEMP_COLORS = [RED; AMBER; BLUE];  % inner / middle / outer
CORNER_LABELS = {'FL','FR','RL','RR'};
TEMP_AXES = [ax.tmpFL, ax.tmpFR, ax.tmpRL, ax.tmpRR];

% Dynamisch: 3 Linien pro Ecke
ln.tmp = cell(4, 3);
for corner = 1:4
    for zone = 1:3
        ln.tmp{corner, zone} = plot(TEMP_AXES(corner), nan, nan, ...
            'Color', TEMP_COLORS(zone,:), 'LineWidth', 1.5);
    end
    legend(TEMP_AXES(corner), {'inner','middle','outer'}, ...
        'TextColor', WHITE, 'Color', PANEL, 'EdgeColor', DIM, ...
        'Location', 'northwest', 'FontSize', 6);
end

ROCKER_COLORS = [GREEN, BLUE; AMBER, RED];  % FL, FR, RL, RR
ln.rockerFL = plot(ax.rocker, nan, nan, 'Color', GREEN, 'LineWidth', 1.5);
ln.rockerFR = plot(ax.rocker, nan, nan, 'Color', BLUE,  'LineWidth', 1.5);
ln.rockerRL = plot(ax.rocker, nan, nan, 'Color', AMBER, 'LineWidth', 1.5);
ln.rockerRR = plot(ax.rocker, nan, nan, 'Color', RED,   'LineWidth', 1.5);

legend(ax.rocker, {'FL','FR','RL','RR'}, ...
    'TextColor', WHITE, 'Color', PANEL, 'EdgeColor', DIM, ...
    'Location', 'northwest', 'FontSize', 7);

% ──────────────────────────────────────────────────────────────────────
% TAB 5  SYSTEM  (2x2 Layout)
% ──────────────────────────────────────────────────────────────────────
ax.vcuState = axes('Parent', tabH(5), 'Position', [0.05 0.53 0.43 0.41]);
ax.invState = axes('Parent', tabH(5), 'Position', [0.53 0.53 0.43 0.41]);
ax.tsSafety = axes('Parent', tabH(5), 'Position', [0.05 0.06 0.43 0.41]);
ax.drsOther = axes('Parent', tabH(5), 'Position', [0.53 0.06 0.43 0.41]);

for axH = [ax.vcuState, ax.invState, ax.tsSafety, ax.drsOther]
    styleAx(axH, BG, PANEL, WHITE, GRAY);
    ylabel(axH, 'State', 'Color', GRAY, 'FontSize', 8);
end

ln.vcuState = plot(ax.vcuState, nan, nan, 'Color', GREEN, 'LineWidth', 1.8);
ln.invFL    = plot(ax.invState, nan, nan, 'Color', GREEN, 'LineWidth', 1.5);
ln.invFR    = plot(ax.invState, nan, nan, 'Color', BLUE,  'LineWidth', 1.5);
ln.invRL    = plot(ax.invState, nan, nan, 'Color', AMBER, 'LineWidth', 1.5);
ln.invRR    = plot(ax.invState, nan, nan, 'Color', RED,   'LineWidth', 1.5);
ln.tsState  = plot(ax.tsSafety, nan, nan, 'Color', CYAN,  'LineWidth', 1.8);
ln.amsOk    = plot(ax.tsSafety, nan, nan, 'Color', GREEN, 'LineWidth', 1.5);
ln.imdOk    = plot(ax.tsSafety, nan, nan, 'Color', AMBER, 'LineWidth', 1.5);
ln.drs      = plot(ax.drsOther, nan, nan, 'Color', PURP,  'LineWidth', 1.8);
ln.tsActive = plot(ax.drsOther, nan, nan, 'Color', CYAN,  'LineWidth', 1.5);

legend(ax.invState, {'FL','FR','RL','RR'}, ...
    'TextColor', WHITE, 'Color', PANEL, 'EdgeColor', DIM, ...
    'Location', 'northwest', 'FontSize', 7);
legend(ax.tsSafety, {'TS State','AMS ok','IMD ok'}, ...
    'TextColor', WHITE, 'Color', PANEL, 'EdgeColor', DIM, ...
    'Location', 'northwest', 'FontSize', 7);
legend(ax.drsOther, {'DRS State','TS Active'}, ...
    'TextColor', WHITE, 'Color', PANEL, 'EdgeColor', DIM, ...
    'Location', 'northwest', 'FontSize', 7);

% ──────────────────────────────────────────────────────────────────────
% TAB 6  RAW MONITOR  (scrollbare Tabelle aller DBC-Signale)
% ──────────────────────────────────────────────────────────────────────
monColNames = {'Idx','Signal','Wert','Einheit','Updates','Zuletzt','Status'};
monColWidth = {38, 270, 75, 55, 62, 80, 65};

% Alle 923 Signale einmalig vorbefuellen
monData = cell(sigIndex, 7);
for k = 1:sigIndex
    entry = sigMap(uint32(k));
    monData{k,1} = k;
    monData{k,2} = entry{1};
    monData{k,3} = '---';
    monData{k,4} = entry{4};
    monData{k,5} = 0;
    monData{k,6} = '---';
    monData{k,7} = '[---]';
end

htbl = uitable(tabH(6), ...
    'Data', monData, ...
    'ColumnName', monColNames, ...
    'ColumnWidth', monColWidth, ...
    'Units', 'normalized', ...
    'Position', [0.002 0.005 0.996 0.990], ...
    'FontName', 'Consolas', 'FontSize', 8, ...
    'BackgroundColor', [PANEL; BG], ...
    'ForegroundColor', WHITE, ...
    'RowName', {});

% =========================================================
%% 7. MQTT VERBINDEN
% =========================================================
fprintf('Verbinde mit %s:%d ...\n', cfg.host, cfg.port);

try
    mq = mqttclient(cfg.host, 'Port', cfg.port, ...
        'Username', cfg.user, 'Password', cfg.pass, 'ClientID', cfg.clientID);
    subscribe(mq, cfg.topic);
    fprintf('Verbunden. Topic: "%s"\n\n', cfg.topic);
catch ME
    error('MQTT Verbindung fehlgeschlagen: %s', ME.message);
end

% =========================================================
%% 8. MAIN LOOP
% =========================================================
startZeit  = tic;
drawTimer  = tic;
monTimer   = tic;
saveTimer  = tic;
pktTotal   = 0;
saveCount  = 0;

fprintf('[LIVE] Dashboard laeuft. Fenster schliessen zum Beenden.\n\n');

while ishandle(fig) && toc(startZeit) < cfg.captureTime

    % ── Pakete lesen (alle Zeilen der MQTT-Table) ────────────────────
    data = read(mq);

    if ~isempty(data)
        tNow   = toc(startZeit);
        nZeilen = height(data);

        for i = 1:nZeilen
            bytes = uint8(char(data.Data{i}));
            if length(bytes) < 2, continue; end

            b0  = uint32(bytes(1));
            b1  = double(bytes(2));

            if ~isKey(sigMap, b0), continue; end

            entry  = sigMap(b0);
            val    = b1 * entry{2} + entry{3};

            sigT{b0}(end+1) = tNow;
            sigV{b0}(end+1) = val;
            sigCount(b0)    = sigCount(b0) + 1;
            pktTotal        = pktTotal + 1;
        end
    else
        pause(0.002);
    end

    % ── Aktiven Tab updaten (20 FPS) ─────────────────────────────────
    if toc(drawTimer) >= cfg.drawInterval && ishandle(fig)

        drawTimer  = tic;
        tNow       = toc(startZeit);
        activeTab  = tg.SelectedTab;
        tabIdx     = find(tg.Children == activeTab);
        isLive     = tabIdx <= 5 && get(liveBtn(tabIdx), 'Value') == 1;

        % Hilfsfunktion inline: Linie updaten + XLim bei Live-Modus
        % updateLine(axH, lnH, idx) wird unten als Muster genutzt

        switch tabIdx

            % ── TAB 1  FAHRPEDAL ─────────────────────────────────────
            case 1
                updateLine(ax.apps,  ln.apps,  IDX.apps,  sigT, sigV);
                updateLine(ax.brake, ln.brake, IDX.brake, sigT, sigV);
                updateLine(ax.steer, ln.steer, IDX.steer, sigT, sigV);
                updateLine(ax.speed, ln.speed, IDX.speed, sigT, sigV);
                if isLive
                    xRange = [max(0, tNow-cfg.windowSec), tNow+1];
                    set([ax.apps, ax.brake, ax.steer, ax.speed], 'XLim', xRange);
                end

            % ── TAB 2  ANTRIEB ───────────────────────────────────────
            case 2
                updateLine(ax.tqFront,  ln.tqFL_ist,  IDX.tqFL_ist,  sigT, sigV);
                updateLine(ax.tqFront,  ln.tqFR_ist,  IDX.tqFR_ist,  sigT, sigV);
                updateLine(ax.tqFront,  ln.tqFL_soll, IDX.tqFL_soll, sigT, sigV);
                updateLine(ax.tqFront,  ln.tqFR_soll, IDX.tqFR_soll, sigT, sigV);
                updateLine(ax.tqRear,   ln.tqRL_ist,  IDX.tqRL_ist,  sigT, sigV);
                updateLine(ax.tqRear,   ln.tqRR_ist,  IDX.tqRR_ist,  sigT, sigV);
                updateLine(ax.tqRear,   ln.tqRL_soll, IDX.tqRL_soll, sigT, sigV);
                updateLine(ax.tqRear,   ln.tqRR_soll, IDX.tqRR_soll, sigT, sigV);
                updateLine(ax.tqTarget, ln.tqTarget,  IDX.tqTarget,  sigT, sigV);
                if isLive
                    xRange = [max(0, tNow-cfg.windowSec), tNow+1];
                    set([ax.tqFront, ax.tqRear, ax.tqTarget], 'XLim', xRange);
                end

            % ── TAB 3  BATTERIE ──────────────────────────────────────
            case 3
                updateLine(ax.ivtI,    ln.ivtI,    IDX.ivt_I,    sigT, sigV);
                updateLine(ax.ivtU,    ln.ivtU1,   IDX.ivt_U1,   sigT, sigV);
                updateLine(ax.ivtU,    ln.ivtU2,   IDX.ivt_U2,   sigT, sigV);
                updateLine(ax.cellT,   ln.cellT,   IDX.cellTemp, sigT, sigV);
                updateLine(ax.cellVmx, ln.cellVmx, IDX.cellVmax, sigT, sigV);
                if isLive
                    xRange = [max(0, tNow-cfg.windowSec), tNow+1];
                    set([ax.ivtI, ax.ivtU, ax.cellT, ax.cellVmx], 'XLim', xRange);
                end

            % ── TAB 4  REIFEN ────────────────────────────────────────
            case 4
                cornerAxes  = [ax.tmpFL, ax.tmpFR, ax.tmpRL, ax.tmpRR];
                cornerIdx   = {IDX.tmpFL, IDX.tmpFR, IDX.tmpRL, IDX.tmpRR};
                for corner = 1:4
                    for zone = 1:3
                        idx = cornerIdx{corner}(zone);
                        updateLine(cornerAxes(corner), ln.tmp{corner,zone}, idx, sigT, sigV);
                    end
                end
                updateLine(ax.rocker, ln.rockerFL, IDX.rocker(1), sigT, sigV);
                updateLine(ax.rocker, ln.rockerFR, IDX.rocker(2), sigT, sigV);
                updateLine(ax.rocker, ln.rockerRL, IDX.rocker(3), sigT, sigV);
                updateLine(ax.rocker, ln.rockerRR, IDX.rocker(4), sigT, sigV);
                if isLive
                    xRange = [max(0, tNow-cfg.windowSec), tNow+1];
                    set([ax.tmpFL, ax.tmpFR, ax.tmpRL, ax.tmpRR, ax.rocker], 'XLim', xRange);
                end

            % ── TAB 5  SYSTEM ────────────────────────────────────────
            case 5
                updateLine(ax.vcuState, ln.vcuState, IDX.vcuState, sigT, sigV);
                updateLine(ax.invState, ln.invFL,    IDX.invFL,    sigT, sigV);
                updateLine(ax.invState, ln.invFR,    IDX.invFR,    sigT, sigV);
                updateLine(ax.invState, ln.invRL,    IDX.invRL,    sigT, sigV);
                updateLine(ax.invState, ln.invRR,    IDX.invRR,    sigT, sigV);
                updateLine(ax.tsSafety, ln.tsState,  IDX.tsState,  sigT, sigV);
                updateLine(ax.tsSafety, ln.amsOk,    IDX.amsOk,    sigT, sigV);
                updateLine(ax.tsSafety, ln.imdOk,    IDX.imdOk,    sigT, sigV);
                updateLine(ax.drsOther, ln.drs,      IDX.drs,      sigT, sigV);
                updateLine(ax.drsOther, ln.tsActive, IDX.tsActive, sigT, sigV);
                if isLive
                    xRange = [max(0, tNow-cfg.windowSec), tNow+1];
                    set([ax.vcuState, ax.invState, ax.tsSafety, ax.drsOther], 'XLim', xRange);
                end
        end

        drawnow limitrate;
    end

    % ── 1 Hz: Titel + Raw Monitor updaten ────────────────────────────
    if toc(monTimer) >= cfg.monInterval && ishandle(fig)
        monTimer = tic;
        tNow     = toc(startZeit);

        % Titel-Farbe basierend auf Signalalter (alle Plot-Tabs)
        titleInfo = { ...
            ax.apps,     'THROTTLE',       IDX.apps,    GREEN; ...
            ax.brake,    'BRAKE',          IDX.brake,   RED;   ...
            ax.steer,    'STEERING',       IDX.steer,   AMBER; ...
            ax.speed,    'SPEED',          IDX.speed,   BLUE;  ...
            ax.tqFront,  'TORQUE FRONT',   IDX.tqFL_ist,GREEN; ...
            ax.tqRear,   'TORQUE REAR',    IDX.tqRL_ist,AMBER; ...
            ax.tqTarget, 'TQ TARGET',      IDX.tqTarget,WHITE; ...
            ax.ivtI,     'STROM',          IDX.ivt_I,   CYAN;  ...
            ax.ivtU,     'SPANNUNG',       IDX.ivt_U1,  BLUE;  ...
            ax.cellT,    'ZELLTEMP',       IDX.cellTemp,RED;   ...
            ax.cellVmx,  'MAX ZELLSPG',    IDX.cellVmax,GREEN; ...
            ax.tmpFL,    'TEMP FL',        IDX.tmpFL(1),RED;   ...
            ax.tmpFR,    'TEMP FR',        IDX.tmpFR(1),RED;   ...
            ax.tmpRL,    'TEMP RL',        IDX.tmpRL(1),RED;   ...
            ax.tmpRR,    'TEMP RR',        IDX.tmpRR(1),RED;   ...
            ax.rocker,   'ROCKER',         IDX.rocker(1),GREEN;...
            ax.vcuState, 'VCU STATE',      IDX.vcuState,GREEN; ...
            ax.invState, 'INVERTER STATE', IDX.invFL,   GREEN; ...
            ax.tsSafety, 'TS / SAFETY',    IDX.tsState, CYAN;  ...
            ax.drsOther, 'DRS / OTHER',    IDX.drs,     PURP   ...
        };

        for r = 1:size(titleInfo, 1)
            axH   = titleInfo{r,1};
            lbl   = titleInfo{r,2};
            idx   = titleInfo{r,3};
            col   = titleInfo{r,4};

            if idx > 0 && sigCount(idx) > 0
                age      = tNow - sigT{idx}(end);
                lastVal  = sigV{idx}(end);
                titleStr = sprintf('%s  [%.3g]', lbl, lastVal);
                if age < 2
                    titleCol = col;
                    statusSym = '';
                elseif age < 10
                    titleCol  = AMBER;
                    statusSym = '  (veraltet)';
                    titleStr  = [lbl, statusSym]; %#ok<AGROW>
                else
                    titleCol  = DIM;
                    statusSym = '  (inaktiv)';
                    titleStr  = [lbl, statusSym]; %#ok<AGROW>
                end
            else
                titleCol = DIM;
                titleStr = [lbl, '  (kein Signal)'];
            end
            title(axH, titleStr, 'Color', titleCol, ...
                'FontSize', 9, 'FontName', 'Consolas', 'FontWeight', 'normal');
        end

        % Raw Monitor Tabelle (1 Hz)
        for k = 1:sigIndex
            if sigCount(k) > 0
                age = tNow - sigT{k}(end);
                monData{k,3} = sprintf('%.4g', sigV{k}(end));
                monData{k,5} = sigCount(k);
                if age < 2
                    monData{k,6} = sprintf('%.1fs', age);
                    monData{k,7} = '[OK]';
                elseif age < 30
                    monData{k,6} = sprintf('%.0fs alt', age);
                    monData{k,7} = sprintf('[%ds]', floor(age));
                else
                    monData{k,6} = sprintf('%.0fs alt', age);
                    monData{k,7} = '[INAKTIV]';
                end
            end
        end
        htbl.Data = monData;
    end

    % ── Auto-Save ────────────────────────────────────────────────────
    if toc(saveTimer) >= cfg.saveInterval
        saveTimer = tic;
        saveCount = saveCount + 1;
        saveSession(sigT, sigV, sigCount, sigMap, sigIndex, startZeit, saveCount);
    end

end  % Ende Main Loop

% =========================================================
%% 9. FINALE SESSION SPEICHERN
% =========================================================
fprintf('\n[DONE] %d Pakete empfangen in %.0fs.\n', pktTotal, toc(startZeit));
saveSession(sigT, sigV, sigCount, sigMap, sigIndex, startZeit, 0);
fprintf('[SAVE] Finale Session gespeichert.\n');

% =========================================================
%% LOCAL FUNCTIONS
% =========================================================

function idx = getIdx(name, sigNameMap)
%GETIDX Gibt DBC-Index fuer Signal-Namen zurueck (0 = nicht gefunden).
    if isKey(sigNameMap, name)
        idx = double(sigNameMap(name));
    else
        idx = 0;
        fprintf('[WARN] Signal nicht im DBC: %s\n', name);
    end
end

function updateLine(axH, lnH, idx, sigT, sigV)
%UPDATELINE Setzt XData/YData einer Linie aus der Signal-History.
%  Tut nichts wenn idx = 0 oder noch keine Daten vorhanden.
    if idx <= 0 || isempty(sigT{idx}), return; end
    set(lnH, 'XData', sigT{idx}, 'YData', sigV{idx});
end

function saveSession(sigT, sigV, sigCount, sigMap, sigIndex, startZeit, counter)
%SAVESESSION Speichert komplette Signal-History als .mat-Datei.
    session.sigT      = sigT;
    session.sigV      = sigV;
    session.sigCount  = sigCount;
    session.sigMap    = sigMap;
    session.sigIndex  = sigIndex;
    session.dauer     = toc(startZeit);
    session.gespeichert = datetime('now');

    if counter == 0
        fname = sprintf('session_final_%s.mat', datestr(datetime('now'), 'yyyy-mm-dd_HH-MM-SS'));
    else
        fname = sprintf('session_auto_%02d.mat', counter);
    end
    save(fname, 'session');
    fprintf('[SAVE] %s\n', fname);
end