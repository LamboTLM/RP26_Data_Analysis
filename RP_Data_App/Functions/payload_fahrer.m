% =========================================================================
%  payload_fahrer  –  Dateivertrag fuer den Fahrer-Analyse-Tab
% -------------------------------------------------------------------------
%  Zweck         : Analysiert das Fahren INNERHALB eines Runs und stellt
%                  Fahrer-Eingaben den Fahrzeug-Reaktionen gegenueber:
%                    - Eingaben (Gas / Bremse / Lenkung)
%                    - Laufende Staerke der Fahrstil-Kennzahlen ueber den Run
%                    - Balance: Untersteuerwinkel, Gierrate Ist vs. Ziel, beta
%                    - Lockups je Ecke waehrend der Bremsung
%                    - TQV-Anforderung gegen reale Lieferung je Ecke (+ Delta)
%                    - TC-Arbeit
%                    - Run-Fingerprint (+ Anlege-Moeglichkeit) und Vergleichs-
%                      profile
%                    - Erweiterte Klassifizierungs-Kennzahlen
%                    - Ereignis-Bereiche (Unter-/Uebersteuern, Lockups) fuer
%                      die farbliche Markierung im Frontend
%
%  Einheiten-Annahmen (gegen echte Logdatei bestaetigen):
%    INS_acc_*  in m/s^2 | INS_ang_vel_z in rad/s | INS_vel_* in m/s
%    steering_wheel_angle in Grad (Lenkrad) | pbrake_* in bar
%    speed_can in m/s (sonst params.log.geschw_in_ms) | slip_compare_* dimlos
%
%  Abhaengigkeiten: payload_envelope, signal_holen, fahrer_fingerprint,
%                   fahrerprofile_laden, fahrer_metriken_erweitert
%  Autor         : <dein Name>
%  Datum         : 2026-07-18
% =========================================================================

