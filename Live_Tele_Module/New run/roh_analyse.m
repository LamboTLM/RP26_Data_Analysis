function bericht = roh_analyse(roh, dbc, cfg, bericht_datei)
% ROH_ANALYSE  Bewertet mehrere Hypothesen zum Telemetrie-Datenformat.
%
%   bericht = roh_analyse(roh, dbc, cfg, bericht_datei)
%
%   Zweck:           Aus den unveraendert geloggten MQTT-Nachrichten das
%                    tatsaechliche Uebertragungsformat bestimmen. Es werden
%                    mehrere Hypothesen (1-Byte-Wert, 16/32 bit LE/BE, CAN-Frame,
%                    Klartext) gegen die DBC-Wertebereiche geprueft und nach
%                    Plausibilitaet sortiert ausgegeben.
%   Abhaengigkeiten: payload_darstellungen.m, dbc_parsen.m
%   Autor:           Claude / Dynamics e.V.
%   Datum:           03.08.2026
%
%   Kann auch offline genutzt werden:
%     S = load('telemetrie_roh_....mat');
%     roh_analyse(S.roh, dbc_parsen('RP25e_CAN1.dbc'), S.cfg, 'bericht.txt');
%
%   Changelog:
%     03.08.2026  Erstfassung

%% Konfiguration
if nargin < 4 || isempty(bericht_datei)
    bericht_datei = '';
end
n_tele    = numel(dbc.telemetrie);
max_bsp   = 25;      % Beispielzeilen pro Abschnitt [-]

ziele = 1;           % fid-Liste: 1 = Konsole
if ~isempty(bericht_datei)
    fid = fopen(bericht_datei, 'w');
    if fid == -1
        warning('Berichtsdatei nicht schreibbar: %s', bericht_datei);
    else
        ziele(end+1) = fid;
    end
end
p = @(varargin) schreibe(ziele, varargin{:});

%% Vorberechnungen  (alle Payloads einmal umrechnen)
n = roh.n;
codes_alle = cell(n, 1);
bytes_alle = cell(n, 1);
n_codes    = zeros(n, 1);
n_ersatz   = zeros(n, 1);
druckbar   = zeros(n, 1);
max_code   = zeros(n, 1);
numerisch  = false(n, 1);

for k = 1:n
    [c, b, i] = payload_darstellungen(roh.daten{k});
    codes_alle{k} = c;
    bytes_alle{k} = b;
    n_codes(k)    = i.n_codes;
    n_ersatz(k)   = i.n_ersatzzeichen;
    druckbar(k)   = i.anteil_druckbar;
    max_code(k)   = i.max_code;
    numerisch(k)  = i.ist_numerisch;
end

% Latin-1-Bytes: das, was das Altskript per uint8(char(...)) erzeugt
bytes_l1 = cellfun(@(c) uint8(min(c, 255)), codes_alle, 'UniformOutput', false);

