% =========================================================================
%  fahrer_metriken_erweitert  –  Zusaetzliche Fahrer-Klassifizierungs-Kennzahlen
% -------------------------------------------------------------------------
%  Zweck         : Ergaenzt den kanonischen 8er-Fingerprint um trennschaerfere
%                  Kennzahlen, die Fahrer besser quantifizieren/unterscheiden.
%                  Rein zur Anzeige im Fahrer-Tab (kein Profilvergleich) –
%                  wer diese Kennzahlen auch in den Profilvergleich ziehen will,
%                  fuegt die keys zusaetzlich in fahrer_fingerprint.m ein.
%
%  Rueckgabe     : struct mit Feld .gruppen = Cell-Array (JSON-array-sicher) aus
%                  Gruppen {label, metriken:[{key,label,wert(0..100),roh,info}]}
%                  und .werte = struct der normierten 0..100-Werte je key.
%
%  Einheiten     : gas [%], p_v [bar], v [m/s], ax/ay [m/s^2], us_ang [deg]
%
%  Abhaengigkeiten: signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-18
% =========================================================================

function out = fahrer_metriken_erweitert(store, x, ctx, params) %#ok<INUSD>
%FAHRER_METRIKEN_ERWEITERT  out = FAHRER_METRIKEN_ERWEITERT(store, x, ctx, params)
%   Changelog:
%     2026-07-18  Erststand.

    %% Konfiguration – Normierungskonstanten (bei RP26e kalibrieren)
    NOM_P_MAX     = 60;     % bar,   Referenz fuer Bremsspitze
    NOM_P_REL     = 400;    % bar/s, Referenz fuer Brems-Loeserate
    NOM_GAS_RATE  = 300;    % %/s,   Referenz fuer Gas-Aufziehrate
    NOM_LENK_REV  = 1.5;    % 1/s,   Referenz fuer Lenk-Reversals
    NOM_LENK_RATE = 400;    % deg/s, Referenz fuer Lenk-Spitzenrate (Lenkrad)
    NOM_US        = 4;      % deg,   Referenz fuer Untersteuer-Neigung
    NOM_OS        = 4;      % deg,   Referenz fuer Rotations-/Uebersteuer-Neigung
    NOM_LOCK_KM   = 3;      % 1/km,  Referenz fuer Lockup-Neigung
    NOM_G         = 1.6;    % g,     Referenz fuer g-g-Ausnutzung
    P_MIN         = 5;      % bar,   Bremse aktiv
    GAS_MIN       = 3;      % %,     Gas aktiv
    G_KOMB_MIN    = 3/9.81; % g,     Achse "aktiv" (~0.3 g)

    %% Level-basierte Kennzahlen (auf x)
    gas = ctx.gas(:); p_v = ctx.p_v(:); v = ctx.v(:);
    ax  = ctx.ax(:);  ay = ctx.ay(:);  g_komb = ctx.g_komb(:); us = ctx.us_ang(:);
    gate = ctx.gate(:);
    faehrt = v > 3;                                        % rollt ueberhaupt

    pedal_overlap = 100 * mean((gas > GAS_MIN) & (p_v > P_MIN) & faehrt, 'omitnan');
    coasting      = 100 * mean((gas < GAS_MIN) & (p_v < P_MIN) & faehrt, 'omitnan');
    gg_kombiniert = 100 * mean((abs(ax) > 3) & (abs(ay) > 3), 'omitnan');
    gg_ausnutzung = 100 * maxk_mittel(abs(g_komb), 0.10) / NOM_G;

    us_pos = us(gate & us > 0);  us_neg = us(gate & us < 0);
    untersteuer_neig = 100 * mean(us_pos, 'omitnan') / NOM_US;
    rotation_neig    = 100 * mean(-us_neg, 'omitnan') / NOM_OS;

    lock_km = ctx.lockups / max(ctx.strecke_km, 0.05);
    lockup_neig = 100 * lock_km / NOM_LOCK_KM;

    %% Raten-basierte Kennzahlen (native Zeitbasis, x-modus-unabhaengig)
    bremsspitze = 100 * prc(sig_nativ(store,'pbrake_front_can'), 99) / NOM_P_MAX;

    [tb, vb] = sig_nativ(store, 'pbrake_front_can');
    brems_release = 100 * loeserate(tb, vb, P_MIN) / NOM_P_REL;

    [tg, vg] = sig_nativ(store, 'apps1_can');
    gas_on_rate = 100 * aufziehrate(tg, vg) / NOM_GAS_RATE;

    [ts, vs] = sig_nativ(store, 'steering_wheel_angle_can');
    lenk_reversals = 100 * reversal_rate(ts, vs, 5) / NOM_LENK_REV;   % Deadband 5 deg/s
    lenk_spitze    = 100 * spitzenrate(ts, vs) / NOM_LENK_RATE;

    %% Sammeln + auf 0..100 begrenzen
    w = struct( ...
        'bremsspitze',      klemm(bremsspitze), ...
        'brems_release',    klemm(brems_release), ...
        'gas_on_rate',      klemm(gas_on_rate), ...
        'pedal_overlap',    klemm(pedal_overlap), ...
        'coasting',         klemm(coasting), ...
        'lenk_reversals',   klemm(lenk_reversals), ...
        'lenk_spitze',      klemm(lenk_spitze), ...
        'untersteuer_neig', klemm(untersteuer_neig), ...
        'rotation_neig',    klemm(rotation_neig), ...
        'lockup_neig',      klemm(lockup_neig), ...
        'gg_ausnutzung',    klemm(gg_ausnutzung), ...
        'gg_kombiniert',    klemm(gg_kombiniert) );

    %% Anzeige-Gruppen (Cell-Array -> immer JSON-Array)
    g = {};
    g{end+1} = gruppe('Bremsen', { ...
        m('bremsspitze',   w.bremsspitze,   'Bremsspitze',    'Wie hart maximal gebremst wird (99-Perzentil des Vorderdrucks).'), ...
        m('brems_release', w.brems_release, 'Brems-Loeserate', 'Wie schnell die Bremse geloest wird – hoch = abruptes Loesen, niedrig = sauberes Ausrollen.'), ...
        m('lockup_neig',   w.lockup_neig,   'Lockup-Neigung', 'Blockierer pro Kilometer waehrend der Bremsung.') });
    g{end+1} = gruppe('Gas & Pedale', { ...
        m('gas_on_rate',   w.gas_on_rate,   'Gas-Aufziehrate', 'Wie aggressiv nach der Kurve aufs Gas gegangen wird.'), ...
        m('pedal_overlap', w.pedal_overlap, 'Pedal-Overlap',  'Anteil mit gleichzeitig Gas UND Bremse (Left-Foot-Braking / Overlap).'), ...
        m('coasting',      w.coasting,      'Coasting',       'Anteil rollend ohne Gas und ohne Bremse (Zoegern / freies Rollen).') });
    g{end+1} = gruppe('Lenkung', { ...
        m('lenk_reversals',w.lenk_reversals,'Lenk-Reversals', 'Richtungswechsel der Lenkung pro Sekunde – hoch = nervoeses/korrigierendes Lenken.'), ...
        m('lenk_spitze',   w.lenk_spitze,   'Lenk-Spitzenrate','Maximale Lenkgeschwindigkeit – schnelle Einlenkstoesse.') });
    g{end+1} = gruppe('Balance & Grip', { ...
        m('untersteuer_neig', w.untersteuer_neig, 'Untersteuer-Neigung', 'Wie stark der Fahrer im Mittel ins Untersteuern faehrt.'), ...
        m('rotation_neig',    w.rotation_neig,    'Rotation / Uebersteuer','Wie stark der Fahrer das Auto rotieren laesst (Uebersteuer-Anteil).'), ...
        m('gg_ausnutzung',    w.gg_ausnutzung,    'g-g-Ausnutzung',       'Wie nah am kombinierten Grip-Limit gefahren wird (obere 10 %).'), ...
        m('gg_kombiniert',    w.gg_kombiniert,    'Kombinierte g-Nutzung','Anteil mit gleichzeitig Laengs- und Querbeschleunigung (Trail/Combined).') });

    out = struct();
    out.werte   = w;
    out.gruppen = g;   % Dot-Zuweisung: g bleibt Cell (kein struct-Array-Trick)
