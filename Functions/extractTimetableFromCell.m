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
