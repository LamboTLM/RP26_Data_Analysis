% =========================================================================
%  fahrer_fingerprint  –  Fahrstil-Kennzahlen aus einem Run
% -------------------------------------------------------------------------
%  Zweck         : Berechnet aus einem geladenen Run die Fingerprint-Kennzahlen,
%                  die Fahrer beschreiben (nicht die Rundenzeit). Werte sind auf
%                  0..100 normiert, damit Radar und Abstaende vergleichbar sind.
%                  Wird vom Fahrerprofil-Tab (Zuordnung/Anlegen) und spaeter vom
%                  Fahrer-Analyse-Tab genutzt.
%
%  Die NOM_*-Konstanten kalibrieren die Normierung (raw -> 0..100) und koennen
%  an eure Datenlage angepasst werden.
%
%  Abhaengigkeiten: signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function fp = fahrer_fingerprint(store, x, params) %#ok<INUSD>
%FAHRER_FINGERPRINT  fp = FAHRER_FINGERPRINT(store, x, params)
%   fp : struct mit Feldern gas_aggr, vollgas, brems_aggr, trail, lenk,
%        reibkreis, tc, konsistenz  (jeweils 0..100)
%   x wird nicht benoetigt (Rechnung erfolgt in nativer Zeitbasis).
%
%   Changelog:
%     2026-07-15  Erststand.

    %% Konfiguration (Normierungs-Skalen)
    NOM_GAS    = 300;   % %/s   typische max. Gas-Anstiegsrate
    NOM_BREMS  = 200;   % bar/s typische max. Bremsdruck-Anstiegsrate
    NOM_LENK   = 3;     % 1/s   Lenkumkehrungen pro Sekunde
    NOM_REIB   = 15;    % m/s^2 genutzte Kombi-Beschleunigung (~1.5 g)
    NOM_KONSIST= 150;   % %/s   Streuung der Gasrate fuer Konsistenz-Proxy
    GRID_HZ    = 50;    % Hz    gemeinsames Gitter fuer ueberlagerte Groessen
    STEER_MIN  = 5;     % Grad  ab hier gilt "eingelenkt"
    P_BREMS    = 3;     % bar   ab hier gilt "es wird gebremst"

    %% Vorberechnung: gemeinsames Zeitgitter fuer ueberlagerte Metriken
    tg = grid_run(store, {'pbrake_front_can','steering_wheel_angle_can', ...
                          'INS_acc_x_can','INS_acc_y_can'}, GRID_HZ);

    %% Kennzahlen
    % Gasaggressivitaet: 95. Perzentil der Gas-Anstiegsrate
    [ta, va] = sig_prozent(store, 'apps1_can');
    gas_rate = ableitung(ta, va);
    fp.gas_aggr = norm100(q95(abs(gas_rate)), NOM_GAS);

    % Vollgas-Anteil
    fp.vollgas = 100 * anteil(va > 95);

    % Bremsaggressivitaet (trennschaerfstes Merkmal)
    [tp, vp] = sig_native(store, 'pbrake_front_can');
    fp.brems_aggr = norm100(q95(abs(ableitung(tp, vp))), NOM_BREMS);

    % Trail-Braking: Anteil des Bremsens mit gleichzeitigem Lenken
    p_g  = on_grid(store, 'pbrake_front_can', tg, false);
    s_g  = on_grid(store, 'steering_wheel_angle_can', tg, false);
    brems = p_g > P_BREMS;
    fp.trail = 100 * bedingter_anteil(brems, abs(s_g) > STEER_MIN);

    % Lenkaktivitaet: Lenkumkehrungen pro Sekunde
    [ts, vs] = sig_native(store, 'steering_wheel_angle_can');
    fp.lenk = norm100(umkehrungen_pro_s(ts, vs), NOM_LENK);

    % Reibkreis-Ausnutzung: 95. Perzentil der Kombi-Beschleunigung
    ax_g = on_grid(store, 'INS_acc_x_can', tg, false);
    ay_g = on_grid(store, 'INS_acc_y_can', tg, false);
    g_komb = sqrt(ax_g.^2 + ay_g.^2);
    fp.reibkreis = norm100(q95(g_komb), NOM_REIB);

    % TC-Eingriff: Zeitanteil mit aktiver Traktionskontrolle
    [~, vtc] = sig_native(store, 'tqv_status_tc_enabled_b_can');
    if isempty(vtc), fp.tc = 0; else, fp.tc = 100 * anteil(vtc > 0.5); end

    % Konsistenz (Proxy): geringe Streuung der Gasrate -> hohe Konsistenz
    fp.konsistenz = 100 * (1 - min(1, std_omitnan(gas_rate) / NOM_KONSIST));
