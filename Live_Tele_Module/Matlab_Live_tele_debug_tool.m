%% RP25e — MQTT Telemetrie Debug Tool
%  =====================================================================
%  Zweck: Rohdaten vom MQTT-Broker erfassen und analysieren, BEVOR
%         irgendwelche DBC-Dekodierung stattfindet.
%
%  Zwei Modi (cfg.mode):
%    'live'    → verbindet sich mit dem Broker und logged alles
%    'offline' → liest eine bereits gespeicherte .mat-Session ein
%
%  Output:
%    - Live-Hex-Dump in der Konsole
%    - Statistik-Tabelle: welche Byte[0]-Werte kommen wie oft?
%    - Automatisches Speichern aller Rohdaten als .mat-Datei
%    - Cross-Referenz mit DBC (falls Parser funktioniert)
%
%  Workflow:
%    1. Dieses Skript mit mode='live' laufen lassen (Fahrzeug muss senden)
%    2. Session wird als mqtt_session_<timestamp>.mat gespeichert
%    3. Analyse offline mit mode='offline' wiederholen
%  =====================================================================
clear; clc; close all;

% ── KONFIGURATION ────────────────────────────────────────────────────
cfg.mode        = 'live';           % 'live' oder 'offline'
cfg.host        = "tcp://mqtt-livetele.dynamics-regensburg.de";
cfg.port        = 1883;
cfg.user        = "liveTele_winApp";
cfg.pass        = "dynamics";
cfg.clientID    = "MATLAB_Debug_" + randi(9999);
cfg.topic       = "CAN";
cfg.dbcFile     = "RP25e_CAN1.dbc";
cfg.captureTime = 30;               % Sekunden für Live-Capture
cfg.maxPackets  = 50000;            % Sicherheitslimit
cfg.offlineFile = '';               % Nur für mode='offline' relevant

% ── FARBEN (Konsole nutzt keine, aber Figure braucht sie) ─────────────
C.BG    = [0.10 0.10 0.12];
C.PANEL = [0.16 0.16 0.19];
C.GREEN = [0.20 0.85 0.45];
C.RED   = [0.92 0.28 0.22];
C.AMBER = [0.95 0.70 0.10];
C.BLUE  = [0.30 0.65 0.95];
C.GRAY  = [0.50 0.50 0.55];
C.WHITE = [0.90 0.90 0.93];
C.DIM   = [0.35 0.35 0.40];

% =====================================================================
%% SCHRITT 1 — DBC LADEN (nur zur Referenz, kein Filter)
% =====================================================================
fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('  RP25e MQTT Debug Tool\n');
fprintf('%s\n\n', repmat('=', 1, 60));

dbc = parseDBC_vollstaendig(cfg.dbcFile);
fprintf('[DBC] %d Signale total geladen (kein Filter)\n', length(dbc.signale));
fprintf('[DBC] Knoten im Netzwerk: %s\n\n', strjoin(dbc.knoten, ', '));

% =====================================================================
%% SCHRITT 2 — CAPTURE oder OFFLINE LADEN
% =====================================================================
if strcmp(cfg.mode, 'live')
    session = liveCaptureStarten(cfg, C);
else
    session = offlineSessionLaden(cfg);
end

if isempty(session.pakete)
    fprintf('[WARN] Keine Pakete in der Session. Abbruch.\n');
    return;
end

% =====================================================================
%% SCHRITT 3 — PROTOKOLL-ANALYSE
% =====================================================================
analyseProtokolll(session, dbc, C);

% =====================================================================
%% SCHRITT 4 — STATISTIK-FIGURE
% =====================================================================
zeigStatistikFigure(session, dbc, C);


% =====================================================================
% ██████████████  LOKALE FUNKTIONEN  ██████████████████████████████████
% =====================================================================

function dbc = parseDBC_vollstaendig(dbcFile)
%PARSEDBC_VOLLSTAENDIG Liest alle Signale aus dem DBC — ohne jeglichen Filter.
%
%  Gibt zurück:
%    dbc.signale  : struct-Array mit Feldern name, canId, msgName,
%                   factor, offset, min, max, unit, startBit, length,
%                   isSigned, byteOrder, receiver
%    dbc.knoten   : cell-Array aller Knoten-Namen (BU_)
%    dbc.messages : struct-Array mit id, name, dlc, sender