end

% =========================================================================
%  Functions
% =========================================================================

function [t, v] = sig_nativ(store, name)
% Deduplizierte native Zeitreihe [t, v] oder [] wenn nicht vorhanden.
    sig = signal_holen(store, name);
    if strcmp(sig.status,'fehlt') || numel(sig.t) < 2, t = []; v = []; return; end
    [t, iu] = unique(sig.t(:)); v = sig.value(iu);
end

function p = prc(v, q)
% Perzentil q von v (robust gegen NaN/leer).
    v = v(isfinite(v));
    if isempty(v), p = 0; return; end
    p = prctile(v, q);
end

function r = loeserate(t, v, p_min)
% Typische Brems-Loeserate [bar/s]: Mittel des staerksten Loesens (obere 10 %
%   der negativen Rate) waehrend die Bremse ueber p_min aktiv war.
    r = 0;
    if numel(t) < 3, return; end
    dp = diff(v) ./ diff(t);
    aktiv = v(1:end-1) > p_min;
    neg = -dp(aktiv & dp < 0);          % positive Zahlen = Loesestaerke
    if isempty(neg), return; end
    r = maxk_mittel(neg, 0.10);
end

function r = aufziehrate(t, v)
% Typische Gas-Aufziehrate [%/s]: Mittel der obersten 10 % positiven Raten.
    r = 0;
    if numel(t) < 3, return; end
    dp = diff(v) ./ diff(t);
    pos = dp(dp > 0);
    if isempty(pos), return; end
    r = maxk_mittel(pos, 0.10);
