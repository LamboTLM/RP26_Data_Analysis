function roh_daten = lade_mdf4(datei_pfad_voll, cfg)
% Laedt MDF4-Datei und validiert Toolbox-Verfuegbarkeit
% Autor: [Benutzer]
% Datum: 2026-06-24

if ~exist('mdfInfo', 'file')
    error('RP:ToolboxFehlt', 'mdfInfo nicht gefunden. Vehicle Network Toolbox erforderlich.');
end
if ~exist('mdfRead', 'file')
    error('RP:ToolboxFehlt', 'mdfRead nicht gefunden. Vehicle Network Toolbox erforderlich.');
end
if ~exist(datei_pfad_voll, 'file')
    error('RP:DateiFehlt', 'Datei nicht gefunden: %s', datei_pfad_voll);
end

try
    roh_daten.info = mdfInfo(datei_pfad_voll);
    roh_daten.kanaele = mdfChannelInfo(datei_pfad_voll);
    roh_daten.daten = mdfRead(datei_pfad_voll);
    fprintf('Datei geladen. Kanaele gefunden: %d\n', height(roh_daten.kanaele));
catch ME
    errordlg(sprintf('Fehler beim Laden:\n%s', ME.message), 'Ladefehler');
    error('RP:LadeFehler', 'MDF4-Laden fehlgeschlagen: %s', ME.message);
end

fprintf('mdfRead Format: %s, Gruppen: %d\n', class(roh_daten.daten), numel(roh_daten.daten));
end