dbc.signale  = struct('name',{},'canId',{},'msgName',{},'factor',{}, ...
    'offset',{},'min',{},'max',{},'unit',{}, ...
    'startBit',{},'laenge',{},'isSigned',{}, ...
    'byteOrder',{},'receiver',{});
dbc.knoten   = {};
dbc.messages = struct('id',{},'name',{},'dlc',{},'sender',{});

fid = fopen(dbcFile, 'r');
if fid == -1
    warning('[DBC] Datei nicht gefunden: %s', dbcFile);
    return;
end

aktuelleMsg   = [];
aktuelleCanId = 0;
aktiveMsgName = '';

while ~feof(fid)
    zeile = strtrim(fgetl(fid));
    if ~ischar(zeile) || isempty(zeile), continue; end

    % ── Knoten-Liste ────────────────────────────────────────────
    if startsWith(zeile, 'BU_:')
        teile       = strsplit(strtrim(zeile(5:end)));
        dbc.knoten  = teile(~cellfun(@isempty, teile));

        % ── Nachricht ───────────────────────────────────────────────
    elseif startsWith(zeile, 'BO_ ')
        tok = regexp(zeile, 'BO_\s+(\d+)\s+(\S+)\s*:\s*(\d+)\s+(\S+)', 'tokens');
        if ~isempty(tok)
            aktuelleCanId = str2double(tok{1}{1});
            aktiveMsgName = tok{1}{2};
            m.id     = aktuelleCanId;
            m.name   = aktiveMsgName;
            m.dlc    = str2double(tok{1}{3});
            m.sender = tok{1}{4};
            dbc.messages(end+1) = m;
        end

        % ── Signal ──────────────────────────────────────────────────
    elseif startsWith(zeile, ' SG_') || startsWith(zeile, '\tSG_')
        % Format: SG_ name : startBit|len@byteOrder(factor,offset) [min|max] "unit" receiver
        tok = regexp(zeile, ...
            'SG_\s+(\S+)\s+[M\s]*:\s*(\d+)\|(\d+)@(\d+)([+-])\s*\(([^,]+),([^)]+)\)\s*\[([^|]*)\|([^\]]*)\]\s*"([^"]*)"\s*(.*)', ...
            'tokens');
        if ~isempty(tok)
            t = tok{1};
            s.name      = t{1};
            s.canId     = aktuelleCanId;
            s.msgName   = aktiveMsgName;
            s.startBit  = str2double(t{2});
            s.laenge    = str2double(t{3});
            s.byteOrder = str2double(t{4});  % 1=little, 0=big
            s.isSigned  = strcmp(t{5}, '-');
            s.factor    = str2double(t{6});
            s.offset    = str2double(t{7});
            s.min       = str2double(t{8});
            s.max       = str2double(t{9});
            s.unit      = t{10};
            s.receiver  = strtrim(t{11});
            dbc.signale(end+1) = s;
        end
    end
end
fclose(fid);
end

% ─────────────────────────────────────────────────────────────────────

function session = liveCaptureStarten(cfg, C)
%LIVECAPTURESTARTEN Verbindet sich mit dem MQTT-Broker und sammelt Rohdaten.
%
%  Jedes Paket wird gespeichert als:
%    session.pakete(i).timestamp   : datetime
%    session.pakete(i).rawBytes    : uint8-Vektor (vollständige Payload)
%    session.pakete(i).topic       : char
%    session.pakete(i).payloadHex  : char (Hex-String für Lesbarkeit)

fprintf('[MQTT] Verbinde mit %s:%d ...\n', cfg.host, cfg.port);

try
    mq = mqttclient(cfg.host, 'Port', cfg.port, ...
        'Username', cfg.user, 'Password', cfg.pass, ...
        'ClientID', cfg.clientID);
    subscribe(mq, cfg.topic);
    fprintf('[MQTT] Verbunden. Topic: "%s"\n', cfg.topic);