function pl = payload_fahrer(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_FAHRER  pl = PAYLOAD_FAHRER(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand (Stub).
%     2026-07-15  Gefuellt: Aktivitaet, TQV I/O, TC, Fingerprint, Vergleich.
%     2026-07-18  Balance (Over/Understeer), Lockups je Ecke, KPI-Leiste,
%                 erweiterte Klassifizierung, Ereignis-Bereiche fuer Highlights.

    %% Konfiguration
    FENSTER_S    = 0.4;    % s,   Glaettungsfenster fuer die laufende Aktivitaet
    V_MIN        = 5.0;    % m/s, unterhalb keine Balance-Aussage (r/v instabil)
    AY_MIN       = 3.0;    % m/s^2 (~0.3 g), Mindest-Querbeschl. fuer Kurvenfahrt
    US_SCHWELLE  = 1.5;    % deg (Reifen), us >  Schwelle => Untersteuern
    OS_SCHWELLE  = -1.5;   % deg (Reifen), us <  Schwelle => Uebersteuern
    P_BREMS_MIN  = 5.0;    % bar, ab hier gilt "es wird gebremst"
    LOCK_SLIP    = 0.15;   % -,   Schlupf < -15 % bei Bremsung => Lockup
    MIN_DAUER_S  = 0.15;   % s,   kuerzere Ereignisse verwerfen
    MAX_LUECKE_S = 0.10;   % s,   kleinere Luecken schliessen

    % Fahrzeug-Parameter (flexible Pfade -> Default; bei RP26e bestaetigen)
    L      = param_wert(params, {'fahrzeug.radstand','geometrie.radstand', ...
                                 'radstand','fahrzeug.wheelbase'}, 1.55);      % m
    i_lenk = param_wert(params, {'lenkung.uebersetzung','lenkuebersetzung', ...
                                 'steering_ratio','i_lenk'}, 4.0);             % -
    dt_s   = median(diff(x.t_ref(:)), 'omitnan');                             % s
    if ~isfinite(dt_s) || dt_s <= 0, dt_s = 0.01; end

    %% Rohsignale (fuers Frontend) -> Envelope
    namen = { ...
        'apps1_can','apps2_can','pbrake_front_can','pbrake_rear_can', ...
        'steering_wheel_angle_can','driver_id_can','speed_can', ...
        'INS_acc_x_can','INS_acc_y_can','INS_ang_vel_z_can', ...
        'INS_vel_x_can','INS_vel_y_can', ...
        'tqv_wantedTq_req', ...
        'tqv_result_fl_can','tqv_result_fr_can','tqv_result_rl_can','tqv_result_rr_can', ...
        'unitek_fl_torque_motor_ist_can','unitek_fr_torque_motor_ist_can', ...
        'unitek_rl_torque_motor_ist_can','unitek_rr_torque_motor_ist_can', ...
        'tqv_status_tc_enabled_b_can','tqv_status_tc_slip_target_can', ...
        'tqv_status_tc_mu_factor_can','tqv_status_tqv_strength_can', ...
        'slip_compare_val_fl_can','slip_compare_val_fr_can', ...
        'slip_compare_val_rl_can','slip_compare_val_rr_can' };
    pl = payload_envelope(store, 'fahrer', x, namen);

    %% Gemeinsame Groessen (auf x resampled, Spalten)
    v     = geschwindigkeit(store, x, params);         % m/s
    ax    = res(store, x, 'INS_acc_x_can');            % m/s^2 (laengs)
    ay    = res(store, x, 'INS_acc_y_can');            % m/s^2 (quer)
    yaw   = res(store, x, 'INS_ang_vel_z_can');        % rad/s (Gierrate Ist)
    delta = deg2rad(res(store, x, 'steering_wheel_angle_can')) ./ i_lenk; % rad (Reifen)
    gas   = res(store, x, 'apps1_can');                % %
    p_v   = res(store, x, 'pbrake_front_can');         % bar
    g_komb = hypot(ax, ay) / 9.81;                     % g (kombiniert)

    %% Laufende Staerke der Kennzahlen ueber den Run
    pl.panels.verlauf = struct( ...
        'gas',       zeile(aktivitaet(store, x, 'apps1_can',              FENSTER_S)), ...
        'brems',     zeile(aktivitaet(store, x, 'pbrake_front_can',       FENSTER_S)), ...
        'lenk',      zeile(aktivitaet(store, x, 'steering_wheel_angle_can', FENSTER_S)), ...
        'reibkreis', zeile(reibkreis(store, x)) );

    %% Balance: Untersteuerwinkel + Gierrate Ist vs. Ziel + Schwimmwinkel
    %  us = delta_Reifen - Ackermann-Lenkwinkel fuer die reale Gierrate
    %       = delta - L*yaw/v   (identisch zu alpha_vorn - alpha_hinten)
    v_eps      = max(v, V_MIN);                         % Schutz gegen /0
    delta_ack  = L .* yaw ./ v_eps;                     % rad
    us_ang     = rad2deg(delta - delta_ack);            % deg (>0 Unter-, <0 Ueber)
    yaw_ist    = rad2deg(yaw);                          % deg/s
    yaw_ziel   = rad2deg(v .* delta ./ L);              % deg/s (Ackermann-Ziel)
    beta       = rad2deg(atan2(res(store,x,'INS_vel_y_can'), ...
                               res(store,x,'INS_vel_x_can'))); % deg (nur bei INS ok)

    gate    = (v > V_MIN) & (abs(ay) > AY_MIN);         % nur echte Kurvenfahrt
    us_mask = gate & (us_ang > US_SCHWELLE);
    os_mask = gate & (us_ang < OS_SCHWELLE);
    us_disp = us_ang; us_disp(~gate) = NaN;             % ausserhalb Kurve keine Aussage

    kurvenzeit = max(sum(gate), 1);
    pl.panels.balance = struct( ...
        'us_winkel',  zeile(us_disp), ...
        'yaw_ist',    zeile(yaw_ist), ...
        'yaw_ziel',   zeile(yaw_ziel), ...
        'beta',       zeile(beta), ...
        'schwelle_us', US_SCHWELLE, 'schwelle_os', OS_SCHWELLE, ...
        'anteil_us',  100 * sum(us_mask) / kurvenzeit, ...
        'anteil_os',  100 * sum(os_mask) / kurvenzeit, ...
        'mittel_us',  mean(us_ang(us_mask), 'omitnan'), ...
        'mittel_os',  mean(us_ang(os_mask), 'omitnan'), ...
        'max_beta',   max(abs(beta), [], 'omitnan') );

    %% Lockups je Ecke (Schlupf stark negativ waehrend Bremsdruck)
    brems_mask = (p_v > P_BREMS_MIN) & (v > V_MIN);
    ecken = {'fl','fr','rl','rr'};
    slip  = struct(); lock = struct(); lock_any = false(size(v));
    for i = 1:numel(ecken)
        s = res(store, x, sprintf('slip_compare_val_%s_can', ecken{i}));
        slip.(ecken{i}) = s;
        lk = brems_mask & (s < -LOCK_SLIP);
        lock.(ecken{i}) = lk;
        lock_any = lock_any | lk;
    end
    worst = min([slip.fl(lock_any); slip.fr(lock_any); ...
                 slip.rl(lock_any); slip.rr(lock_any)], [], 'omitnan');
    if isempty(worst), worst = NaN; end
    ber_lock = struct();
    lock_zahl = 0;
    for i = 1:numel(ecken)
        b = maske_zu_bereichen(lock.(ecken{i}), pl.x, dt_s, MIN_DAUER_S, MAX_LUECKE_S);
        ber_lock.(ecken{i}) = b;
        lock_zahl = lock_zahl + numel(b);
    end
    ber_lock_any = maske_zu_bereichen(lock_any, pl.x, dt_s, MIN_DAUER_S, MAX_LUECKE_S);
    pl.panels.lockups = struct( ...
        'p_brems',  zeile(p_v), ...
        'slip_fl',  zeile(slip.fl), 'slip_fr', zeile(slip.fr), ...
        'slip_rl',  zeile(slip.rl), 'slip_rr', zeile(slip.rr), ...
        'schwelle', -LOCK_SLIP, ...
        'anzahl',   numel(ber_lock_any), ...
        'worst',    worst );

    %% TQV: Anforderung vs. reale Lieferung je Ecke (+ Delta + Eingriff)
    anf = res(store, x, 'tqv_wantedTq_req');
    fl = res(store,x,'unitek_fl_torque_motor_ist_can');
    fr = res(store,x,'unitek_fr_torque_motor_ist_can');
    rl = res(store,x,'unitek_rl_torque_motor_ist_can');
    rr = res(store,x,'unitek_rr_torque_motor_ist_can');
    liefer = struct('fl',zeile(fl),'fr',zeile(fr),'rl',zeile(rl),'rr',zeile(rr));
    delta_tq = struct('fl',zeile(fl-anf),'fr',zeile(fr-anf), ...
                      'rl',zeile(rl-anf),'rr',zeile(rr-anf));
    spread = std([fl fr rl rr], 0, 2, 'omitnan');
    tc_b   = res_bool(store, x, 'tqv_status_tc_enabled_b_can');
    tc_anteil = 100 * mean(tc_b > 0.5, 'omitnan');
    eingriff = struct('tc_anteil', tc_anteil, ...
                      'moment_spread', mean(spread, 'omitnan'));
    pl.panels.tqv = struct('anforderung', zeile(anf), 'lieferung', liefer, ...
                           'delta', delta_tq, 'eingriff', eingriff);

    %% TC-Arbeit
    slip_ist = max(abs([slip.fl, slip.fr, slip.rl, slip.rr]), [], 2);
    pl.panels.tc = struct( ...
        'slip_target', zeile(res(store,x,'tqv_status_tc_slip_target_can')), ...
        'slip_ist',    zeile(slip_ist), ...
        'mu_factor',   zeile(res(store,x,'tqv_status_tc_mu_factor_can')), ...
        'strength',    zeile(res(store,x,'tqv_status_tqv_strength_can')) );

    %% KPI-Leiste (Kurzueberblick oben im Tab)
    reib_nutzung = 100 * mean(maxk_mittel(g_komb, 0.10), 'omitnan') / 1.6; % % von ~1.6 g
    pl.panels.kpi = struct( ...
        'anteil_us',    pl.panels.balance.anteil_us, ...
        'anteil_os',    pl.panels.balance.anteil_os, ...
        'lockups',      pl.panels.lockups.anzahl, ...
        'tc_anteil',    tc_anteil, ...
        'reib_nutzung', reib_nutzung, ...
        'worst_lock',   100 * abs(min(0, worst)) );   % % Schlupf im schlimmsten Lockup

    %% Fingerprint des Runs (kanonische 8 -> Profilvergleich/Radar)
    keys    = {'gas_aggr','vollgas','brems_aggr','trail','lenk','reibkreis','tc','konsistenz'};
    labels  = {'Gasaggr.','Vollgas','Bremsaggr.','Trail-Brake','Lenkaktiv.','Reibkreis','TC-Eingriff','Konsistenz'};
    gewicht = [1,1,2,1,1,1,1,1];
    metriken = struct('key',{},'label',{},'gewicht',{});
    for i=1:numel(keys), metriken(i)=struct('key',keys{i},'label',labels{i},'gewicht',gewicht(i)); end
    fp = fahrer_fingerprint(store, x, params);
    pl.panels.fingerprint = struct('modus','run','kennzahlen',fp,'metriken',metriken);

    %% Erweiterte Klassifizierungs-Kennzahlen (nur Run, Anzeige)
    ber_brems  = maske_zu_bereichen(p_v > P_BREMS_MIN, pl.x, dt_s, MIN_DAUER_S, MAX_LUECKE_S);
    vv = max(v,0); vv(~isfinite(vv)) = 0;
    strecke_m  = trapz(x.t_ref(:), vv);                 % m (v ueber echte Zeit)
    ctx = struct('gas',gas,'p_v',p_v,'v',v,'ax',ax,'ay',ay,'g_komb',g_komb, ...
                 'us_ang',us_ang,'gate',gate,'brems_events',numel(ber_brems), ...
                 'lockups',pl.panels.lockups.anzahl,'strecke_km',strecke_m/1000, ...
                 'dt_s',dt_s);
    pl.panels.klassifizierung = fahrer_metriken_erweitert(store, x, ctx, params);

    %% Ereignis-Bereiche fuer die farbliche Markierung (JSON-array-sicher: Cells)
    pl.panels.ereignisse = struct( ...
        'untersteuern', {maske_zu_bereichen(us_mask, pl.x, dt_s, MIN_DAUER_S, MAX_LUECKE_S)}, ...
        'uebersteuern', {maske_zu_bereichen(os_mask, pl.x, dt_s, MIN_DAUER_S, MAX_LUECKE_S)}, ...
        'lockup_any',   {ber_lock_any}, ...
        'lockup_fl',    {ber_lock.fl}, 'lockup_fr', {ber_lock.fr}, ...
        'lockup_rl',    {ber_lock.rl}, 'lockup_rr', {ber_lock.rr} );

    %% Hinterlegte Profile zum Vergleich (Radar-Overlay im Frontend)
    profile = fahrerprofile_laden(feld(params, 'profil_datei', ''));
    verg = struct('name',{},'werte',{});
    for i=1:numel(profile)
        verg(i) = struct('name',profile(i).name,'werte',fp_zu_vektor(profile(i).kennzahlen,keys));
    end
    pl.panels.vergleich = struct('profile', verg);
end

% =========================================================================
%  Functions
% =========================================================================

function y = res(store, x, name)
% Analogsignal auf die x-Achse resampeln (NaN wo nicht vorhanden). Spalte.
    sig = signal_holen(store, name);
    if strcmp(sig.status,'fehlt') || isempty(sig.t), y = nan(size(x.t_ref(:))); return; end
    [tu,iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), 'linear', NaN);
end

function y = res_bool(store, x, name)
% Boolean/Flag auf die x-Achse (Halten des letzten Werts).
    sig = signal_holen(store, name);
    if strcmp(sig.status,'fehlt') || isempty(sig.t), y = nan(size(x.t_ref(:))); return; end
    [tu,iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), 'previous', NaN);
