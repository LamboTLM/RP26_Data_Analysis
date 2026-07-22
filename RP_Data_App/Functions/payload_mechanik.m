% =========================================================================
%  payload_mechanik  –  Dateivertrag fuer den Mechanik-Tab
% -------------------------------------------------------------------------
%  Zweck         : Liefert Rohsignale + abgeleitete Mechanik-Groessen:
%                  Bremslinearitaet (Regression p_vorn/p_hinten mit R² und
%                  Hinweis auf den auffaelligen Kreis), rein mechanische
%                  Bremsbalance, Daempfergeschwindigkeit je Ecke (echtes dt aus
%                  der nativen Zeitbasis -> unabhaengig vom x-Modus) und
%                  Roll/Pitch/Heave/Warp aus den vier Rockern.
%
%  EINHEITEN-ANNAHMEN:
%    pbrake_*  -> bar     rocker_* -> mm (Nullpunkt/Skalierung ggf. kalibrieren)
%    Daempfergeschwindigkeit in Rocker-Einheiten pro Sekunde.
%
%  Abhaengigkeiten: payload_envelope, signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function pl = payload_mechanik(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_MECHANIK  pl = PAYLOAD_MECHANIK(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand (Panel-Stubs).
%     2026-07-15  Berechnungen gefuellt: Bremslinearitaet, Balance, Daempfer, RPHW.

    %% Konfiguration
    P_BREMS_MIN = 3;      % bar, ab hier gilt "es wird gebremst"
    P_STUCK     = 1;      % bar, darunter gilt ein Kreis als druecklos
    R2_WARN     = 0.90;   % darunter Hinweis auf gestoerte Linearitaet

    %% Rohsignale (fuers Frontend) -> Envelope
    namen = { 'pbrake_front_can','pbrake_rear_can','brake_balance_front_can', ...
              'rocker_fl_can','rocker_fr_can','rocker_rl_can','rocker_rr_can', ...
              'gas_strut_can' };
    pl = payload_envelope(store, 'mechanik', x, namen);

    %% Vorberechnung: Bremsdruecke auf x
    pv = res(store, x, 'pbrake_front_can');
    ph = res(store, x, 'pbrake_rear_can');

    %% Bremslinearitaet (Regression + R² + auffaelliger Kreis)
    pl.panels.bremslinearitaet = bremslinearitaet(pv, ph, P_BREMS_MIN, P_STUCK, R2_WARN);

    %% Bremsbalance (Front-Anteil waehrend des Bremsens)
    front_anteil = pv ./ (pv + ph);
    front_anteil((pv + ph) < P_BREMS_MIN) = NaN;
    pl.panels.bremsbalance = struct('front_anteil', zeile(front_anteil));

    %% Daempfergeschwindigkeit je Ecke (echtes dt aus nativer Zeitbasis)
    d.fl = zeile(daempfer_geschw(store, 'rocker_fl_can'));
    d.fr = zeile(daempfer_geschw(store, 'rocker_fr_can'));
    d.rl = zeile(daempfer_geschw(store, 'rocker_rl_can'));
    d.rr = zeile(daempfer_geschw(store, 'rocker_rr_can'));
    pl.panels.daempfergeschw = struct('fl', d.fl, 'fr', d.fr, 'rl', d.rl, 'rr', d.rr, ...
                                      'einheit', 'rocker/s');

    %% Roll / Pitch / Heave / Warp (auf x, Rocker-Einheiten)
    fl = res(store, x, 'rocker_fl_can'); fr = res(store, x, 'rocker_fr_can');
    rl = res(store, x, 'rocker_rl_can'); rr = res(store, x, 'rocker_rr_can');
    heave = (fl + fr + rl + rr) / 4;
    roll  = ((fl + rl) - (fr + rr)) / 2;   % links - rechts
    pitch = ((fl + fr) - (rl + rr)) / 2;   % vorn - hinten
    warp  = ((fl + rr) - (fr + rl)) / 2;   % diagonal
    pl.panels.rphw = struct('heave', zeile(heave), 'roll', zeile(roll), ...
                            'pitch', zeile(pitch), 'warp', zeile(warp), 'einheit', 'rocker');
end

% =========================================================================
%  Functions
% =========================================================================

function y = res(store, x, name)
% Signal auf die x-Achse resampeln (NaN wo nicht vorhanden).
    sig = signal_holen(store, name);
    if strcmp(sig.status, 'fehlt') || isempty(sig.t)
        y = nan(size(x.t_ref(:))); return;
    end
    methode = 'linear'; if sig.is_bool, methode = 'previous'; end
    [tu, iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), methode, NaN);
end

function r = bremslinearitaet(pv, ph, p_min, p_stuck, r2_warn)
% Lineare Regression p_hinten = m*p_vorn + b (nur waehrend des Bremsens),
% R², und Heuristik fuer den auffaelligen Kreis.
    r = struct('r2', NaN, 'steigung', NaN, 'achsenabschnitt', NaN, 'auffaelliger_kreis', '');

    gilt = isfinite(pv) & isfinite(ph) & (pv + ph) >= p_min;
    xv = pv(gilt); yv = ph(gilt);
    n  = numel(xv);
    if n < 10, return; end

    sx = sum(xv); sy = sum(yv); sxx = sum(xv.^2); sxy = sum(xv.*yv); syy = sum(yv.^2);
    d  = n*sxx - sx^2;
    if d == 0, return; end
    m  = (n*sxy - sx*sy) / d;
    b  = (sy - m*sx) / n;
    nenner = sqrt(d * (n*syy - sy^2));
    if nenner == 0, return; end
    r.r2 = ((n*sxy - sx*sy) / nenner)^2;
    r.steigung = m;
    r.achsenabschnitt = b;

    % Heuristik: welcher Kreis baut keinen Druck, waehrend der andere bremst?
    if r.r2 < r2_warn
        front_klemmt = mean(xv < p_stuck & yv >= p_min);
        rear_klemmt  = mean(yv < p_stuck & xv >= p_min);
        if front_klemmt > rear_klemmt && front_klemmt > 0.05
            r.auffaelliger_kreis = 'vorn';
        elseif rear_klemmt > front_klemmt && rear_klemmt > 0.05
            r.auffaelliger_kreis = 'hinten';
        else
            r.auffaelliger_kreis = 'unklar';
        end
    end
end

function v = daempfer_geschw(store, name)
% Zeitableitung des Rockers in der nativen Zeitbasis (korrektes dt).
% Rueckgabe: Zeilenvektor aller Geschwindigkeitswerte (fuer das Histogramm).
    sig = signal_holen(store, name);
    if strcmp(sig.status, 'fehlt') || numel(sig.t) < 2
        v = []; return;
    end
    [tu, iu] = unique(sig.t(:));
    yu = sig.value(iu);
    v  = diff(yu) ./ diff(tu);
    v  = v(isfinite(v)).';
end

function z = zeile(v)
% Als Zeilenvektor fuer sauberes JSON.
    z = v(:).';
end