%% rp_data_tool.m
% FSAE Datenanalyse-Tool — Racing Performance Electrical
% Kompatibilitaet: MATLAB R2023b+
%
% Autor:  [Benutzer]
% Datum:  2026-06-24
% Changelog:
%   2026-06-24  Refactoring nach internem Coding-Standard:
%               - Modulare Struktur mit Packages (+config, +io, +signal, etc.)
%               - +RP Plot-Design Integration
%               - Neue Tabs: Bremse-Balance, Efficiency-Map, Compare
%               - INS Dead-Reckoning Fix (cumtrapz, alpha konfigurierbar)
%               - Energieberechnung via trapz
%
% Eingabe:  Keine (Dateiauswahl per Dialog)
% Ausgabe:  uifigure mit Analyse-Tabs

function rp_data_tool()
%% Initialisierung
clc;
cfg = get_config();

fprintf('============================================\n');
fprintf('  RP FSAE Datenanalyse-Tool\n');
fprintf('  Racing Performance — Electrical\n');
fprintf('============================================\n\n');

%% Dateiauswahl
[datei_name, datei_pfad] = uigetfile('*.mf4;*.MF4', 'MDF4 Datei auswaehlen');
if isequal(datei_name, 0)
    fprintf('Kein File gewaehlt. Tool wird beendet.\n');
    return;
end
datei_pfad_voll = fullfile(datei_pfad, datei_name);

% % Log gehardcoded zum schnelleren Debuggen
% datei_name = 'RP25e_2025-09-13_10-37-50_SattlerAccel_Italy.mf4';
% datei_pfad_voll = 'C:\Users\Danie\OneDrive\Desktop\RP26_Data_Analysis\Logging_data\Accels\RP25e_2025-09-13_10-37-50_SattlerAccel_Italy.mf4';
% fprintf('Lade: %s\n', datei_pfad_voll);

%% Laden & Validierung
roh_daten = lade_mdf4(datei_pfad_voll, cfg);

%% Metadaten
meta = parse_dateiname(datei_name, cfg);

%% Signalextraktion
fprintf('Extrahiere Signale...\n');
signale = extrahiere_signale(roh_daten, cfg);
fprintf('Signalextraktion abgeschlossen.\n\n');

%% Abgeleitete Groessen
signale = berechne_abgeleitete(signale, cfg);

%% GUI
erstelle_gui(signale, meta, datei_pfad_voll, cfg);
end