catch ME
    error('[MQTT] Verbindung fehlgeschlagen: %s', ME.message);
end

% ── Erste Nachricht abwarten ─────────────────────────────────────
fprintf('[MQTT] Warte auf erste Nachricht');
timeout  = tic;
ersteMsg = false;
while toc(timeout) < 10
    probe = read(mq);
    if ~isempty(probe)
        ersteMsg = true;
        fprintf(' OK!\n\n');
        break;
    end
    fprintf('.');
    pause(0.1);
end
if ~ersteMsg
    fprintf('\n[WARN] Keine Nachrichten in 10s. Broker sendet möglicherweise gerade nichts.\n');
    fprintf('       Ist das Fahrzeug eingeschaltet und sendet es aktiv?\n\n');
end

% ── Capture-Loop ─────────────────────────────────────────────────
fprintf('[CAPTURE] Starte Aufzeichnung für %d Sekunden ...\n', cfg.captureTime);
fprintf('          Max. Pakete: %d\n\n', cfg.maxPackets);
fprintf('  %-8s  %-5s  %-6s  %s\n', 'Zeit [s]', '#Pkt', 'Rate/s', 'Letzte Payload (Hex)');
fprintf('  %s\n', repmat('-', 1, 55));

pakete      = struct('timestamp',{},'rawBytes',{},'topic',{},'payloadHex',{});
startZeit   = tic;
rateTimer   = tic;
pktRate     = 0;
letzterDump = '';

while toc(startZeit) < cfg.captureTime && length(pakete) < cfg.maxPackets
    for batchStep = 1:20  % Batch lesen
        msg = read(mq);
        if isempty(msg), break; end

        % ── Payload extrahieren ──────────────────────────────────
        % read() gibt eine Table zurück. Spalten prüfen:
        payload = extrahierePayload(msg);
        if isempty(payload), continue; end

        pkt.timestamp  = datetime('now');
        pkt.rawBytes   = payload;
        pkt.topic      = cfg.topic;
        pkt.payloadHex = bytes2hex(payload);
        pakete(end+1) = pkt;  %#ok<AGROW>
        letzterDump   = pkt.payloadHex;
        pktRate        = pktRate + 1;
    end

    % ── Konsolen-Update (1 Hz) ───────────────────────────────────
    if toc(rateTimer) >= 1.0
        fprintf('  %-8.1f  %-5d  %-6.1f  %s\n', ...
            toc(startZeit), length(pakete), pktRate, letzterDump);
        pktRate   = 0;
        rateTimer = tic;
    end
    pause(0.002);
end

fprintf('\n[CAPTURE] Aufzeichnung beendet. %d Pakete gesammelt.\n', length(pakete));

% ── Session speichern ────────────────────────────────────────────
session.pakete    = pakete;
session.startZeit = datetime('now') - seconds(toc(startZeit));
session.cfg       = cfg;

dateiname = sprintf('mqtt_session_%s.mat', ...
    datestr(datetime('now'), 'yyyy-mm-dd_HH-MM-SS'));
save(dateiname, 'session');
fprintf('[SAVE] Session gespeichert: %s\n\n', dateiname);

clear mq;
end

% ─────────────────────────────────────────────────────────────────────

function payload = extrahierePayload(mqttData)
%EXTRAHIEREPAYLOAD Holt den rohen uint8-Payload aus dem MQTT-read()-Ergebnis.
%
%  Gibt ALLE möglichen Spaltenformate aus (Debug-Info beim ersten Aufruf).

persistent ersterAufruf;
if isempty(ersterAufruf)
    ersterAufruf = true;
    fprintf('\n[DEBUG] MQTT read() Rückgabe-Struktur:\n');
    if istable(mqttData)
        fprintf('  Typ: table | Spalten: %s\n', strjoin(mqttData.Properties.VariableNames, ', '));
    else
        fprintf('  Typ: %s | Größe: %s\n', class(mqttData), mat2str(size(mqttData)));
    end
    fprintf('\n');
end

payload = [];

if isempty(mqttData), return; end

