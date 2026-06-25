function signale = extrahiere_signale(roh_daten, cfg)
% Extrahiert definierte Signale aus MDF4-Rohdaten
% Autor: [Benutzer]
% Datum: 2026-06-24

signal_namen = get_signal_liste(cfg);
n_gefunden = 0;

fprintf('  Durchsuche %d Cell-Gruppen nach Signalen...\n', numel(roh_daten.daten));

lookup = containers.Map('KeyType', 'char', 'ValueType', 'any');
for ci = 1:numel(roh_daten.daten)
    tt = roh_daten.daten{ci};
    if ~isa(tt, 'timetable')
        continue;
    end
    spalten = tt.Properties.VariableNames;
    for k = 1:numel(spalten)
        if ~isKey(lookup, spalten{k})
            lookup(spalten{k}) = struct('cell_idx', ci, 'col_name', spalten{k});
        end
    end
end
fprintf('  Lookup fertig: %d eindeutige Spaltennamen.\n', lookup.Count);

for i = 1:numel(signal_namen)
    signal_name = signal_namen{i};
    feld_name = signal_zu_feldname(signal_name);

    if isKey(lookup, signal_name)
        info = lookup(signal_name);
        ci = info.cell_idx;
        col_name = info.col_name;
        try
            tt = roh_daten.daten{ci};
            t_roh = tt.Properties.RowTimes;

            if isa(t_roh, 'duration')
                t_sec = seconds(t_roh - t_roh(1));
            elseif isa(t_roh, 'datetime')
                t_sec = seconds(t_roh - t_roh(1));
            else
                t_sec = double(t_roh) - double(t_roh(1));
            end

            werte = tt.(col_name);
            if ~isa(werte, 'double')
                werte = double(werte);
            end
            if size(werte, 2) > 1
                werte = werte(:, 1);
            end

            signale.(feld_name) = timeseries(werte, t_sec, 'Name', signal_name);
            signale.([feld_name '_ok']) = true;
            n_gefunden = n_gefunden + 1;
        catch ME
            signale.(feld_name) = [];
            signale.([feld_name '_ok']) = false;
            if n_gefunden == 0 && i <= 5
                fprintf('  [ERR] %s: %s\n', signal_name, ME.message);
            end
        end
    else
        signale.(feld_name) = [];
        signale.([feld_name '_ok']) = false;
    end
end

fprintf('  Signale erfolgreich geladen: %d / %d\n', n_gefunden, numel(signal_namen));

% Debug-Ausgabe speed_can
fn_test = 'speed_can';
if isfield(signale, fn_test)
    fprintf('  [DEBUG] speed_can Feld vorhanden, _ok=%d\n', signale.([fn_test '_ok']));
    if signale.([fn_test '_ok'])
        fprintf('  [DEBUG] speed_can: %d Punkte, max=%.2f\n', numel(signale.(fn_test).Data), max(signale.(fn_test).Data));
    end
else
    fprintf('  [DEBUG] speed_can NICHT als Feld in signale vorhanden!\n');
end

% Zeitbasis finden
signale.t_base = [];
signale.t_base_ok = false;
for i = 1:numel(signal_namen)
    fn = signal_zu_feldname(signal_namen{i});
    if isfield(signale, [fn '_ok']) && signale.([fn '_ok'])
        try
            signale.t_base = signale.(fn).Time;
            signale.t_base_ok = true;
            break;
        catch
            % continue
        end
    end
end
end