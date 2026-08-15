%% ========================================================================
%  mqtt_binaer_test.m
%
%  Zweck:           Empfaengt die RP25e-Telemetrie binaersicher (ohne die
%                   String-Konvertierung der Industrial Communication Toolbox)
%                   und bestimmt automatisch das Frame-Layout, indem mehrere
%                   Kandidaten gegen die CAN-IDs und DLCs der DBC geprueft
%                   werden. Anschliessend wird apps_res_can dekodiert und
%                   zur Kontrolle geplottet.
%  Abhaengigkeiten: MqttBinaerClient.m, dbc_parsen.m, can_signal_lesen.m,
%                   RP25e_CAN1.dbc, tcpclient
%  Autor:           Claude / Dynamics e.V.
%  Datum:           03.08.2026
%
%  Bedienung:
%    Skript starten und waehrend der Messung das GASPEDAL einmal langsam
%    von 0 auf 100 % und zurueck bewegen.
% =========================================================================

%% Konfiguration
cfg = struct();
cfg.host        = "mqtt-livetele.dynamics-regensburg.de";   % ohne "tcp://"
cfg.port        = 1883;
cfg.user        = "liveTele_winApp";
cfg.pass        = "dynamics";
cfg.clientID    = "MATLAB_Bin_" + randi(9999);
cfg.topic       = "CAN";
cfg.dbc_datei   = "RP25e_CAN1.dbc";
cfg.dauer_s     = 20;                 % Messdauer [s]
cfg.max_frames  = 500000;             % Puffergrenze [-]
cfg.fokus_id    = 596;                % VCU_DRIVE_ctrl (0x254)
cfg.fokus_sig   = "apps_res_can";
cfg.dump_datei  = "telemetrie_binaer_dump.txt";
cfg.n_dump      = 400;                % Rohframes im Dump [-]

if exist(cfg.dbc_datei, 'file') ~= 2
    error('mqtt_binaer_test:DbcFehlt', 'DBC nicht gefunden: %s', cfg.dbc_datei);
end

%% Vorberechnungen
fprintf('\n=== RP25e Telemetrie - binaersicherer Empfang ===\n');
dbc = dbc_parsen(cfg.dbc_datei);
bekannte_ids = [dbc.nachrichten.id];
bekannte_dlc = [dbc.nachrichten.dlc];
fprintf('DBC: %d Nachrichten, %d Signale.\n', numel(dbc.nachrichten), numel(dbc.signale));

%% Berechnung  (Erfassung)
mq = MqttBinaerClient(cfg.host, cfg.port, cfg.user, cfg.pass, cfg.clientID);
mq.verbinden();
mq.abonnieren(cfg.topic);
fprintf('Verbunden. Erfasse %g s ...\n', cfg.dauer_s);
fprintf('>>> JETZT das Gaspedal langsam voll durchtreten und wieder loesen! <<<\n');

frames  = cell(cfg.max_frames, 1);
zeiten  = nan(cfg.max_frames, 1);
n       = 0;
uhr     = tic;
letzte  = 0;

while toc(uhr) < cfg.dauer_s
    nachr = mq.empfangen();
    for k = 1:numel(nachr)
        if n >= cfg.max_frames, break; end
        n = n + 1;
        frames{n} = nachr(k).payload;
        zeiten(n) = toc(uhr);
    end
    if isempty(nachr), pause(0.002); end
    if floor(toc(uhr)) > letzte
        letzte = floor(toc(uhr));
        fprintf('  t = %3d s   Frames: %d\n', letzte, n);
    end
end
mq.trennen();

frames = frames(1:n);
zeiten = zeiten(1:n);
if n == 0
    error('mqtt_binaer_test:KeineDaten', 'Keine Nachrichten empfangen.');
end
fprintf('Erfassung beendet: %d Frames in %.1f s (%.0f/s)\n', n, toc(uhr), n / toc(uhr));

%% Ausgabe  (Format bestimmen)
laengen = cellfun(@numel, frames);
fprintf('\n--- Framelaengen (Bytes) ---\n');
[lu, ~, ic] = unique(laengen);
al = accumarray(ic, 1);
for k = 1:numel(lu)
    fprintf('  %3d Byte : %6d  (%.1f %%)\n', lu(k), al(k), 100 * al(k) / n);
end