if istable(mqttData)
    % Häufige Spaltennamen beim MATLAB MQTT-Client:
    moeglicheFelder = {'Data','Payload','Message','Body','Value'};
    for k = 1:length(moeglicheFelder)
        if any(strcmp(mqttData.Properties.VariableNames, moeglicheFelder{k}))
            rohwert = mqttData.(moeglicheFelder{k}){1};
            payload = uint8(rohwert(:));
            return;
        end
    end
    % Fallback: letzte Spalte (altes Verhalten)
    payload = uint8(char(mqttData{1, end}));
elseif iscell(mqttData)
    payload = uint8(char(mqttData{end}));
end
end

% ─────────────────────────────────────────────────────────────────────

function session = offlineSessionLaden(cfg)
%OFFLINESESSIONLADEN Liest eine gespeicherte .mat-Session ein.

datei = cfg.offlineFile;
if isempty(datei)
    % Neueste Session-Datei automatisch finden
    dateien = dir('mqtt_session_*.mat');
    if isempty(dateien)
        error('[OFFLINE] Keine mqtt_session_*.mat Datei gefunden.');
    end
    [~, idx] = max([dateien.datenum]);
    datei    = dateien(idx).name;
end

fprintf('[OFFLINE] Lade Session: %s\n', datei);
loaded  = load(datei, 'session');
session = loaded.session;
fprintf('[OFFLINE] %d Pakete geladen.\n\n', length(session.pakete));
end

% ─────────────────────────────────────────────────────────────────────

function analyseProtokolll(session, dbc, C)
%ANALYSEPROTOKOLL Analysiert die Rohdaten und gibt Diagnose-Infos aus.
%
%  Zeigt:
%    1. Paketlängen-Verteilung (kritisch für Protokoll-Verständnis)
%    2. Häufigste Byte[0]-Werte (= wahrscheinliche Signal-IDs oder CAN-IDs)
%    3. Häufigste Byte[1]-Werte pro Byte[0]-Wert
%    4. Cross-Referenz mit DBC (nach CAN-ID und Signal-Index)

pakete = session.pakete;
n      = length(pakete);

fprintf('%s\n', repmat('=', 1, 60));
fprintf('  PROTOKOLL-ANALYSE  (%d Pakete)\n', n);
fprintf('%s\n\n', repmat('=', 1, 60));

% ── 1. Paketlängen ───────────────────────────────────────────────
laengen   = cellfun(@(p) length(p.rawBytes), num2cell(pakete));
uLaengen  = unique(laengen);
fprintf('PAKETLÄNGEN:\n');
for L = uLaengen'
    anzahl = sum(laengen == L);
    fprintf('  %2d Byte : %5d Pakete (%5.1f%%)\n', L, anzahl, 100*anzahl/n);
end
fprintf('\n');

% ── 2. Byte[0]-Verteilung ────────────────────────────────────────
byte0  = cellfun(@(p) double(p.rawBytes(1)), num2cell(pakete));
uB0    = unique(byte0);
fprintf('BYTE[0]-WERTE (top 20 nach Häufigkeit):\n');
fprintf('  %-6s  %-5s  %-8s  %-8s  %s\n', 'HEX', 'DEC', 'Anzahl', 'Anteil', 'DBC-Match?');
fprintf('  %s\n', repmat('-', 1, 55));

zaehler = arrayfun(@(v) sum(byte0 == v), uB0);
[~, ord] = sort(zaehler, 'descend');
uB0_srt  = uB0(ord);
zaehler_srt = zaehler(ord);

limit = min(20, length(uB0_srt));
for k = 1:limit
    v    = uB0_srt(k);
    anz  = zaehler_srt(k);
    ref  = findDBCMatch(v, dbc);
    fprintf('  0x%02X   %-5d  %-8d  %-7.1f%%  %s\n', ...
        v, v, anz, 100*anz/n, ref);
end
fprintf('\n');

% ── 3. Sample-Dump: erste 5 Pakete pro Byte[0] ──────────────────
fprintf('SAMPLE-DUMP (jeweils erstes Paket pro Byte[0]):\n');
fprintf('  %-8s  %-6s  %s\n', 'Zeit [s]', 'B[0]', 'Vollständiger Hex-Dump');
fprintf('  %s\n', repmat('-', 1, 60));

