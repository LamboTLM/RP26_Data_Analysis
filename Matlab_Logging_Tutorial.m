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
addpath("Logging_data")
% addpath("Functions") Nur nötig wenn die Functions extern Liegen in diesem
% Testskript werden sie Lokal Functions definiert.

%% Laden der Datei:

% Festelgen wie die Datei Heißt:
Dateiname="RP25e_2025-09-14_14-46-50_driving_FSATA_Endurance.mf4";

% Vorhandene Loggingfiles in diesem Ordner
% Der Rest befindet sich unter \\fs-extern.hs-regensburg.de\dynamics\00 Saisonuebergreifend\17 Logging
% Vom Laufwerk in Matlab Laden dauert ewig! Lokal runterziehen!

% Übermitteln der Daten 
FileInfo = mdfInfo(Dateiname);              % Gibt nur Infos zur Datei, nicht weiter Relevant
Channels = mdfChannelInfo(Dateiname);       % Channels Sagen wo welche Datei liegt.
Data     = mdfRead(Dateiname);              % Hier liegen die Daten versteckt drinnen als Matlab Timetable

%% Abschneiden des Relevanten Zeitbereichs
Time_frame =[447,1028];                                                                     % Eingabe von [t_anf, t_end] in Sekunden
fahrzeitBereich = timerange(seconds(Time_frame(1)), seconds(Time_frame(2)), 'closed');

%% Entschlüsseln der Daten
% Erste komplett eigene Function hier verwendet:
% extractTimetableFromCell sucht anhand des Namens alle Zellen durch und
% findet die zugehörigen Daten. Falls sie die nicht findet werden diese mit
% NaN Belegt damit das skript nicht scheitert. Durchsucht aber alles
% Manuell also nicht besonders Recheneffizient.
% 
% Die Daten werden als Timetable geladen was ein neuers Matlab format ist
% und nicht mit alten Versionen kompatibel ist. 

% Laden der Geschwindigkeit als TimeTable 
speed_can = extractTimetableFromCell(Data,'speed_can');

% Laden des Akkustroms als Timetable
IVT_Result_I_can = extractTimetableFromCell(Data,'IVT_Result_I_can');

% Angleichen der Zeitstrahle (Mit Erklärung)
% Da die Daten von Unterschiedlichen Sensoren mit unterschiedlichen
% Abtaastraten erfasst werden müssen diese erst zu einander Interpoliert
% werden wenn wir damit Rechnen wollen. 
% Großes Fehlerpotenziall bei Falschem Umgang!!!
% Alialising oder andere Messfehler können durch digitale Punkte verborgen
% beliben!!
VehicleData=synchronize(speed_can, IVT_Result_I_can,"union","spline");

% Abschneiden der Daten auf das vorher festgelegte Limit
VehicleData=VehicleData(fahrzeitBereich,:);

%% Einsatz der Daten
% Abrufen muss richtig gemacht werden

whos VehicleDatal.speed_can                 % Einsatz der speed daten
whos VehicleDatal.IVT_Result_I_can          % Einsatz der Akkustrom Daten
whos VehicleDatal.t                         % Einsatz des Zeitdaten

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
