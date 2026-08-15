function dbc = dbc_parsen(dbc_datei)
% DBC_PARSEN  Liest eine DBC-Datei vollstaendig ein.
%
%   dbc = dbc_parsen(dbc_datei)
%
%   Zweck:           Vollstaendiges Einlesen von Nachrichten und Signalen einer
%                    DBC-Datei als Grundlage fuer die Telemetrie-Diagnose und
%                    das spaetere Live-Tool. Ersetzt den bisherigen
%                    Inline-Parser, der nur Name/Faktor/Offset erfasst hat.
%   Abhaengigkeiten: keine
%   Autor:           Claude / Dynamics e.V.
%   Datum:           03.08.2026
%
%   Eingang:
%     dbc_datei   char/string  Pfad zur .dbc-Datei
%
%   Ausgang (Struct):
%     dbc.nachrichten     Struct-Array: id, name, dlc, sender
%     dbc.signale         Struct-Array: name, nachricht_id, nachricht_name,
%                                       startbit, laenge_bit, byteorder,
%                                       vorzeichen, faktor, offset,
%                                       minimum, maximum, einheit, empfaenger
%     dbc.telemetrie      Struct-Array: Teilmenge der Signale mit Empfaenger
%                                       TELEMETRY_SIGNALS, in DBC-Reihenfolge,
%                                       dedupliziert -> entspricht exakt der
%                                       Indizierung des Altskripts (1..N)
%     dbc.telemetrie_namen Cellstr der Namen (Index = Telemetrie-Index)
%     dbc.datei           verwendeter Pfad
%
%   Changelog:
%     03.08.2026  Erstfassung

%% Konfiguration
if nargin < 1 || isempty(dbc_datei)
    error('dbc_parsen:KeineDatei', 'Pfad zur DBC-Datei fehlt.');
end
dbc_datei = char(dbc_datei);
if exist(dbc_datei, 'file') ~= 2
    error('dbc_parsen:DateiNichtGefunden', 'DBC nicht gefunden: %s', dbc_datei);
end

EMPFAENGER_TELEMETRIE = 'TELEMETRY_SIGNALS';   % Knotenname in der DBC

%% Vorberechnungen
fid = fopen(dbc_datei, 'r', 'n', 'ISO-8859-1');   % DBC ist latin-1, nicht UTF-8
if fid == -1
    error('dbc_parsen:DateiNichtLesbar', 'DBC nicht lesbar: %s', dbc_datei);
end
alle_zeilen = textscan(fid, '%s', 'Delimiter', '\n', 'Whitespace', '');
fclose(fid);
alle_zeilen = alle_zeilen{1};

n_zeilen = numel(alle_zeilen);

nachrichten = struct('id', {}, 'name', {}, 'dlc', {}, 'sender', {});
signale     = struct('name', {}, 'nachricht_id', {}, 'nachricht_name', {}, ...
                     'startbit', {}, 'laenge_bit', {}, 'byteorder', {}, ...
                     'vorzeichen', {}, 'faktor', {}, 'offset', {}, ...
                     'minimum', {}, 'maximum', {}, 'einheit', {}, 'empfaenger', {});

aktuelle_id   = NaN;
aktueller_name = '';

%% Berechnung
for k = 1:n_zeilen
    zeile = strtrim(alle_zeilen{k});
    if isempty(zeile), continue; end

    % --- Nachrichtenkopf: BO_ <id> <name>: <dlc> <sender> ---
    if strncmp(zeile, 'BO_ ', 4)
        tok = regexp(zeile, '^BO_\s+(\d+)\s+(\S+?)\s*:\s*(\d+)\s*(\S*)', 'tokens', 'once');
        if ~isempty(tok)
            aktuelle_id    = str2double(tok{1});
            aktueller_name = tok{2};
            nachrichten(end+1) = struct( ...        %#ok<AGROW>
                'id',     aktuelle_id, ...
                'name',   aktueller_name, ...
                'dlc',    str2double(tok{3}), ...
                'sender', tok{4});
        end
        continue
    end

    % --- Signalzeile: SG_ <name> [Mux] : <start>|<len>@<bo><sgn> (fac,off) [min|max] "unit" Empfaenger ---
    if strncmp(zeile, 'SG_ ', 4)
        tok = regexp(zeile, ...
            ['^SG_\s+(\w+)\s*(?:M|m\d+)?\s*:\s*(\d+)\|(\d+)@(\d)([+-])\s*' ...
             '\(([^,]+),([^)]+)\)\s*\[([^|]*)\|([^\]]*)\]\s*"([^"]*)"\s*(.*)$'], ...
            'tokens', 'once');
        if isempty(tok), continue; end

        signale(end+1) = struct( ...                %#ok<AGROW>
            'name',           tok{1}, ...
            'nachricht_id',   aktuelle_id, ...
            'nachricht_name', aktueller_name, ...
            'startbit',       str2double(tok{2}), ...
            'laenge_bit',     str2double(tok{3}), ...
            'byteorder',      str2double(tok{4}), ...   % 1 = Intel/LE, 0 = Motorola/BE
            'vorzeichen',     tok{5}, ...               % '+' unsigned, '-' signed
            'faktor',         str2double(tok{6}), ...
            'offset',         str2double(tok{7}), ...
            'minimum',        str2double(tok{8}), ...
            'maximum',        str2double(tok{9}), ...
            'einheit',        tok{10}, ...
            'empfaenger',     strtrim(tok{11}));
    end
end

%% Ausgabe
% Telemetrie-Teilmenge in DBC-Reihenfolge, dedupliziert (wie Altskript)
ist_tele = arrayfun(@(s) contains(s.empfaenger, EMPFAENGER_TELEMETRIE), signale);
kandidaten = signale(ist_tele);

gesehen = {};
behalten = false(1, numel(kandidaten));
for k = 1:numel(kandidaten)
    if ~any(strcmp(kandidaten(k).name, gesehen))
        gesehen{end+1} = kandidaten(k).name;   %#ok<AGROW>
        behalten(k) = true;
    end
end

dbc = struct();
dbc.datei             = dbc_datei;
dbc.nachrichten       = nachrichten;
dbc.signale           = signale;
dbc.telemetrie        = kandidaten(behalten);
dbc.telemetrie_namen  = {dbc.telemetrie.name};

end