t0       = pakete(1).timestamp;
gezeigte = [];
for k = 1:n
    b0 = double(pakete(k).rawBytes(1));
    if ~ismember(b0, gezeigte)
        dt = seconds(pakete(k).timestamp - t0);
        fprintf('  %-8.2f  0x%02X   %s\n', dt, b0, pakete(k).payloadHex);
        gezeigte(end+1) = b0; %#ok<AGROW>
    end
    if length(gezeigte) >= 30, break; end
end
fprintf('\n');

% ── 4. Zeitlicher Abstand zwischen gleichem Byte[0] ────────────
fprintf('UPDATE-RATEN pro Byte[0] (Durchschnitt):\n');
fprintf('  %-6s  %-5s  %-10s  %s\n', 'HEX', 'DEC', 'Rate [Hz]', 'Δt [ms]');
fprintf('  %s\n', repmat('-', 1, 40));

timestamps = [pakete.timestamp];
for k = 1:min(15, length(uB0_srt))
    v    = uB0_srt(k);
    mask = byte0 == v;
    tSel = timestamps(mask);
    if length(tSel) < 2, continue; end
    dts     = seconds(diff(tSel));
    dts_ms  = mean(dts) * 1000;
    rate_hz = 1 / mean(dts);
    fprintf('  0x%02X   %-5d  %-10.1f  %.1f\n', v, v, rate_hz, dts_ms);
end
fprintf('\n');
end

% ─────────────────────────────────────────────────────────────────────

function ref = findDBCMatch(byte0val, dbc)
%FINDDBCMATCH Versucht, byte0 einer CAN-ID oder einem Signal-Index zuzuordnen.

ref = '(kein Match)';

% ── Versuch 1: direkte CAN-ID ────────────────────────────────────
canIds = [dbc.messages.id];
idx    = find(canIds == byte0val, 1);
if ~isempty(idx)
    ref = sprintf('CAN-Msg: %s (ID=%d)', dbc.messages(idx).name, byte0val);
    return;
end

% ── Versuch 2: Signal-Index (1-basiert, DBC-Reihenfolge) ────────
if byte0val >= 1 && byte0val <= length(dbc.signale)
    s   = dbc.signale(byte0val);
    ref = sprintf('DBC-Sig[%d]: %s', byte0val, s.name);
    return;
end
end

% ─────────────────────────────────────────────────────────────────────

function zeigStatistikFigure(session, dbc, C)
%ZEIGSTATISTIKFIGURE Erstellt eine Dark-Mode Figure mit Protokoll-Statistiken.

pakete  = session.pakete;
n       = length(pakete);
if n == 0, return; end

byte0   = cellfun(@(p) double(p.rawBytes(1)), num2cell(pakete));
uB0     = unique(byte0);
zaehler = arrayfun(@(v) sum(byte0 == v), uB0);
[zaehler_srt, ord] = sort(zaehler, 'descend');
uB0_srt = uB0(ord);

fig = figure('Name', 'RP25e — MQTT Debug Statistik', ...
    'Color', C.BG, 'Position', [80 80 1000 620], ...
    'MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off');

% ── Balkendiagramm: Byte[0]-Häufigkeiten ────────────────────────
axBar = axes(fig, 'Position', [0.05 0.55 0.55 0.38]);
set(axBar, 'Color', C.PANEL, 'XColor', C.WHITE, 'YColor', C.WHITE, ...
    'FontName', 'Consolas', 'FontSize', 8, 'Box', 'off', ...
    'GridColor', [0.25 0.25 0.30], 'YGrid', 'on', 'GridAlpha', 1);

anzeigeLimit = min(20, length(uB0_srt));
xTicks       = 1:anzeigeLimit;
labels       = arrayfun(@(v) sprintf('0x%02X', v), uB0_srt(1:anzeigeLimit), 'UniformOutput', false);

bar(axBar, xTicks, zaehler_srt(1:anzeigeLimit), 'FaceColor', C.BLUE, 'EdgeColor', 'none');
set(axBar, 'XTick', xTicks, 'XTickLabel', labels, 'XTickLabelRotation', 45);
title(axBar, 'Paket-Häufigkeit nach Byte[0]', 'Color', C.WHITE, 'FontSize', 10, 'FontWeight', 'normal');
ylabel(axBar, 'Anzahl', 'Color', C.GRAY);