end

function y = aktivitaet(store, x, name, fenster_s)
% Laufende Staerke: |Rate| in nativer Zeitbasis, geglaettet, auf x resampled.
    sig = signal_holen(store, name);
    if strcmp(sig.status,'fehlt') || numel(sig.t) < 3, y = nan(size(x.t_ref(:))); return; end
    [tu,iu] = unique(sig.t(:)); v = sig.value(iu);
    rate = abs(diff(v) ./ diff(tu));
    tm   = (tu(1:end-1) + tu(2:end)) / 2;
    dtm  = median(diff(tu)); n = max(1, round(fenster_s / max(dtm, eps)));
    rate = movmean(rate, n);
    y = interp1(tm, rate, x.t_ref(:), 'linear', NaN);
end

function y = reibkreis(store, x)
% Kombi-Beschleunigung sqrt(ax^2+ay^2) auf x (kein Zeit-dt noetig).
    ax = res(store, x, 'INS_acc_x_can');
    ay = res(store, x, 'INS_acc_y_can');
    y  = sqrt(ax.^2 + ay.^2);
end

function v = geschwindigkeit(store, x, params)
% Robuste Fahrzeuggeschwindigkeit in m/s: speed_can bevorzugt, sonst INS_vel_x.
    v = res(store, x, 'speed_can');
    in_ms = feld(feld(params,'log',struct()), 'geschw_in_ms', true);
    if ~in_ms, v = v / 3.6; end          % km/h -> m/s falls konfiguriert
    if all(isnan(v)), v = res(store, x, 'INS_vel_x_can'); end
    v = abs(v);
