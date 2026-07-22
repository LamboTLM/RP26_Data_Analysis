% =========================================================================
%  load_mf4  –  MF4-Logdatei in einen einheitlichen Signal-Store laden
% -------------------------------------------------------------------------
%  Zweck         : Liest eine .mf4-Datei gruppenweise (eine Zeitbasis je
%                  Kanalgruppe) in ein struct-Array. Jedes Signal traegt
%                  seinen Datenhealth-Status, statt fehlende Werte still zu
%                  NaN zu machen.
%  Abhaengigkeiten: Vehicle Network Toolbox (mdf, channelList, read)
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function [store, log_start] = load_mf4(dateiname, fortschritt_cb)
%LOAD_MF4  Laedt eine MF4-Datei in den Signal-Store.
%   store = LOAD_MF4(dateiname)
%   store = LOAD_MF4(dateiname, fortschritt_cb)
%
%   dateiname      : char/string, Pfad zur .mf4-Datei
%   fortschritt_cb : (optional) function_handle @(anteil, text), anteil 0..1
%
%   store          : struct-Array, ein Eintrag je Signal mit Feldern:
%                    .name (char) .t (double [s]) .value (double)
%                    .unit (char) .subsystem (char) .is_bool (logical)
%                    .gruppe (double) .status (char)
%                    .status in {'gueltig','statisch','nan'}
%                    ('fehlt' entsteht erst beim Zugriff, siehe signal_holen)
%
%   Changelog:
%     2026-07-15  Erststand: gruppenweises Lesen statt Cell-Suche je Signal.

    %% Konfiguration
    NAN_ANTEIL_TOT = 0.999;   % ab diesem NaN-Anteil gilt ein Signal als tot
    if nargin < 2 || isempty(fortschritt_cb)
        fortschritt_cb = @(~, ~) [];   % No-Op, falls kein Callback uebergeben
    end

    %% Eingabepruefung
    if ~(ischar(dateiname) || isstring(dateiname)) || ~isfile(dateiname)
        error('load_mf4:DateiFehlt', 'Datei nicht gefunden: %s', string(dateiname));
    end

    %% Vorberechnungen
    m        = mdf(dateiname);          % MDF-Objekt (schneller als mdfRead)
    log_start = NaT;                    % absoluter Startzeitpunkt (fuer Uhrzeit)
    try, log_start = m.InitialTimestamp; catch, end %#ok<CTCH>
    kanaele  = channelList(m);          % Tabelle aller Kanaele
    gruppen  = unique(kanaele.ChannelGroupNumber);
    n_grp    = numel(gruppen);

    % Store-Vorlage mit fester Feldreihenfolge
    vorlage  = struct('name', '', 't', [], 'value', [], 'unit', '', ...
                      'subsystem', '', 'is_bool', false, 'gruppe', 0, ...
                      'status', '');
    store    = repmat(vorlage, 0, 1);

    %% Berechnung: pro Kanalgruppe einmal lesen
    for gi = 1:n_grp
        g  = gruppen(gi);
        tt = read(m, g);                              % ganze Gruppe = eine Zeitbasis
        t  = seconds(tt.Properties.RowTimes);         % double [s] statt duration
        vars     = tt.Properties.VariableNames;
        einheiten = tt.Properties.VariableUnits;      % ggf. leer

        for k = 1:numel(vars)
            name  = vars{k};
            wert  = double(tt.(name));

            eintrag           = vorlage;
            eintrag.name      = name;
            eintrag.t         = t;
            eintrag.value     = wert;
            eintrag.unit      = einheit_holen(einheiten, k);
            eintrag.subsystem = subsystem_aus_name(name);
            eintrag.is_bool   = ist_boolean(name, wert);
            eintrag.gruppe    = g;
            eintrag.status    = signal_status(wert, NAN_ANTEIL_TOT);

            store(end+1, 1) = eintrag; %#ok<AGROW>  % wenige Gruppen, unkritisch
        end

        fortschritt_cb(gi / n_grp, sprintf('Lade Kanalgruppe %d/%d', gi, n_grp));
    end
end

% =========================================================================
%  Functions
% =========================================================================

function u = einheit_holen(einheiten, k)
% Robust die Einheit zum k-ten Kanal ziehen (VariableUnits kann leer sein).
    if iscell(einheiten) && numel(einheiten) >= k && ~isempty(einheiten{k})
        u = char(einheiten{k});
    else
        u = '';
    end
end

function tf = ist_boolean(name, wert)
% Boolean anhand Namenskonvention (_b_can / _e_b_can) oder Wertebereich {0,1}.
    endet_b = endsWith(name, '_b_can') || endsWith(name, '_b') || contains(name, '_e_b');
    endliche = wert(isfinite(wert));
    nur_01   = ~isempty(endliche) && all(ismember(endliche, [0 1]));
    tf       = endet_b || nur_01;
end

function s = signal_status(wert, nan_anteil_tot)
% Datenhealth eines Signals: 'nan' (tot) | 'statisch' | 'gueltig'.
    if isempty(wert) || mean(isnan(wert)) >= nan_anteil_tot
        s = 'nan';
        return;
    end
    endliche = wert(isfinite(wert));
    if isempty(endliche) || (max(endliche) - min(endliche)) == 0
        s = 'statisch';   % geloggt, aber konstant
    else
        s = 'gueltig';
    end
end
