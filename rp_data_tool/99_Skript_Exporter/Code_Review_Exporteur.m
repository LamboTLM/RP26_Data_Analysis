%%  CODE REVIEW EXPORTER - Komplett & Robust
%  Packt alle Abhängigkeiten in eine Textdatei

clear; clc; close all;

%% KONFIGURATION
root_script   = 'C:\Users\Danie\OneDrive\Desktop\RP26_Data_Analysis\rp_data_tool\rp_data_tool.m';
export_file   = 'C:\Users\Danie\OneDrive\Desktop\RP26_Data_Analysis\rp_data_tool\Skript_Exporter\code_review_export.txt';
copy_to_clipboard = true;   % true = direkt in Zwischenablage kopieren (Windows)

%% VALIDIERUNG
if ~isfile(root_script)
    error('Hauptskript nicht gefunden:\n%s', root_script);
end

%% ABHÄNGIGKEITEN ERMITTELN
fprintf('Analysiere Abhängigkeiten...\n');
[files, products] = matlab.codetools.requiredFilesAndProducts(root_script);

% Sicherstellen: Spaltenvektor (robust gegen Zeilen-/Spaltenvektor)
files = files(:);

% Root-Script an den Anfang setzen
root_idx = strcmp(files, root_script);
if ~any(root_idx)
    error('Root-Script wurde nicht in den Abhängigkeiten gefunden.');
end
files = [files(root_idx); files(~root_idx)];  % Jetzt funktioniert vertcat!

%% TEXTDATEI SCHREIBEN
fid = fopen(export_file, 'w', 'n', 'UTF-8');
if fid == -1
    error('Konnte Export-Datei nicht erstellen:\n%s', export_file);
end

% Header
fprintf(fid, '============================================================\n');
fprintf(fid, '  MATLAB CODE REVIEW EXPORT\n');
fprintf(fid, '============================================================\n');
fprintf(fid, 'Hauptskript : %s\n', root_script);
fprintf(fid, 'Exportdatum : %s\n', datestr(now, 'dd-mmm-yyyy HH:MM:SS'));
fprintf(fid, 'Anzahl Dateien: %d\n', length(files));
fprintf(fid, '============================================================\n\n');

% Toolboxen
fprintf(fid, '--- BENÖTIGTE PRODUKTE / TOOLBOXEN\n');
if isempty(products)
    fprintf(fid, '  (keine zusätzlichen Produkte erkannt)\n');
else
    for i = 1:length(products)
        fprintf(fid, '  [%d] %s\n', i, products(i).Name);
    end
end
fprintf(fid, '\n');

%% ALLE DATEIEN EINLESEN & SCHREIBEN
total_chars = 0;

for i = 1:length(files)
    [fpath, fname, fext] = fileparts(files{i});
    
    % Trennlinie mit Metadaten
    fprintf(fid, '\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, '  DATEI %d / %d\n', i, length(files));
    fprintf(fid, '  NAME  : %s%s\n', fname, fext);
    fprintf(fid, '  PFAD  : %s\n', files{i});
    fprintf(fid, '============================================================\n\n');
    
    % Inhalt lesen
    try
        content = fileread(files{i});
        fprintf(fid, '%s\n', content);
        total_chars = total_chars + strlength(content);
    catch ME
        fprintf(fid, '*** FEHLER BEIM LESEN: %s ***\n', ME.message);
    end
end

fclose(fid);

%% ZUSAMMENFASSUNG
fprintf('\n============================================================\n');
fprintf('  EXPORT ABGESCHLOSSEN\n');
fprintf('============================================================\n');
fprintf('  Dateien     : %d\n', length(files));
fprintf('  Zeichen     : ~%d\n', total_chars);
fprintf('  Ausgabe     : %s\n', export_file);

%% OPTIONAL: IN ZWISCHENABLAGE KOPIEREN (Windows)
if copy_to_clipboard && ispc
    try
        full_text = fileread(export_file);
        clipboard('copy', full_text);
        fprintf('  Zwischenablage: ✓ Kopiert (Strg+V zum Einfügen)\n');
    catch
        fprintf('  Zwischenablage: ✗ Fehler beim Kopieren\n');
    end
end

fprintf('============================================================\n');