%% Ausgabe  Abschnitt 1: Ueberblick
p('\n');
p('========================================================================\n');
p(' RP25e TELEMETRIE - ROHDATEN-BERICHT\n');
p(' Erstellt: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
p(' Empfangsmodus: %s   Dauer: %.1f s   Nachrichten: %d (%.1f/s)\n', ...
    roh.modus, roh.dauer_s, n, n / max(roh.dauer_s, eps));
p(' DBC: %s   Telemetrie-Signale: %d\n', dbc.datei, n_tele);
if ~isempty(roh.spalten_namen)
    p(' Datenquelle-Spalten/Signatur: %s\n', strjoin(string(roh.spalten_namen), ', '));
end
p('========================================================================\n');

%% Abschnitt 2: Transport-Integritaet  (kritisch!)
p('\n--- 1. TRANSPORT-INTEGRITAET ------------------------------------------\n');
p('Payload numerisch geliefert : %d von %d Nachrichten\n', sum(numerisch), n);
p('Nachrichten mit U+FFFD      : %d (%.1f %%)   <- Ersatzzeichen\n', ...
    sum(n_ersatz > 0), 100 * mean(n_ersatz > 0));
p('Max. Codepoint gesamt       : %d\n', max(max_code));
p('Anteil druckbares ASCII     : %.1f %% (Mittel ueber alle Nachrichten)\n', ...
    100 * mean(druckbar, 'omitnan'));
if sum(n_ersatz > 0) > 0
    p('\n  ACHTUNG: U+FFFD gefunden. MATLAB dekodiert die Payload als UTF-8\n');
    p('  und ersetzt ungueltige Bytes. Binaere Werte >= 0x80 gehen damit\n');
    p('  VERLOREN (uint8() macht daraus 255). Das allein erklaert bereits\n');
    p('  statische/unsinnige Signale. Transport muss geaendert werden.\n');
elseif max(max_code) > 255
    p('\n  HINWEIS: Codepoints > 255 vorhanden -> Payload wurde als UTF-8 Text\n');
    p('  interpretiert. Originalbytes stehen in bytes_utf8, nicht in char().\n');
else
    p('\n  OK: alle Codepoints <= 255, keine Ersatzzeichen. Bytes sind intakt.\n');
end

%% Abschnitt 3: Laengenverteilung
p('\n--- 2. NACHRICHTENLAENGE ----------------------------------------------\n');
[laengen_u, ~, ic] = unique(n_codes);
anzahl_l = accumarray(ic, 1);
[~, srt] = sort(anzahl_l, 'descend');
p('%8s %10s %8s\n', 'Laenge', 'Anzahl', 'Anteil');
for k = 1:min(numel(srt), 15)
    j = srt(k);
    p('%8d %10d %7.1f%%\n', laengen_u(j), anzahl_l(j), 100 * anzahl_l(j) / n);
end
if numel(laengen_u) == 1
    p('-> Feste Laenge %d Byte. Bei %d Signalen mit bis zu 32 bit spricht das\n', ...
        laengen_u, n_tele);
    p('   fuer ein festes Rahmenformat [Index | Wert].\n');
else
    p('-> Variable Laenge: deutet auf laengenabhaengige Signalcodierung\n');
    p('   oder auf komplette CAN-Frames hin.\n');
end

%% Abschnitt 4: Klartext-Pruefung
p('\n--- 3. KLARTEXT-PRUEFUNG ----------------------------------------------\n');
if mean(druckbar, 'omitnan') > 0.9
    p('Payload ist ueberwiegend druckbar -> vermutlich Text (JSON/CSV/Hex).\n');
    p('Erste Nachrichten als Text:\n');
    for k = 1:min(n, max_bsp)
        p('  %4d: %s\n', k, char(bytes_l1{k}));
    end
else
    p('Payload ist ueberwiegend binaer (Anteil druckbar %.1f %%).\n', ...
        100 * mean(druckbar, 'omitnan'));
end

%% Abschnitt 5: Beispielnachrichten in allen Darstellungen
p('\n--- 4. BEISPIELNACHRICHTEN (alle Darstellungen) -----------------------\n');
for k = 1:min(n, max_bsp)
    c = codes_alle{k};
    b = bytes_l1{k};
    u = bytes_alle{k};
    p('#%04d t=%7.3f s  n=%d\n', k, roh.t_s(k), numel(c));
    p('      Codepoints : %s\n', strtrim(sprintf('%d ', c)));
    p('      Hex (L1)   : %s\n', strtrim(sprintf('%02X ', b)));
    p('      Hex (UTF8) : %s\n', strtrim(sprintf('%02X ', u)));
    p('      ASCII      : |%s|\n', regexprep(char(b), '[^\x20-\x7E]', '.'));
end

%% Abschnitt 6: Erstes Byte als Signalindex?
p('\n--- 5. ERSTES BYTE ALS SIGNALINDEX ------------------------------------\n');
erste = cellfun(@primaerbyte, bytes_l1);
erste = erste(~isnan(erste));
in_bereich = mean(erste >= 1 & erste <= n_tele);
p('Wertebereich Byte 1 : %d .. %d\n', min(erste), max(erste));
p('Anteil in 1..%d      : %.1f %%\n', n_tele, 100 * in_bereich);
p('Verschiedene Werte  : %d von %d moeglichen Telemetrie-Indizes\n', ...
    numel(unique(erste)), n_tele);

[idx_u, ~, ic2] = unique(erste);
anzahl_i = accumarray(ic2, 1);
[~, srt2] = sort(anzahl_i, 'descend');
p('\nHaeufigste Indizes (mit DBC-Zuordnung):\n');
p('%6s %8s %8s  %-34s %6s %10s %10s\n', 'Index', 'Anzahl', 'Hz', 'Signal (DBC)', 'Bits', 'Min', 'Max');
for k = 1:min(numel(srt2), 30)
    j = idx_u(srt2(k));
    if j >= 1 && j <= n_tele
        s = dbc.telemetrie(j);
        p('%6d %8d %8.1f  %-34s %6d %10g %10g\n', j, anzahl_i(srt2(k)), ...
            anzahl_i(srt2(k)) / max(roh.dauer_s, eps), s.name, s.laenge_bit, ...
            s.minimum, s.maximum);
    else
        p('%6d %8d %8.1f  %-34s\n', j, anzahl_i(srt2(k)), ...
            anzahl_i(srt2(k)) / max(roh.dauer_s, eps), '(ausserhalb der Liste)');
    end
end

fehlend = setdiff(1:n_tele, idx_u);
p('\nNie gesendete Telemetrie-Indizes: %d von %d\n', numel(fehlend), n_tele);
if ~isempty(fehlend) && numel(fehlend) <= 60
    for j = fehlend
        p('   %3d  %s\n', j, dbc.telemetrie(j).name);
    end
end

%% Abschnitt 7: CAN-Frame-Hypothese
p('\n--- 6. HYPOTHESE: KOMPLETTER CAN-FRAME --------------------------------\n');
bekannte_ids = [dbc.nachrichten.id];
treffer = zeros(1, 4);
namen_h = {'ID = uint16 LE (Byte 1-2)', 'ID = uint16 BE (Byte 1-2)', ...
           'ID = uint32 LE (Byte 1-4)', 'ID = uint32 BE (Byte 1-4)'};
for k = 1:n
    b = double(bytes_l1{k});
    if numel(b) >= 2
        treffer(1) = treffer(1) + any(bekannte_ids == b(1) + 256 * b(2));
        treffer(2) = treffer(2) + any(bekannte_ids == b(2) + 256 * b(1));
    end
    if numel(b) >= 4
        treffer(3) = treffer(3) + any(bekannte_ids == b(1) + 256*b(2) + 65536*b(3) + 16777216*b(4));
        treffer(4) = treffer(4) + any(bekannte_ids == b(4) + 256*b(3) + 65536*b(2) + 16777216*b(1));
    end
end
for k = 1:4
    p('%-28s Treffer auf bekannte CAN-IDs: %6d von %d (%.1f %%)\n', ...
        namen_h{k}, treffer(k), n, 100 * treffer(k) / n);
end
if max(treffer) / n > 0.8
    p('-> Sehr wahrscheinlich werden komplette CAN-Frames uebertragen.\n');
else
    p('-> Kein CAN-Frame-Format erkennbar (Indexformat wahrscheinlicher).\n');
end

%% Abschnitt 8: Wert-Hypothesen gegen DBC-Bereiche
p('\n--- 7. WERT-HYPOTHESEN (Byte 1 = Index, Rest = Rohwert) ---------------\n');
p('Bewertung: Anteil der Nachrichten, deren dekodierter Wert im DBC-Bereich liegt.\n');
p('Nur Signale mit gueltigem Bereich (max > min) werden gewertet.\n\n');

hyp = hypothesen_definition();
n_hyp = numel(hyp);
gut = zeros(n_hyp, 1);
gewertet = zeros(n_hyp, 1);

for k = 1:n
    b = double(bytes_l1{k});
    if numel(b) < 2, continue; end
    j = b(1);
    if j < 1 || j > n_tele, continue; end
    s = dbc.telemetrie(j);
    if ~(s.maximum > s.minimum), continue; end
    for h = 1:n_hyp
        roh_wert = hyp(h).fkt(b);
        if isnan(roh_wert), continue; end
        gewertet(h) = gewertet(h) + 1;
        phys = roh_wert * s.faktor + s.offset;
        if phys >= s.minimum - eps && phys <= s.maximum + eps
            gut(h) = gut(h) + 1;
        end
    end
end

quote = 100 * gut ./ max(gewertet, 1);
[~, rang] = sort(quote, 'descend');
p('%-32s %10s %10s %10s\n', 'Hypothese', 'gewertet', 'plausibel', 'Quote');
for k = 1:n_hyp
    h = rang(k);
    p('%-32s %10d %10d %9.1f%%\n', hyp(h).name, gewertet(h), gut(h), quote(h));
end
p('\n-> Die oberste Zeile ist die wahrscheinlichste Wertcodierung.\n');
p('   Achtung: 1-Byte-Hypothesen sind bei kleinen Signalen immer plausibel;\n');
p('   entscheidend ist der Vergleich im Fokus-Abschnitt unten.\n');

%% Abschnitt 9: Fokussignal im Detail
fokus_idx = find(strcmp(dbc.telemetrie_namen, char(cfg.fokus_signal)), 1);
p('\n--- 8. FOKUSSIGNAL: %s ---------------------------\n', char(cfg.fokus_signal));
if isempty(fokus_idx)
    p('Signal nicht in der Telemetrie-Liste gefunden.\n');
else
    s = dbc.telemetrie(fokus_idx);
    p('Telemetrie-Index %d | %d bit %s | Faktor %g | Offset %g | %g..%g %s\n', ...
        fokus_idx, s.laenge_bit, s.vorzeichen, s.faktor, s.offset, ...
        s.minimum, s.maximum, s.einheit);
    p('Rohwertbereich laut Bitbreite: 0 .. %d\n', 2^s.laenge_bit - 1);

    treffer_k = find(erste_index_gleich(bytes_l1, fokus_idx));
    p('Nachrichten mit diesem Index: %d (%.1f Hz)\n', ...
        numel(treffer_k), numel(treffer_k) / max(roh.dauer_s, eps));

    if ~isempty(treffer_k)
        % Byteweise Statistik
        maxlen = max(cellfun(@numel, bytes_l1(treffer_k)));
        p('\nByteweise Statistik ueber diese Nachrichten:\n');
        p('%8s %8s %8s %8s %12s\n', 'Byte', 'Min', 'Max', 'Mittel', 'versch. Werte');
        for bpos = 1:maxlen
            werte = [];
            for k = treffer_k(:)'
                b = bytes_l1{k};
                if numel(b) >= bpos, werte(end+1) = double(b(bpos)); end %#ok<AGROW>
            end
            if isempty(werte), continue; end
            p('%8d %8d %8d %8.1f %12d\n', bpos, min(werte), max(werte), ...
                mean(werte), numel(unique(werte)));
        end

        % Hypothesen konkret durchgerechnet
        p('\nDekodierung nach Hypothese (physikalischer Wertebereich):\n');
        p('%-32s %10s %10s %12s\n', 'Hypothese', 'Min', 'Max', 'versch. Werte');
        for h = 1:n_hyp
            w = [];
            for k = treffer_k(:)'
                r = hyp(h).fkt(double(bytes_l1{k}));
                if ~isnan(r), w(end+1) = r * s.faktor + s.offset; end %#ok<AGROW>
            end
            if isempty(w), continue; end
            marker = '';
            if min(w) >= s.minimum - eps && max(w) <= s.maximum + eps
                marker = '  <= im DBC-Bereich';
            end
            p('%-32s %10.2f %10.2f %12d%s\n', hyp(h).name, min(w), max(w), ...
                numel(unique(w)), marker);
        end

        % Rohverlauf zum Mitlesen
        p('\nErste %d Nachrichten dieses Signals (Hex):\n', min(numel(treffer_k), 60));
        for k = treffer_k(1:min(numel(treffer_k), 60))'
            p('  t=%7.3f  %s\n', roh.t_s(k), strtrim(sprintf('%02X ', bytes_l1{k})));
        end
    end
end

%% Abschnitt 10: Zusammenfassung
p('\n--- 9. ZUSAMMENFASSUNG ------------------------------------------------\n');
p('Bytes intakt          : %s\n', ja_nein(sum(n_ersatz) == 0 && max(max_code) <= 255));
p('Feste Nachrichtenlaenge: %s (%s)\n', ja_nein(numel(laengen_u) == 1), ...
    strtrim(sprintf('%d ', laengen_u(1:min(end, 8)))));
p('Byte 1 plausibel Index : %s (%.1f %% in 1..%d)\n', ...
    ja_nein(in_bereich > 0.95), 100 * in_bereich, n_tele);
p('CAN-Frame-Format       : %s (bester Treffer %.1f %%)\n', ...
    ja_nein(max(treffer) / n > 0.8), 100 * max(treffer) / n);
p('Beste Wertcodierung    : %s (%.1f %%)\n', hyp(rang(1)).name, quote(rang(1)));
p('========================================================================\n\n');

bericht = struct();
bericht.n              = n;
bericht.laengen        = laengen_u;
bericht.index_bereich  = [min(erste) max(erste)];
bericht.hypothesen     = {hyp.name};
bericht.quoten         = quote;
bericht.can_frame      = treffer / n;
bericht.ersatzzeichen  = sum(n_ersatz > 0);

if numel(ziele) > 1
    fclose(ziele(2));
    fprintf('Bericht geschrieben:  %s\n', bericht_datei);
end

end

%% Functions
% -------------------------------------------------------------------------
function hyp = hypothesen_definition()
% HYPOTHESEN_DEFINITION  Liste der geprueften Wertcodierungen.
%   Jede Hypothese bekommt den Bytevektor und liefert den ROHWERT
%   (vor Faktor/Offset) oder NaN, wenn die Nachricht zu kurz ist.
%
%   Changelog:
%     03.08.2026  Erstfassung

    hyp = struct('name', {}, 'fkt', {});
    hyp(end+1) = struct('name', 'B2 = uint8 (aktuelles Skript)', ...
        'fkt', @(b) hole(b, 2, 1, 'le', false));
    hyp(end+1) = struct('name', 'B2-B3 = uint16 LE', ...
        'fkt', @(b) hole(b, 2, 2, 'le', false));
    hyp(end+1) = struct('name', 'B2-B3 = uint16 BE', ...
        'fkt', @(b) hole(b, 2, 2, 'be', false));
    hyp(end+1) = struct('name', 'B2-B3 = int16 LE', ...
        'fkt', @(b) hole(b, 2, 2, 'le', true));
    hyp(end+1) = struct('name', 'B2-B5 = uint32 LE', ...
        'fkt', @(b) hole(b, 2, 4, 'le', false));
    hyp(end+1) = struct('name', 'B2-B5 = uint32 BE', ...
        'fkt', @(b) hole(b, 2, 4, 'be', false));
    hyp(end+1) = struct('name', 'B2-B5 = int32 LE', ...
        'fkt', @(b) hole(b, 2, 4, 'le', true));
    hyp(end+1) = struct('name', 'B3-B2 = uint16 LE (Idx 2 Byte)', ...
        'fkt', @(b) hole(b, 3, 2, 'le', false));
end

% -------------------------------------------------------------------------
function w = hole(b, start, n_byte, ordnung, vorzeichen)
% HOLE  Extrahiert einen Integer-Rohwert aus einem Bytevektor.
%
%   Changelog:
%     03.08.2026  Erstfassung

    if numel(b) < start + n_byte - 1
        w = NaN; return
    end
    teil = double(b(start:start + n_byte - 1));
    if strcmp(ordnung, 'be'), teil = fliplr(teil); end
    w = sum(teil .* 256.^(0:n_byte-1));
    if vorzeichen && w >= 2^(8 * n_byte - 1)
        w = w - 2^(8 * n_byte);
    end
end

% -------------------------------------------------------------------------
function m = erste_index_gleich(bytes_zellen, idx)
% ERSTE_INDEX_GLEICH  Maske: Nachrichten, deren erstes Byte gleich idx ist.
%
%   Changelog:
%     03.08.2026  Erstfassung

    m = cellfun(@(b) ~isempty(b) && double(b(1)) == idx, bytes_zellen);
end

% -------------------------------------------------------------------------
function schreibe(ziele, varargin)
% SCHREIBE  Gibt denselben Text auf Konsole und Berichtsdatei aus.
%
%   Changelog:
%     03.08.2026  Ersetzt die fehlerhafte arrayfun-Variante

    for f = ziele
        fprintf(f, varargin{:});
    end
end

% -------------------------------------------------------------------------
function w = primaerbyte(b)
% PRIMAERBYTE  Erstes Byte einer Nachricht, NaN bei leerer Nachricht.
%
%   Changelog:
%     03.08.2026  Erstfassung

    if isempty(b), w = NaN; else, w = double(b(1)); end
end

% -------------------------------------------------------------------------
function s = ja_nein(tf)
% JA_NEIN  Formatierte Ja/Nein-Ausgabe.
%
%   Changelog:
%     03.08.2026  Erstfassung

    if tf, s = 'JA'; else, s = 'NEIN'; end
end
