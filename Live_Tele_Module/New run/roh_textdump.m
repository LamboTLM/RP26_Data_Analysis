function roh_textdump(roh, dateiname, max_zeilen)
% ROH_TEXTDUMP  Schreibt die Rohnachrichten zeilenweise als Klartext.
%
%   roh_textdump(roh, dateiname, max_zeilen)
%
%   Zweck:           Menschenlesbarer Dump aller empfangenen Nachrichten in
%                    allen Darstellungen, damit das Format per Auge bzw. durch
%                    Weitergabe der Datei geprueft werden kann.
%   Abhaengigkeiten: payload_darstellungen.m
%   Autor:           Claude / Dynamics e.V.
%   Datum:           03.08.2026
%
%   Changelog:
%     03.08.2026  Erstfassung

%% Konfiguration
if nargin < 3 || isempty(max_zeilen)
    max_zeilen = 3000;   % Begrenzung der Dateigroesse [-]
end

n = min(roh.n, max_zeilen);

%% Ausgabe
fid = fopen(dateiname, 'w');
if fid == -1
    error('roh_textdump:DateiNichtSchreibbar', 'Kann %s nicht schreiben.', dateiname);
end

fprintf(fid, '# Rohdump RP25e Telemetrie | Modus: %s | %d von %d Nachrichten\n', ...
    roh.modus, n, roh.n);
fprintf(fid, '# lfd | t_s | n | Codepoints | Hex(Latin1) | Hex(UTF8) | ASCII\n\n');

for k = 1:n
    [codes, bytes_utf8] = payload_darstellungen(roh.daten{k});
    bytes_l1 = uint8(min(codes, 255));
    fprintf(fid, '%6d %8.4f %3d  [%s]  L1: %s  U8: %s  |%s|\n', ...
        k, roh.t_s(k), numel(codes), ...
        strtrim(sprintf('%d ', codes)), ...
        strtrim(sprintf('%02X ', bytes_l1)), ...
        strtrim(sprintf('%02X ', bytes_utf8)), ...
        regexprep(char(bytes_l1), '[^\x20-\x7E]', '.'));
end

fclose(fid);
fprintf('Rohdump geschrieben:  %s\n', dateiname);
end