end

function r = spitzenrate(t, v)
% Spitzen-|Rate| [Einheit/s] als 99-Perzentil (robust gegen Ausreisser).
    r = 0;
    if numel(t) < 3, return; end
    r = prc(abs(diff(v) ./ diff(t)), 99);
end

function r = reversal_rate(t, v, deadband_rate)
% Richtungswechsel der Rate pro Sekunde, nur oberhalb eines Deadbands.
    r = 0;
    if numel(t) < 5, return; end
    dt_tot = t(end) - t(1);
    if dt_tot <= 0, return; end
    rate = diff(v) ./ diff(t);
    rate(abs(rate) < deadband_rate) = 0;        % kleines Zittern ignorieren
    s = sign(rate); s = s(s ~= 0);
    if numel(s) < 2, return; end
    wechsel = sum(diff(s) ~= 0);
    r = wechsel / dt_tot;
end

function m = maxk_mittel(v, anteil)
% Mittelwert des obersten Anteils endlicher Werte.
    v = v(isfinite(v));
    if isempty(v), m = 0; return; end
    n = max(1, round(anteil * numel(v)));
    m = mean(maxk(v, n));
end

function y = klemm(x)
% Auf 0..100 begrenzen, NaN -> 0.
    if ~isfinite(x), y = 0; return; end
    y = max(0, min(100, x));
end

function s = m(key, wert, label, info)
% Einzelmetrik-Struct fuer die Anzeige.
    s = struct('key', key, 'label', label, 'wert', wert, ...
               'roh', round(wert), 'info', info);
end

function s = gruppe(label, metriken_cell)
% Gruppen-Struct; metriken als Cell -> JSON-Array.
    s = struct('label', label);
    s.metriken = metriken_cell;    % Dot-Zuweisung haelt Cell
end
