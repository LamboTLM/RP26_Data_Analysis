%% How to Loggindaten in Matlab.
% Ziel des Skriptes ist es eine kleine einführung zu geben wie Logging
% Daten in Matlab geöfnet werden können.
% Autor: Lambo 
% Datum: 03.04.26
%% Pre Skript
% Alles Löschen und Zumachen
close all;
clear;
clc;
% Hinzufügen des Loggindatenpfades und Function Ordners
addpath("Logging_data/RP26_First_Testday_12_07_26/")
% addpath("Functions") Nur nötig wenn die Functions extern Liegen in diesem
% Testskript werden sie Lokal Functions definiert.
%% Laden der Datei:
% Festelgen wie die Datei Heißt:
Dateiname="RP26ed_2026-07-12_13-41-48_driving.mf4";
% Dateiname = uigetfile;
% Vorhandene Loggingfiles in diesem Ordner
% Der Rest befindet sich unter \\fs-extern.hs-regensburg.de\dynamics\00 Saisonuebergreifend\17 Logging
% Vom Laufwerk in Matlab Laden dauert ewig! Lokal runterziehen!
% Übermitteln der Daten 
FileInfo = mdfInfo(Dateiname);              % Gibt nur Infos zur Datei, nicht weiter Relevant
Channels = mdfChannelInfo(Dateiname);       % Channels Sagen wo welche Datei liegt.
Data     = mdfRead(Dateiname);              % Hier liegen die Daten versteckt drinnen als Matlab Timetable
%% Abschneiden des Relevanten Zeitbereichs
Time_frame =[0,inf];                                                                     % Eingabe von [t_anf, t_end] in Sekunden
fahrzeitBereich = timerange(seconds(Time_frame(1)), seconds(Time_frame(2)), 'closed');
%% Laden der Bremsdrücke als Timetable
% Deine extractTimetableFromCell-Funktion wird verwendet
pbrake_front_can_tt = extractTimetableFromCell(Data, 'pbrake_front_can');
pbrake_rear_can_tt  = extractTimetableFromCell(Data, 'pbrake_rear_can');


%% Test für Michi
VCU_Result_W_moving_avg_can_tt  = extractTimetableFromCell(Data, "VCU_Result_W_moving_avg_can");
IVT_Result_W_can  = extractTimetableFromCell(Data, "IVT_Result_W_can");
speed_can  = extractTimetableFromCell(Data, "speed_can");

tiledlayout(3,1)
ax1 = nexttile;
plot(VCU_Result_W_moving_avg_can_tt.t, VCU_Result_W_moving_avg_can_tt.VCU_Result_W_moving_avg_can)
title ('Moving Avarage')
ax2 = nexttile;
plot(IVT_Result_W_can.t, IVT_Result_W_can.IVT_Result_W_can)
title ('IVT Current')
ax3 = nexttile;
plot(speed_can.t, speed_can.speed_can)
title ('Speed')
linkaxes([ax1 ax2 ax3], 'x')
%% Synchronisation und Filtern
% Da die Signale im CAN-Bus unterschiedliche Zeitstempel haben können, 
% müssen sie auf eine gemeinsame Zeitachse synchronisiert werden.
brake_data = synchronize(pbrake_front_can_tt, pbrake_rear_can_tt, 'intersection', 'linear');
% Umbenennen der Spalten für einfacheres Handling
% (Die Namen hängen davon ab, wie deine Funktion sie ausspuckt, wir greifen auf die Spaltenindizes zu)
P_front_raw = brake_data{:, 1}; 
P_rear_raw  = brake_data{:, 2};
% Filtern auf den relevanten Zeitbereich
brake_data_filtered = brake_data(fahrzeitBereich, :);
P_front = brake_data_filtered{:, 1};
P_rear  = brake_data_filtered{:, 2};
%% Bereinigung und lineare Regression (Fit)
% NaNs entfernen, falls vorhanden, da polyfit sonst fehlschlägt
valid_idx = ~isnan(P_front) & ~isnan(P_rear);
P_front_clean = P_front(valid_idx);
P_rear_clean  = P_rear(valid_idx);
% Linearen Fit (Polynom 1. Grades) erstellen
p_fit = polyfit(P_rear_clean, P_front_clean, 1);
P_front_fitted = polyval(p_fit, P_rear_clean);
% R^2 Wert berechnen
SS_resid = sum((P_front_clean - P_front_fitted).^2);
SS_total = sum((P_front_clean - mean(P_front_clean)).^2);
R_squared = 1 - (SS_resid / SS_total);

