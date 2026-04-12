%% RP25e — MQTT Debug Tool
%  Verbindet sich mit dem Broker, empfängt alle Nachrichten,
%  dekodiert Byte[0] (Signal-Index) + Byte[1] (Rohwert) gegen DBC,
%  und gibt am Ende eine vollständige Statistik aus.
%
%  Einzel-Signal überwachen: cfg.watchSignal = 'apps_res_can'
%  Alle Signale:             cfg.watchSignal = ''

clear; clc;

% =========================================================
%% 1. KONFIGURATION
% =========================================================
cfg.host        = "tcp://mqtt-livetele.dynamics-regensburg.de";
cfg.port        = 1883;
cfg.user        = "liveTele_winApp";
cfg.pass        = "dynamics";
cfg.clientID    = "MATLAB_Debug_" + randi(9999);
cfg.topic       = "CAN";
cfg.dbcFile     = "RP25e_CAN1.dbc";
cfg.captureTime = 30;        % Sekunden — auf inf setzen fuer manuellen Stop
cfg.watchSignal = '';        % z.B. 'apps_res_can' oder '' fuer alle

% =========================================================
%% 2. DBC LADEN — alle Signale, kein Filter
% =========================================================
fprintf('Lade DBC: %s\n', cfg.dbcFile);

% sigMap: Signal-Index (uint32) -> {name, factor, offset, unit}
sigMap   = containers.Map('KeyType','uint32','ValueType','any');
sigIndex = 0;

fid = fopen(cfg.dbcFile, 'r');
if fid == -1, error('DBC nicht gefunden: %s', cfg.dbcFile); end

while ~feof(fid)
    zeile = strtrim(fgetl(fid));
    if ~ischar(zeile), continue; end

    if startsWith(zeile, 'SG_ ') || startsWith(zeile, ' SG_')
        % Format: SG_ name : startBit|len@order(factor,offset) [min|max] "unit" receiver
        tok = regexp(zeile, ...
            'SG_\s+(\S+)\s+[M\s]*:\s*\d+\|\d+@\d+[+-]\s*\(([^,]+),([^)]+)\)\s*\[[^\]]*\]\s*"([^"]*)"', ...
            'tokens');
        if isempty(tok), continue; end

        sigIndex = sigIndex + 1;
        t        = tok{1};
        sigMap(uint32(sigIndex)) = {t{1}, str2double(t{2}), str2double(t{3}), t{4}};
    end
end
fclose(fid);

fprintf('OK — %d Signale geladen (Indices 1 bis %d)\n\n', sigMap.Count, sigIndex);

% =========================================================
%% 3. MQTT VERBINDEN
% =========================================================
fprintf('Verbinde mit %s:%d ...\n', cfg.host, cfg.port);

mq = mqttclient(cfg.host, 'Port', cfg.port, ...
    'Username', cfg.user, 'Password', cfg.pass, 'ClientID', cfg.clientID);
subscribe(mq, cfg.topic);

fprintf('Verbunden. Topic: "%s"\n\n', cfg.topic);

% =========================================================
%% 4. EINZEL-MONITOR VORBEREITEN
% =========================================================
watchIdx = uint32(0);

if ~isempty(cfg.watchSignal)
    for k = 1:sigIndex
        if isKey(sigMap, uint32(k))
            entry = sigMap(uint32(k));
            if strcmp(entry{1}, cfg.watchSignal)
                watchIdx = uint32(k);
                break;
            end
        end
    end

    if watchIdx == 0
        fprintf('[WARN] watchSignal "%s" nicht im DBC gefunden.\n\n', cfg.watchSignal);
    else
        fprintf('── EINZEL-MONITOR: %s (DBC-Index %d) ──\n', cfg.watchSignal, watchIdx);
        fprintf('  %-15s  %-12s  %s\n', 'Zeit', 'Wert', 'Einheit');
        fprintf('  %s\n', repmat('-', 1, 40));
    end
end

% =========================================================
%% 5. STATISTIK-PUFFER INITIALISIEREN
% =========================================================
pktCount   = zeros(sigIndex, 1);    % Anzahl Updates pro Signal
lastVal    = nan(sigIndex, 1);      % letzter dekodierter Wert
minVal     = inf(sigIndex, 1);      % Minimum seit Capture-Start
maxVal     = -inf(sigIndex, 1);     % Maximum seit Capture-Start
firstSeen  = NaT(sigIndex, 1);      % erster Empfangszeitpunkt
lastSeen   = NaT(sigIndex, 1);      % letzter Empfangszeitpunkt

