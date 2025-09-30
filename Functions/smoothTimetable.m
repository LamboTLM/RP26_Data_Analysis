function tt_out = smoothTimetable(tt_in, options)

arguments
    tt_in timetable
    options.Method string {mustBeMember(options.Method, ["movmean", "movmedian", "gaussian", "lowess", "loess", "rlowess", "rloess", "sgolay"])} = "movmean"
    options.WindowSize double {mustBeInteger, mustBePositive} = 5
end

% Eine Kopie der Eingabe-Timetable erstellen, um die Ergebnisse zu speichern
tt_out = tt_in;

% Alle Variablennamen aus der Timetable extrahieren
varNames = tt_in.Properties.VariableNames;

fprintf('Starte Glättungsprozess mit Methode: %s, Fenstergröße: %d\n', options.Method, options.WindowSize);

% --- Durch jede Variable (Spalte) der Timetable iterieren ---
for i = 1:length(varNames)
    varName = varNames{i};

    % Daten aus der aktuellen Spalte extrahieren
    data = tt_in.(varName);

    % Glättungsfunktion auf die Daten anwenden
    smoothed_data = smoothdata(data, options.Method, options.WindowSize);

    % Die geglätteten Daten in der Ausgabe-Timetable speichern
    tt_out.(varName) = smoothed_data;
    fprintf('  - Variable "%s" wurde geglättet.\n', varName);

end

end