%% Plotting (Manuelles High-Contrast Light-Theme für Präsentationen)
% Figur erstellen und Hintergrund explizit weiß setzen
fig = figure('Name', 'Brake Balance Hysterese', 'Color', 'w');
ax = axes('Parent', fig, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
hold(ax, 'on');

% Scatter-Plot: Kräftiges Blau mit leichter Transparenz für die Dichteverteilung
scatter(ax, P_rear_clean, P_front_clean, 15, [0 0.4470 0.7410], 'filled', ...
    'MarkerFaceAlpha', 0.5, 'MarkerEdgeAlpha', 0.5);

% Die gefittete Linie in einem satten Orange-Rot (deutlich sichtbar auf weiß)
plot(ax, P_rear_clean, P_front_fitted, 'Color', [0.8500 0.3250 0.0980], 'LineStyle', '-', 'LineWidth', 3);

% Plot-Beschriftungen anpassen (Schwarz, fettgedruckt und vergrößert für Beamer)
title_str = sprintf('Brake Balance Hysterese (R^2 = %.4f)', R_squared);
title(ax, title_str, 'Color', 'k', 'Interpreter', 'none', 'FontSize', 14, 'FontWeight', 'bold');
xlabel(ax, 'Brake Pressure Rear [bar]', 'Color', 'k', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax, 'Brake Pressure Front [bar]', 'Color', 'k', 'FontSize', 12, 'FontWeight', 'bold');

% Achsenskalierung & Ticks lesbarer machen
ax.FontSize = 11;
ax.LineWidth = 1.5;

% Grid dezent im Hintergrund halten (hellgrau)
grid(ax, 'on');
ax.GridColor = [0.2 0.2 0.2];
ax.GridAlpha = 0.15;

% Textbox für den Fit und R^2 Wert (Weißer Hintergrund mit dünnem schwarzen Rahmen)
fit_eq = sprintf('Fit: y = %.2f * x + %.2f\nR^2 = %.4f', p_fit(1), p_fit(2), R_squared);
text(ax, 0.05, 0.95, fit_eq, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
    'Color', 'k', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'FontSize', 11, 'Margin', 6);

hold(ax, 'off');

%% Functions
function output_tt = extractTimetableFromCell(data, variableName)
% EXTRACTTIMETABLEFROMCELL Durchsucht ein Cell-Array nach einer Timetable mit einer bestimmten Variable.
%
%   output_tt = EXTRACTTIMETABLEFROMCELL(data, variableName)
%
%   data:           Cell-Array, das Timetables enthält.
%   variableName:   String mit dem Namen der Variablen, die du extrahieren möchtest.
%
%   output_tt:      Die extrahierte Timetable, die nur die angegebene Variable und Zeitstempel enthält.
%                   Wenn die Variable nicht gefunden wird, wird eine Dummy-Timetable mit t=1:10 und NaN-Werten zurückgegeben.
%                   Falls die Daten kein double sind, werden sie automatisch nach double konvertiert.
% Initialisiere die Ausgabevariable.
output_tt = timetable();
% Durchlaufe jede Zelle im Cell-Array.
for i = 1:numel(data)
    % Überprüfe, ob die aktuelle Zelle eine Timetable ist und den
    % gewünschten Variablennamen enthält.
    if isa(data{i}, 'timetable') && ismember(variableName, data{i}.Properties.VariableNames)
        % Wenn gefunden, extrahiere die Timetable
        wheelspeed_tt_full = data{i};
        output_tt = wheelspeed_tt_full(:, variableName);
        % Datentyp überprüfen und ggf. nach double konvertieren
        if ~isa(output_tt.(variableName), 'double')
            output_tt.(variableName) = double(output_tt.(variableName));
        end
        return; % Verlasse die Funktion sofort, sobald die Timetable gefunden wurde.
    end
end
% Wenn keine Timetable gefunden wurde -> Dummy-Timetable erzeugen
t = seconds(1:10)';                      % Zeitbasis (Sekunden als duration)
nanValues = nan(length(t), 1);           % Spalte voller NaN
output_tt = timetable(t, nanValues, ...
    'VariableNames', {variableName});
end