% Layout-Kandidaten: [Name, ID-Bytes, ID-Reihenfolge, DLC-Position(0=keins), Datenoffset]
kand = struct('name', {}, 'id_n', {}, 'id_le', {}, 'dlc_pos', {}, 'daten_pos', {});
kand(end+1) = struct('name', 'SocketCAN 16B: ID u32LE, DLC@5, Daten@9', ...
    'id_n', 4, 'id_le', true,  'dlc_pos', 5, 'daten_pos', 9);
kand(end+1) = struct('name', 'Kompakt: ID u32LE, DLC@5, Daten@6', ...
    'id_n', 4, 'id_le', true,  'dlc_pos', 5, 'daten_pos', 6);
kand(end+1) = struct('name', 'Ohne DLC: ID u32LE, Daten@5', ...
    'id_n', 4, 'id_le', true,  'dlc_pos', 0, 'daten_pos', 5);
kand(end+1) = struct('name', 'ID u32BE, DLC@5, Daten@6', ...
    'id_n', 4, 'id_le', false, 'dlc_pos', 5, 'daten_pos', 6);
kand(end+1) = struct('name', 'ID u16LE, DLC@3, Daten@4', ...
    'id_n', 2, 'id_le', true,  'dlc_pos', 3, 'daten_pos', 4);
kand(end+1) = struct('name', 'ID u16LE, Daten@3', ...
    'id_n', 2, 'id_le', true,  'dlc_pos', 0, 'daten_pos', 3);

fprintf('\n--- Layout-Hypothesen ---\n');
fprintf('%-42s %10s %10s %10s\n', 'Kandidat', 'ID ok', 'DLC ok', 'Bewertung');
punkte = zeros(numel(kand), 1);
for h = 1:numel(kand)
    id_ok = 0; dlc_ok = 0; gewertet = 0;
    for k = 1:n
        b = frames{k};
        if numel(b) < kand(h).daten_pos - 1, continue; end
        gewertet = gewertet + 1;
        id = bytes_zu_uint(b, 1, kand(h).id_n, kand(h).id_le);
        j  = find(bekannte_ids == id, 1);
        if ~isempty(j)
            id_ok = id_ok + 1;
            if kand(h).dlc_pos > 0 && numel(b) >= kand(h).dlc_pos
                if double(b(kand(h).dlc_pos)) == bekannte_dlc(j)
                    dlc_ok = dlc_ok + 1;
                end
            end
        end
    end
    gewertet = max(gewertet, 1);
    punkte(h) = id_ok / gewertet + (kand(h).dlc_pos > 0) * dlc_ok / gewertet;
    fprintf('%-42s %9.1f%% %9.1f%% %10.2f\n', kand(h).name, ...
        100 * id_ok / gewertet, 100 * dlc_ok / gewertet, punkte(h));
end
[~, best] = max(punkte);
layout = kand(best);
fprintf('\n-> Gewaehltes Layout: %s\n', layout.name);

%% Ausgabe  (IDs im Datenstrom)
ids = nan(n, 1);
for k = 1:n
    b = frames{k};
    if numel(b) >= layout.id_n
        ids(k) = bytes_zu_uint(b, 1, layout.id_n, layout.id_le);
    end
end
[iu, ~, ic2] = unique(ids(~isnan(ids)));
ai = accumarray(ic2, 1);
[~, srt] = sort(ai, 'descend');
fprintf('\n--- Empfangene CAN-IDs ---\n');
fprintf('%8s %8s %8s  %s\n', 'ID dez', 'ID hex', 'Hz', 'Nachricht');
for k = 1:min(numel(srt), 40)
    id = iu(srt(k));
    j  = find(bekannte_ids == id, 1);
    if isempty(j), nm = '(nicht in DBC)'; else, nm = dbc.nachrichten(j).name; end
    fprintf('%8d %8s %8.1f  %s\n', id, sprintf('0x%03X', id), ...
        ai(srt(k)) / toc(uhr), nm);
end

%% Ausgabe  (Fokussignal dekodieren)
sig = [];
for k = 1:numel(dbc.signale)
    if dbc.signale(k).nachricht_id == cfg.fokus_id && ...
            strcmp(dbc.signale(k).name, char(cfg.fokus_sig))
        sig = dbc.signale(k); break
    end
end