end

% =========================================================================
%  Functions
% =========================================================================

function [t, v] = sig_native(store, name)
% Signal in nativer Zeitbasis, bereinigt (eindeutige t, endliche Werte).
    sig = signal_holen(store, name);
    if strcmp(sig.status, 'fehlt') || isempty(sig.t)
        t = []; v = []; return;
    end
    [t, iu] = unique(sig.t(:));
    v = sig.value(iu);
    ok = isfinite(t) & isfinite(v);
    t = t(ok); v = v(ok);
end

function [t, v] = sig_prozent(store, name)
% Wie sig_native, aber auf Prozent skaliert (0..1 -> 0..100).
    [t, v] = sig_native(store, name);
    if ~isempty(v) && max(v) <= 1.5, v = v * 100; end
end

function tg = grid_run(store, namen, hz)
% Gemeinsames uniformes Zeitgitter ueber die Spanne der genannten Signale.
    t0 = inf; t1 = -inf;
    for i = 1:numel(namen)
        [t, ~] = sig_native(store, namen{i});
        if ~isempty(t), t0 = min(t0, t(1)); t1 = max(t1, t(end)); end
    end
    if ~isfinite(t0) || t1 <= t0, tg = []; return; end
    tg = (t0 : 1/hz : t1).';
end

function y = on_grid(store, name, tg, is_bool)
% Signal auf das gemeinsame Gitter interpolieren (NaN wo nicht vorhanden).
    if isempty(tg), y = []; return; end
    [t, v] = sig_native(store, name);
    if isempty(t), y = nan(size(tg)); return; end
    methode = 'linear'; if is_bool, methode = 'previous'; end
    y = interp1(t, v, tg, methode, NaN);
end

function d = ableitung(t, v)
% Zeitableitung (native Basis).
    if numel(t) < 2, d = []; return; end
    d = diff(v) ./ diff(t);
    d = d(isfinite(d));
end

function a = anteil(maske)
% Anteil der true-Werte (NaN als false).
    m = maske(:); m(isnan(m)) = 0;
    a = mean(m > 0);
end

function a = bedingter_anteil(bedingung, ereignis)
% Anteil von 'ereignis' unter der Bedingung (P(ereignis|bedingung)).
    b = bedingung(:); e = ereignis(:);
    idx = b & isfinite(e);
    if ~any(idx), a = 0; else, a = mean(e(idx) > 0); end
end

function n = umkehrungen_pro_s(t, v)
% Vorzeichenwechsel der Lenkrate pro Sekunde.
    d = ableitung(t, v);
    if numel(d) < 2 || t(end) <= t(1), n = 0; return; end
    wechsel = sum(diff(sign(d)) ~= 0);
    n = wechsel / (t(end) - t(1));
end

function y = norm100(raw, nom)
% Auf 0..100 gegen eine Nominal-Skala begrenzen.
    if isempty(raw) || ~isfinite(raw), y = 0; else, y = 100 * min(1, max(0, raw / nom)); end
end

function q = q95(v)
% 95. Perzentil ohne Statistics Toolbox.
    v = v(isfinite(v));
    if isempty(v), q = NaN; return; end
    s = sort(v);
    q = s(max(1, min(numel(s), ceil(0.95 * numel(s)))));
end

function s = std_omitnan(v)
    v = v(isfinite(v));
    if numel(v) < 2, s = 0; else, s = std(v); end
end