end

function m = maxk_mittel(v, anteil)
% Mittelwert des obersten Anteils (z.B. 0.10 = obere 10 %) endlicher Werte.
    v = v(isfinite(v));
    if isempty(v), m = NaN; return; end
    n = max(1, round(anteil * numel(v)));
    m = mean(maxk(v, n));
end

function b = maske_zu_bereichen(mask, xv, dt_s, min_dauer_s, max_luecke_s)
% Logische Maske -> Cell-Array von [x_start x_ende]-Bereichen (x-Einheiten).
%   Schliesst Luecken < max_luecke_s und verwirft Ereignisse < min_dauer_s.
    b = {};
    mask = mask(:); mask(isnan(mask)) = 0; mask = logical(mask);
    if ~any(mask), return; end
    n_gap = max(0, round(max_luecke_s / max(dt_s, eps)));
    n_min = max(1, round(min_dauer_s / max(dt_s, eps)));

    % Kleine Luecken schliessen
    if n_gap > 0
        aus = find(diff([1; mask; 1]) == -1);   % Startindex jeder 0-Luecke
        ein = find(diff([1; mask; 1]) ==  1) - 1;
        for k = 1:numel(aus)
            i0 = aus(k); i1 = ein(k);
            if i0 > 1 && i1 <= numel(mask) && (i1 - i0 + 1) <= n_gap
                mask(i0:i1) = true;
            end
        end
    end

    % Zusammenhaengende Laeufe finden
    d = diff([0; mask; 0]);
    starts = find(d == 1);
    enden  = find(d == -1) - 1;
    for k = 1:numel(starts)
        if (enden(k) - starts(k) + 1) >= n_min
            b{end+1} = [xv(starts(k)), xv(enden(k))]; %#ok<AGROW>
        end
    end
end

function v = fp_zu_vektor(kennzahlen, keys)
    v = zeros(1, numel(keys));
    for i = 1:numel(keys)
        if isfield(kennzahlen, keys{i}) && isfinite(kennzahlen.(keys{i}))
            v(i) = kennzahlen.(keys{i});
        end
    end
end

function val = feld(s, name, default)
    if isstruct(s) && isfield(s, name), val = s.(name); else, val = default; end
end

function val = param_wert(params, pfade, default)
% Erster aufloesbarer Punkt-Pfad aus PFADE (Cell) auf einen endlichen Skalar.
    val = default;
    if ~isstruct(params), return; end
    for k = 1:numel(pfade)
        teile = strsplit(pfade{k}, '.');
        cur = params; ok = true;
        for j = 1:numel(teile)
            if isstruct(cur) && isfield(cur, teile{j})
                cur = cur.(teile{j});
            else
                ok = false; break;
            end
        end
        if ok && isnumeric(cur) && isscalar(cur) && isfinite(cur)
            val = cur; return;
        end
    end
end

function z = zeile(v)
    z = v(:).';
end
