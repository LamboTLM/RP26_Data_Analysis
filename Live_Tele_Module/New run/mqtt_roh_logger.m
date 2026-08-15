%% ========================================================================
%  mqtt_roh_logger.m
%
%  Zweck:           Diagnose des Uebertragungsformats der RP25e-Live-Telemetrie.
%                   Empfaengt MQTT-Nachrichten und protokolliert sie
%                   UNINTERPRETIERT in mehreren Darstellungen (Codepoints,
%                   UTF-8-Bytes, Latin-1-Bytes, Hex, ASCII), damit das
%                   tatsaechliche Format bestimmt werden kann.
%                   Es wird bewusst NICHTS dekodiert und NICHTS verworfen.
%  Abhaengigkeiten: Industrial Communication Toolbox (mqttclient),
%                   dbc_parsen.m, roh_erfassen.m, roh_analyse.m,
%                   roh_textdump.m, payload_darstellungen.m, RP25e_CAN1.dbc
%  Autor:           Claude / Dynamics e.V.
%  Datum:           03.08.2026
%
%  Bedienung:
%    1. cfg.dauer_s und cfg.modus einstellen
%    2. Skript starten, waehrend der Messung das GASPEDAL langsam von 0 auf
%       100 % und zurueck bewegen (moeglichst ueber den vollen Weg)
%    3. Danach die erzeugte Datei *_bericht.txt weitergeben
% =========================================================================

%% Konfiguration
cfg = struct();

% --- Verbindung: identisch zum funktionierenden Altskript, nicht aendern ---
cfg.host     = "tcp://mqtt-livetele.dynamics-regensburg.de";
cfg.port     = 1883;                      % [-]
cfg.user     = "liveTele_winApp";
cfg.pass     = "dynamics";
cfg.clientID = "MATLAB_Diag_" + randi(999);
cfg.topic    = "CAN";

% --- Diagnose-Einstellungen ---
cfg.dbc_datei       = "RP25e_CAN1.dbc";
cfg.modus           = "callback";         % "callback" | "polling"
cfg.dauer_s         = 20;                 % Messdauer [s]
cfg.max_nachrichten = 300000;             % Puffergrenze [-]
cfg.fokus_signal    = "apps_res_can";     % Signal fuer Detailauswertung
cfg.max_zeilen_txt  = 3000;               % max. Rohzeilen im Textdump [-]
cfg.ausgabe_ordner  = fullfile(pwd, "telemetrie_diagnose");

% --- Eingangspruefung ---
if ~ismember(cfg.modus, ["callback", "polling"])
    error('mqtt_roh_logger:ModusUngueltig', ...
        'cfg.modus muss "callback" oder "polling" sein.');
end
if exist(cfg.dbc_datei, 'file') ~= 2
    error('mqtt_roh_logger:DbcFehlt', 'DBC nicht gefunden: %s', cfg.dbc_datei);
end
if cfg.dauer_s <= 0
    error('mqtt_roh_logger:DauerUngueltig', 'cfg.dauer_s muss > 0 sein.');
end
if ~isfolder(cfg.ausgabe_ordner)
    mkdir(cfg.ausgabe_ordner);
end

%% Vorberechnungen
fprintf('\n=== RP25e Telemetrie-Rohdiagnose ===\n');
fprintf('Parse DBC: %s\n', cfg.dbc_datei);
dbc = dbc_parsen(cfg.dbc_datei);
fprintf('  %d Nachrichten, %d Signale, %d davon an TELEMETRY_SIGNALS.\n', ...
    numel(dbc.nachrichten), numel(dbc.signale), numel(dbc.telemetrie));

fokus_idx = find(strcmp(dbc.telemetrie_namen, cfg.fokus_signal), 1);
if isempty(fokus_idx)
    warning('Fokussignal "%s" nicht in der Telemetrie-Liste.', cfg.fokus_signal);
else
    fs = dbc.telemetrie(fokus_idx);
    fprintf('  Fokus: %s = Telemetrie-Index %d (%d bit, Faktor %g, Offset %g, %g..%g %s)\n', ...
        fs.name, fokus_idx, fs.laenge_bit, fs.faktor, fs.offset, ...
        fs.minimum, fs.maximum, fs.einheit);
end

%% Berechnung  (Erfassung)
fprintf('\nVerbinde mit %s ...\n', cfg.host);
roh = roh_erfassen(cfg);

if roh.n == 0
    error('mqtt_roh_logger:KeineDaten', ...
        ['Keine Nachrichten empfangen. Verbindung/Topic pruefen, ' ...
         'oder Modus auf "polling" umstellen.']);
end

%% Ausgabe  (Dateien schreiben)
stempel   = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
basisname = fullfile(cfg.ausgabe_ordner, ['telemetrie_roh_' stempel]);
basisname = 'Telemtry_Diagnose';

save([basisname '.mat'], 'roh', 'cfg', '-v7.3');
fprintf('\nRohdaten gespeichert: %s.mat\n', basisname);

bericht = roh_analyse(roh, dbc, cfg, [basisname '_bericht.txt']);

roh_textdump(roh, [basisname '_dump.txt'], cfg.max_zeilen_txt);

fprintf('\nFERTIG. Bitte diese Datei weitergeben:\n   %s_bericht.txt\n', basisname);
fprintf('(Bei Bedarf zusaetzlich: %s_dump.txt)\n\n', basisname);

%% Visualisierung
% bewusst leer: Live-Plot erst nach geklaertem Datenformat

%% Functions
% Ausgelagert in eigene Dateien (bessere Wiederverwendbarkeit):
%   roh_erfassen.m   - Empfang (Callback / Polling)
%   roh_analyse.m    - Hypothesenbewertung
%   roh_textdump.m   - Klartextdump
%   dbc_parsen.m     - DBC-Parser
%   payload_darstellungen.m - Payload in alle Darstellungen
