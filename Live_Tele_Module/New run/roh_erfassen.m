function roh = roh_erfassen(cfg)
% ROH_ERFASSEN  Empfaengt MQTT-Nachrichten und puffert sie unveraendert.
%
%   roh = roh_erfassen(cfg)
%
%   Zweck:           Verlustfreie Erfassung der Live-Telemetrie zur
%                    Formatdiagnose. In der Erfassungsschleife wird bewusst
%                    NICHTS dekodiert, damit keine Nachricht verloren geht.
%   Abhaengigkeiten: Industrial Communication Toolbox (mqttclient)
%   Autor:           Claude / Dynamics e.V.
%   Datum:           03.08.2026
%
%   Zwei Empfangsmodi (cfg.modus):
%     "callback" - subscribe mit Callback; MATLAB liefert jede Nachricht
%                  einzeln, nichts kann zwischen zwei read() verloren gehen
%     "polling"  - read() in der Schleife; es werden ALLE Zeilen des
%                  zurueckgegebenen Timetables uebernommen. Das bisherige
%                  Skript nahm nur Zeile 1 und verwarf den Rest.
%
%   Ausgang (Struct):
%     roh.n, roh.modus, roh.t_s, roh.topic, roh.daten, roh.extra,
%     roh.spalten_namen, roh.dauer_s, roh.start
%
%   Changelog:
%     03.08.2026  Erstfassung

%% Konfiguration
if ~isfield(cfg, 'modus') || ~ismember(cfg.modus, ["callback", "polling"])
    error('roh_erfassen:ModusUngueltig', 'cfg.modus muss "callback" oder "polling" sein.');
end

puffer_topic  = cell(cfg.max_nachrichten, 1);
puffer_daten  = cell(cfg.max_nachrichten, 1);
puffer_zeit   = nan(cfg.max_nachrichten, 1);
puffer_extra  = cell(cfg.max_nachrichten, 1);
zaehler       = 0;
spalten_namen = {};
uhr           = tic;

%% Berechnung
mq = mqttclient(cfg.host, 'Port', cfg.port, 'Username', cfg.user, ...
    'Password', cfg.pass, 'ClientID', cfg.clientID);

switch cfg.modus
    case "callback"
        subscribe(mq, cfg.topic, 'Callback', @bei_nachricht);
        fprintf('Verbunden (Callback-Modus). Erfasse %g s ...\n', cfg.dauer_s);
        fprintf('>>> JETZT das Gaspedal langsam voll durchtreten und wieder loesen! <<<\n');
        letzte_ausgabe = 0;
        while toc(uhr) < cfg.dauer_s
            pause(0.05);
            if floor(toc(uhr)) > letzte_ausgabe
                letzte_ausgabe = floor(toc(uhr));
                fprintf('  t = %3d s   Nachrichten: %d\n', letzte_ausgabe, zaehler);
            end
        end
        try
            unsubscribe(mq, cfg.topic);
        catch
            % Verbindung wird ohnehin gleich verworfen
        end

    case "polling"
        subscribe(mq, cfg.topic);
        fprintf('Verbunden (Polling-Modus). Erfasse %g s ...\n', cfg.dauer_s);
        fprintf('>>> JETZT das Gaspedal langsam voll durchtreten und wieder loesen! <<<\n');
        letzte_ausgabe = 0;
        while toc(uhr) < cfg.dauer_s
            daten = read(mq);
            if ~isempty(daten)
                if isempty(spalten_namen)
                    spalten_namen = daten.Properties.VariableNames;
                end
                for z = 1:height(daten)
                    if zaehler >= cfg.max_nachrichten, break; end
                    zaehler = zaehler + 1;
                    puffer_zeit(zaehler)  = toc(uhr);
                    puffer_daten{zaehler} = daten{z, end};
                    if width(daten) > 1
                        puffer_topic{zaehler} = daten{z, 1};
                    end
                    puffer_extra{zaehler} = daten(z, :);
                end
            else
                pause(0.002);
            end
            if floor(toc(uhr)) > letzte_ausgabe
                letzte_ausgabe = floor(toc(uhr));
                fprintf('  t = %3d s   Nachrichten: %d\n', letzte_ausgabe, zaehler);
            end
        end
end

dauer = toc(uhr);
clear mq

%% Ausgabe
n = min(zaehler, cfg.max_nachrichten);
roh = struct();
roh.n             = n;
roh.modus         = cfg.modus;
roh.t_s           = puffer_zeit(1:n);
roh.topic         = puffer_topic(1:n);
roh.daten         = puffer_daten(1:n);
roh.extra         = puffer_extra(1:n);
roh.spalten_namen = spalten_namen;
roh.dauer_s       = dauer;
roh.start         = datetime('now');

fprintf('Erfassung beendet: %d Nachrichten in %.1f s (%.1f Nachr./s)\n', ...
    roh.n, roh.dauer_s, roh.n / max(roh.dauer_s, eps));

%% Functions
    function bei_nachricht(varargin)
    % BEI_NACHRICHT  MQTT-Callback, schreibt nur in den Puffer.
        zaehler = zaehler + 1;
        if zaehler > cfg.max_nachrichten, return; end
        puffer_zeit(zaehler) = toc(uhr);
        if numel(varargin) >= 2
            puffer_topic{zaehler} = varargin{1};
            puffer_daten{zaehler} = varargin{2};
        elseif numel(varargin) == 1
            puffer_daten{zaehler} = varargin{1};
        end
        puffer_extra{zaehler} = varargin;
        if isempty(spalten_namen)
            spalten_namen = {sprintf('Callback mit %d Argument(en)', numel(varargin))};
        end
    end
end
