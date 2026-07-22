% =========================================================================
%  berechne_x_achse  –  Gemeinsame x-Achse fuer den Run bauen
% -------------------------------------------------------------------------
%  Zweck         : Baut ein uniformes Gitter in Zeit oder Distanz und liefert
%                  zu jedem x-Wert die zugehoerige Zeit (t_ref). Damit koennen
%                  beliebige Signale spaeter per interp1 auf x resampled werden.
%                  Distanz kommt aus dem Geschwindigkeits-Integral (best effort,
%                  INS-Dead-Reckoning-Ersatz), mit Rueckfall auf Zeit.
%  Abhaengigkeiten: signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function x = berechne_x_achse(store, modus, params)
%BERECHNE_X_ACHSE  Erzeugt die gemeinsame x-Achse.
%   x = BERECHNE_X_ACHSE(store, modus, params)
%
%   store  : Signal-Store
%   modus  : 'distanz' | 'zeit'
%   params : Fahrzeugparameter (fuer Einheitenannahmen; siehe fahrzeug_parameter)
%
%   x : struct mit
%       .werte   double-Vektor (Zeit [s] oder Distanz [m])
%       .t_ref   double-Vektor gleicher Laenge: Zeit zu jedem x-Wert
%       .einheit char ('s' | 'm')
%       .modus   char (tatsaechlich verwendeter Modus, ggf. Rueckfall)
%       .status  char ('ok' | 'rueckfall_zeit')
%
%   Changelog:
%     2026-07-15  Erststand.

    %% Konfiguration
    RATE_HZ     = 100;              % Aufloesung des Zeitgitters
    DIST_SCHRITT = 0.5;            % m, Aufloesung des Distanzgitters
    GESCHW_NAME = 'speed_can';     % Referenzsignal fuer die Distanz

    if nargin < 3, params = struct(); end
    if nargin < 2 || isempty(modus), modus = 'zeit'; end

    %% Vorberechnung: gemeinsames Zeitfenster ueber alle Signale
    t_min = 0;
    t_max = max_zeit(store);
    t_gitter = (t_min : 1/RATE_HZ : t_max).';

    %% Berechnung
    switch lower(char(modus))
        case 'zeit'
            x = zeit_achse(t_gitter);

        case 'distanz'
            v_sig = signal_holen(store, GESCHW_NAME);
            if strcmp(v_sig.status, 'gueltig')
                x = distanz_achse(v_sig, t_gitter, DIST_SCHRITT, params);
            else
                % Rueckfall: Geschwindigkeit fehlt/ungueltig -> Zeit
                x = zeit_achse(t_gitter);
                x.status = 'rueckfall_zeit';
            end

        otherwise
            error('berechne_x_achse:Modus', 'Unbekannter Modus: %s', modus);
    end
end

% =========================================================================
%  Functions
% =========================================================================

function tmax = max_zeit(store)
% Groesste Endzeit ueber alle nicht-leeren Signale.
    tmax = 0;
    for i = 1:numel(store)
        if ~isempty(store(i).t)
            tmax = max(tmax, store(i).t(end));
        end
    end
    if tmax == 0, tmax = 1; end   % Schutz vor leerem Store
end

function x = zeit_achse(t_gitter)
% Zeitmodus: x = Zeit, t_ref = identisch.
    x = struct('werte', t_gitter, 't_ref', t_gitter, ...
               'einheit', 's', 'modus', 'zeit', 'status', 'ok');
end

function x = distanz_achse(v_sig, t_gitter, dist_schritt, params)
% Distanzmodus: Strecke aus Geschwindigkeit integrieren, uniformes
% Distanzgitter bauen und dazu die Referenzzeit bestimmen.

    % Geschwindigkeit in m/s bringen (Einheit heuristisch/ueber params)
    v = v_sig.value(:);
    tv = v_sig.t(:);
    v = v .* geschw_faktor(v_sig.unit, params);   % -> m/s
    v = max(v, 0);                                % keine negative Strecke

    % Auf gemeinsames Zeitgitter, dann kumulieren
    v_g   = interp1_sicher(tv, v, t_gitter, 'linear');
    v_g(isnan(v_g)) = 0;
    strecke = cumtrapz(t_gitter, v_g);            % m ueber der Zeit

    % Uniformes Distanzgitter
    d_ende = strecke(end);
    if d_ende <= 0
        x = zeit_achse(t_gitter);
        x.status = 'rueckfall_zeit';
        return;
    end
    d_gitter = (0 : dist_schritt : d_ende).';

    % Zu jeder Distanz die Zeit (Strecke ist monoton steigend)
    [s_u, iu] = unique(strecke);
    t_ref = interp1(s_u, t_gitter(iu), d_gitter, 'linear');

    x = struct('werte', d_gitter, 't_ref', t_ref, ...
               'einheit', 'm', 'modus', 'distanz', 'status', 'ok');
end

function f = geschw_faktor(einheit, params)
% Faktor auf m/s. Bekannt: 'm/s'->1, 'km/h'->1/3.6. Sonst params-Annahme.
    switch lower(strtrim(char(einheit)))
        case {'m/s', 'mps'},  f = 1;
        case {'km/h', 'kph'}, f = 1/3.6;
        otherwise
            if isfield(params, 'log') && isfield(params.log, 'geschw_in_ms')
                f = params.log.geschw_in_ms;   % vom Nutzer gesetzte Annahme
            else
                f = 1;                          % Default: bereits m/s
            end
    end
end

function yq = interp1_sicher(t, y, tq, methode)
% interp1 mit Schutz gegen doppelte/unsortierte Stuetzstellen.
    [tu, iu] = unique(t(:));
    yq = interp1(tu, y(iu), tq, methode, NaN);
end