% ── Paketlängen-Histogramm ───────────────────────────────────────
axLen = axes(fig, 'Position', [0.67 0.55 0.28 0.38]);
set(axLen, 'Color', C.PANEL, 'XColor', C.WHITE, 'YColor', C.WHITE, ...
    'FontName', 'Consolas', 'FontSize', 8, 'Box', 'off', ...
    'GridColor', [0.25 0.25 0.30], 'YGrid', 'on', 'GridAlpha', 1);

laengen = cellfun(@(p) length(p.rawBytes), num2cell(pakete));
histogram(axLen, laengen, 'FaceColor', C.AMBER, 'EdgeColor', 'none');
title(axLen, 'Paketlängen-Verteilung', 'Color', C.WHITE, 'FontSize', 10, 'FontWeight', 'normal');
xlabel(axLen, 'Bytes', 'Color', C.GRAY);
ylabel(axLen, 'Anzahl', 'Color', C.GRAY);

% ── Timeline: Byte[0] über Zeit ─────────────────────────────────
axTime = axes(fig, 'Position', [0.05 0.10 0.90 0.35]);
set(axTime, 'Color', C.PANEL, 'XColor', C.WHITE, 'YColor', C.WHITE, ...
    'FontName', 'Consolas', 'FontSize', 8, 'Box', 'off', ...
    'GridColor', [0.25 0.25 0.30], 'XGrid', 'on', 'YGrid', 'on', 'GridAlpha', 1);
hold(axTime, 'on');

timestamps = [pakete.timestamp];
t0         = timestamps(1);
tSek       = seconds(timestamps - t0);

% Pro ID eine andere Farbe (max 15 IDs)
colormap_ids = [C.GREEN; C.RED; C.AMBER; C.BLUE; C.WHITE; ...
    0.8 0.4 0.9; 0.4 0.9 0.9; 0.9 0.6 0.3; ...
    0.5 0.8 0.5; 0.9 0.4 0.6; 0.6 0.6 0.9; ...
    0.9 0.9 0.4; 0.4 0.7 0.9; 0.9 0.5 0.5; 0.7 0.9 0.7];

legendNames = {};
plotLimit   = min(15, length(uB0_srt));
for k = 1:plotLimit
    v     = uB0_srt(k);
    mask  = byte0 == v;
    col   = colormap_ids(mod(k-1, size(colormap_ids,1))+1, :);
    scatter(axTime, tSek(mask), byte0(mask), 6, col, 'filled', ...
        'MarkerFaceAlpha', 0.6);
    legendNames{k} = sprintf('0x%02X', v);
end

title(axTime, 'Empfangene IDs über Zeit', 'Color', C.WHITE, 'FontSize', 10, 'FontWeight', 'normal');
xlabel(axTime, 'Zeit [s]', 'Color', C.GRAY);
ylabel(axTime, 'Byte[0] Wert', 'Color', C.GRAY);
legend(axTime, legendNames, 'TextColor', C.WHITE, 'Color', C.PANEL, ...
    'EdgeColor', [0.30 0.30 0.35], 'Location', 'eastoutside', 'FontSize', 7);

% ── Titel ────────────────────────────────────────────────────────
annotation(fig, 'textbox', [0 0.94 1 0.06], ...
    'String', sprintf('MQTT DEBUG  |  %d Pakete  |  %d unique IDs  |  %s', ...
    n, length(uB0), datestr(session.startZeit)), ...
    'Color', C.WHITE, 'BackgroundColor', 'none', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
    'FontName', 'Consolas', 'FontSize', 11, 'FontWeight', 'bold');
end

% ─────────────────────────────────────────────────────────────────────

function hexStr = bytes2hex(byteVec)
%BYTES2HEX Konvertiert uint8-Vektor in lesbaren Hex-String ("AA BB CC ...").
hexStr = strjoin(arrayfun(@(b) sprintf('%02X', b), byteVec, 'UniformOutput', false), ' ');
end