% Unbekannte Byte[0]-Werte (nicht im DBC)
unknownIds = containers.Map('KeyType','uint32','ValueType','uint32');

% =========================================================
%% 6. CAPTURE LOOP
% =========================================================
fprintf('[CAPTURE] Laeuft fuer %g Sekunden ...\n\n', cfg.captureTime);

startZeit = tic;
rateTimer = tic;
pktTotal  = 0;
pktInSek  = 0;

while toc(startZeit) < cfg.captureTime

    data = read(mq);

    if isempty(data)
        pause(0.002);
        continue;
    end

    % read() gibt eine Table mit mehreren Zeilen zurueck — alle verarbeiten
    nZeilen = height(data);

    for i = 1:nZeilen
        bytes = uint8(char(data.Data{i}));

        if length(bytes) < 2, continue; end

        b0   = uint32(bytes(1));    % Signal-Index (Byte 0)
        b1   = double(bytes(2));    % Rohwert      (Byte 1)
        nowT = datetime('now');

        pktTotal = pktTotal + 1;
        pktInSek = pktInSek + 1;

        % ── Bekanntes Signal dekodieren ───────────────────
        if isKey(sigMap, b0)
            entry  = sigMap(b0);
            factor = entry{2};
            offset = entry{3};
            unit   = entry{4};
            val    = b1 * factor + offset;

            pktCount(b0) = pktCount(b0) + 1;
            lastVal(b0)  = val;
            minVal(b0)   = min(minVal(b0),  val);
            maxVal(b0)   = max(maxVal(b0),  val);
            lastSeen(b0) = nowT;
            if isnat(firstSeen(b0))
                firstSeen(b0) = nowT;
            end

            % Einzel-Monitor: nur bei Wert-Aenderung ausgeben
            if b0 == watchIdx
                fprintf('  %-15s  %-12.4f  %s\n', ...
                    datestr(nowT, 'HH:MM:SS.FFF'), val, unit);
            end

        % ── Unbekannter Index ─────────────────────────────
        else
            if isKey(unknownIds, b0)
                unknownIds(b0) = unknownIds(b0) + 1;
            else
                unknownIds(b0) = uint32(1);
            end
        end
    end

    % 1-Hz Status-Ticker
    if toc(rateTimer) >= 1.0
        fprintf('[%5.1fs]  Pakete: %6d  |  Rate: %4d/s  |  Aktive Signale: %d\n', ...
            toc(startZeit), pktTotal, pktInSek, sum(pktCount > 0));
        pktInSek  = 0;
        rateTimer = tic;
    end
end

fprintf('\n[CAPTURE] Beendet — %d Pakete total in %.1fs.\n', pktTotal, toc(startZeit));
clear mq;

% =========================================================
%% 7. KONSOLEN-STATISTIK
% =========================================================
fprintf('\n%s\n', repmat('=', 1, 78));
fprintf('  SIGNAL-STATISTIK  (%.0fs Capture  |  %d Pakete total)\n', ...
    cfg.captureTime, pktTotal);
fprintf('%s\n', repmat('=', 1, 78));
fprintf('  %-4s  %-36s  %7s  %10s  %10s  %10s\n', ...
    'Idx', 'Signal', 'Updates', 'Letzter', 'Min', 'Max');
fprintf('  %s\n', repmat('-', 1, 78));

for k = 1:sigIndex
    if pktCount(k) == 0, continue; end

    entry = sigMap(uint32(k));
    name  = entry{1};
    unit  = entry{4};

    % Langen Namen kuerzen
    if length(name) > 36, name = [name(1:34) '..']; end

    fprintf('  %-4d  %-36s  %7d  %10.4f  %10.4f  %10.4f  %s\n', ...
        k, name, pktCount(k), lastVal(k), minVal(k), maxVal(k), unit);
end

% ── Signale ohne empfangene Daten ────────────────────────
nStill = sum(pktCount == 0);
fprintf('\n  Signale im DBC ohne Daten: %d von %d\n', nStill, sigIndex);

% ── Unbekannte Indices ────────────────────────────────────
if ~isempty(unknownIds)
    fprintf('\n  UNBEKANNTE BYTE[0]-WERTE (nicht im DBC-Index):\n');
    fprintf('  %-6s  %-5s  %s\n', 'HEX', 'DEC', 'Anzahl');
    uKeys = keys(unknownIds);
    for k = 1:length(uKeys)
        v = uKeys{k};
        fprintf('  0x%02X   %-5d  %d\n', v, v, unknownIds(v));
    end
end

fprintf('%s\n', repmat('=', 1, 78));