t_apps = []; v_apps = [];
if isempty(sig)
    warning('Fokussignal %s in Nachricht %d nicht gefunden.', cfg.fokus_sig, cfg.fokus_id);
else
    fprintf('\n--- %s (ID %d / 0x%03X) ---\n', sig.name, cfg.fokus_id, cfg.fokus_id);
    fprintf('Startbit %d, %d bit, @%d%s, Faktor %g, Offset %g, Bereich %g..%g %s\n', ...
        sig.startbit, sig.laenge_bit, sig.byteorder, sig.vorzeichen, ...
        sig.faktor, sig.offset, sig.minimum, sig.maximum, sig.einheit);

    treffer = find(ids == cfg.fokus_id);
    for k = treffer(:)'
        b = frames{k};
        if numel(b) < layout.daten_pos, continue; end
        d = b(layout.daten_pos:end);
        w = can_signal_lesen(d, sig.startbit, sig.laenge_bit, sig.byteorder, ...
            sig.vorzeichen, sig.faktor, sig.offset);
        if ~isnan(w)
            t_apps(end+1) = zeiten(k);  %#ok<AGROW>
            v_apps(end+1) = w;          %#ok<AGROW>
        end
    end

    if isempty(v_apps)
        fprintf('Keine dekodierbaren Frames fuer dieses Signal.\n');
    else
        fprintf('Frames: %d (%.1f Hz)   Wertebereich: %.2f .. %.2f %s   versch. Werte: %d\n', ...
            numel(v_apps), numel(v_apps) / toc(uhr), min(v_apps), max(v_apps), ...
            sig.einheit, numel(unique(v_apps)));
        if min(v_apps) >= sig.minimum && max(v_apps) <= sig.maximum
            fprintf('-> Werte liegen im DBC-Bereich. Dekodierung plausibel.\n');
        else
            fprintf('-> ACHTUNG: Werte ausserhalb des DBC-Bereichs.\n');
        end
    end
end

%% Ausgabe  (Rohdump zum Weitergeben)
fid = fopen(cfg.dump_datei, 'w');
fprintf(fid, '# Binaerdump RP25e | %d Frames | Layout: %s\n', n, layout.name);
fprintf(fid, '# lfd | t_s | len | ID | Hex\n\n');
for k = 1:min(n, cfg.n_dump)
    fprintf(fid, '%5d %8.4f %3d  %6s  %s\n', k, zeiten(k), numel(frames{k}), ...
        sprintf('0x%03X', ids(k)), strtrim(sprintf('%02X ', frames{k})));
end
fclose(fid);
fprintf('\nRohdump geschrieben: %s\n', cfg.dump_datei);

%% Visualisierung
if ~isempty(v_apps)
    BG    = [0.12 0.12 0.14];
    PANEL = [0.18 0.18 0.21];
    GREEN = [0.20 0.85 0.45];
    WEISS = [0.90 0.90 0.93];

    f = figure('Name', 'apps_res_can - Kontrolle', 'Color', BG, ...
        'NumberTitle', 'off', 'Position', [100 100 900 420]);
    ax = axes(f, 'Color', PANEL, 'XColor', WEISS, 'YColor', WEISS, ...
        'GridColor', [0.3 0.3 0.35], 'GridAlpha', 1, 'Box', 'off', ...
        'FontName', 'Consolas', 'FontSize', 9);
    hold(ax, 'on'); grid(ax, 'on');
    plot(ax, t_apps, v_apps, 'Color', GREEN, 'LineWidth', 1.5);
    ylim(ax, [-5 105]);
    xlabel(ax, 'Zeit [s]', 'Color', WEISS);
    ylabel(ax, 'apps\_res [%]', 'Color', WEISS);
    title(ax, 'Gaspedal - binaersicher dekodiert', 'Color', WEISS, 'FontWeight', 'normal');
end

%% Functions
function v = bytes_zu_uint(b, start, n_byte, ist_le)
% BYTES_ZU_UINT  Liest einen vorzeichenlosen Integer aus einem Bytevektor.
%
%   Changelog:
%     03.08.2026  Erstfassung

    if numel(b) < start + n_byte - 1
        v = NaN; return
    end
    teil = double(b(start:start + n_byte - 1));
    if ~ist_le, teil = fliplr(teil); end
    v = sum(teil .* 256.^(0:n_byte-1));
end
