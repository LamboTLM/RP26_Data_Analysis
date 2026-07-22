% =========================================================================
%  payload_envelope  –  Gemeinsamer Teil des Dateivertrags (alle Tabs)
% -------------------------------------------------------------------------
%  Zweck         : Baut die Envelope, die JEDE Tab-Payload teilt: Meta-Info,
%                  die gemeinsame x-Achse, die angeforderten Rohsignale (auf x
%                  resampled) und die Health-Liste. Tab-spezifische Auswertungen
%                  haengen die einzelnen payload_<tab>-Functions als .panels an.
%  Abhaengigkeiten: signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% -------------------------------------------------------------------------
%  DATEIVERTRAG (das an die HTML/JS uebergebene struct -> jsonencode):
%    pl.meta.tab       char   Tab-Name
%    pl.meta.x_modus   char   'zeit' | 'distanz'
%    pl.meta.x_einheit char   's' | 'm'
%    pl.x              double x-Achse (Vektor)
%    pl.signals        struct-Array je Signal:
%                        .name (char) .unit (char) .status (char) .y (double)
%                        .y ist auf pl.x resampled; bei status 'fehlt' -> []
%    pl.health         struct-Array: .name (char) .status (char)
%    pl.panels         struct (tab-spezifisch, von payload_<tab> gefuellt)
% =========================================================================

function pl = payload_envelope(store, tab_name, x, signal_namen)
%PAYLOAD_ENVELOPE  Erzeugt den gemeinsamen Payload-Rumpf.
%   pl = PAYLOAD_ENVELOPE(store, tab_name, x, signal_namen)
%
%   store        : Signal-Store
%   tab_name     : char, Name des Tabs
%   x            : x-Achse aus berechne_x_achse
%   signal_namen : cellstr der fuer diesen Tab benoetigten Rohsignale
%
%   Changelog:
%     2026-07-15  Erststand.

    if nargin < 4, signal_namen = {}; end

    %% Meta + x-Achse
    pl = struct();
    pl.meta = struct('tab', char(tab_name), ...
                     'x_modus', x.modus, 'x_einheit', x.einheit);
    pl.x = x.werte(:).';                          % Zeilenvektor -> sauberes JSON

    %% Signale auf die gemeinsame x-Achse bringen
    n = numel(signal_namen);
    signals = repmat(struct('name', '', 'unit', '', 'status', '', 'y', []), n, 1);
    health  = repmat(struct('name', '', 'status', ''), n, 1);

    for i = 1:n
        sig = signal_holen(store, signal_namen{i});
        signals(i).name   = sig.name;
        signals(i).unit   = sig.unit;
        signals(i).status = sig.status;

        if strcmp(sig.status, 'fehlt') || isempty(sig.t)
            signals(i).y = [];                    % bewusst leer, nicht NaN-Dummy
        else
            methode = 'linear';
            if sig.is_bool, methode = 'previous'; end   % Flags nicht interpolieren
            signals(i).y = resample_auf(x.t_ref, sig.t, sig.value, methode);
        end

        health(i).name   = sig.name;
        health(i).status = sig.status;
    end

    pl.signals = signals;
    pl.health  = health;

    %% Platzhalter fuer tab-spezifische Auswertungen
    pl.panels = struct();
end

% =========================================================================
%  Functions
% =========================================================================

function yq = resample_auf(t_ref, t, y, methode)
% Signal (t, y) auf die Referenzzeit t_ref bringen. Doppelte Stuetzstellen
% werden entfernt; ausserhalb -> NaN (im Frontend als Luecke sichtbar).
    [tu, iu] = unique(t(:));
    yq = interp1(tu, y(iu), t_ref(:), methode, NaN);
    yq = yq(:).';                                 % Zeilenvektor fuers JSON
end
