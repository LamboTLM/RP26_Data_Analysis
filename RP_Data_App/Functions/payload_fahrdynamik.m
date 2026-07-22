% =========================================================================
%  payload_fahrdynamik  –  Dateivertrag fuer den Fahrdynamik-Tab
% -------------------------------------------------------------------------
%  Zweck         : Liefert Rohsignale + die abgeleiteten Fahrdynamik-Groessen:
%                  Laengsschlupf (eigen + geloggt + Delta), Schwimm-/Schraeg-
%                  laufwinkel, Radlast Fz je Ecke (aus Beschleunigung UND aus
%                  Federverformung), Reifen-Laengskraft je Ecke sowie g-g- und
%                  Eigenlenk-Daten. Alle abgeleiteten Reihen liegen auf pl.x.
%
%  EINHEITEN-ANNAHMEN (bei Bedarf in fahrzeug_parameter / hier anpassen):
%    speed_can            -> * params.log.geschw_in_ms  = m/s
%    tqv_rot_spd_*        -> rad/s   (Radwinkelgeschwindigkeit)
%    INS_acc_*            -> m/s^2
%    INS_ang_vel_z /
%      DL_Yaw_rate        -> rad/s
%    steering_wheel_angle -> Grad (Reifenwinkel = / params.lenkung.uebersetzung)
%    unitek_*_torque      -> Nm (Motormoment; Regen = negativ)
%    pbrake_*             -> bar
%    rocker_*             -> mm (Federweg; Nullpunkt/Skalierung ggf. kalibrieren)
%
%  Abhaengigkeiten: payload_envelope, signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function pl = payload_fahrdynamik(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_FAHRDYNAMIK  pl = PAYLOAD_FAHRDYNAMIK(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand (Panel-Stubs).
%     2026-07-15  Berechnungen gefuellt: Schlupf, Schraeglauf, Fz, Reifenkraft.

    %% Konfiguration
    G     = 9.81;    % m/s^2
    V_MIN = 2.0;     % m/s, darunter sind Schlupf/Schraeglauf undefiniert

    %% Rohsignale (fuers Frontend) -> Envelope
    namen = { ...
        'speed_can','INS_vel_x_can','INS_vel_y_can', ...
        'INS_acc_x_can','INS_acc_y_can','INS_ang_vel_z_can','DL_Yaw_rate_can', ...
        'steering_wheel_angle_can', ...
        'slip_compare_val_fl_can','slip_compare_val_fr_can', ...
        'slip_compare_val_rl_can','slip_compare_val_rr_can', ...
        'tqv_rot_spd_fl_can','tqv_rot_spd_fr_can', ...
        'tqv_rot_spd_rl_can','tqv_rot_spd_rr_can', ...
        'unitek_fl_torque_motor_ist_can','unitek_fr_torque_motor_ist_can', ...
        'unitek_rl_torque_motor_ist_can','unitek_rr_torque_motor_ist_can', ...
        'pbrake_front_can','pbrake_rear_can'};
    pl = payload_envelope(store, 'fahrdynamik', x, namen);

    %% Vorberechnungen: Geometrie aus Parametern
    m   = params.fahrzeug.masse_gesamt_kg;
    L   = params.fahrzeug.radstand_mm      / 1000;   % m
    tf  = params.fahrzeug.spur_vorn_mm     / 1000;   % m
    tr  = params.fahrzeug.spur_hinten_mm   / 1000;   % m
    h   = params.fahrzeug.schwerpunkt_hoehe_mm / 1000;
    wf  = params.fahrzeug.gewichtsanteil_vorn;       % 0..1
    a_v = L * (1 - wf);                              % SP -> Vorderachse
    b_h = L * wf;                                    % SP -> Hinterachse
    r   = params.reifen.radius_dyn_mm      / 1000;   % m
    ue  = params.antrieb.uebersetzung;               % Motor -> Rad
    lk  = params.lenkung.uebersetzung;               % Lenkrad -> Reifen
    f_v = params.log.geschw_in_ms;                   % speed_can -> m/s

    %% Vorberechnungen: benoetigte Signale auf x
    v_x   = res(store, x, 'speed_can')          * f_v;       % m/s
    ax    = res(store, x, 'INS_acc_x_can');                  % m/s^2
    ay    = res(store, x, 'INS_acc_y_can');                  % m/s^2
    yaw   = yaw_rate(store, x);                              % rad/s
    delta = res(store, x, 'steering_wheel_angle_can') / lk;  % Reifenwinkel [Grad]
    v_y   = quergeschw(store, x, v_x, ax, ay, yaw);          % m/s (gemessen o. geschaetzt)

    v_x_gate = v_x; v_x_gate(v_x_gate < V_MIN) = NaN;        % Tor fuer Divisionen

    %% Berechnung: Laengsschlupf je Ecke (eigen + geloggt + Delta)
    ecken = {'fl','fr','rl','rr'};
    y_off = [ +tf/2, -tf/2, +tr/2, -tr/2 ];                  % laterale Radposition
    schlupf_e = struct(); schlupf_g = struct(); schlupf_d = struct();
    for i = 1:4
        e = ecken{i};
        v_ref = v_x_gate - yaw .* y_off(i);                 % Referenzgeschw. an der Ecke
        omega = res(store, x, ['tqv_rot_spd_' e '_can']);   % rad/s
        v_rad = omega * r;                                  % m/s am Radumfang
        eigen = (v_rad - v_ref) ./ v_ref;                   % Schlupf
        gelog = res(store, x, ['slip_compare_val_' e '_can']);
        schlupf_e.(e) = zeile(eigen);
        schlupf_g.(e) = zeile(gelog);
        schlupf_d.(e) = zeile(eigen - gelog);
    end
    pl.panels.schlupf = struct('eigen', schlupf_e, 'geloggt', schlupf_g, 'delta', schlupf_d);

    %% Berechnung: Schwimmwinkel + Achs-Schraeglaufwinkel
    beta = atan2(v_y, v_x_gate) * 180/pi;                   % Grad
    df   = deg2rad(delta);                                  % vorn, rad
    alpha_v = (df - atan2(v_y + a_v.*yaw, v_x_gate)) * 180/pi;
    alpha_h = (   - atan2(v_y - b_h.*yaw, v_x_gate)) * 180/pi;   % hinten ungelenkt
    pl.panels.schraeglauf = struct('beta', zeile(beta), ...
        'alpha_vorn', zeile(alpha_v), 'alpha_hinten', zeile(alpha_h));

    %% Berechnung: Radlast Fz je Ecke
    % (a) aus Beschleunigung + Geometrie (Radlastverlagerung)
    W  = m * G;
    Wf = W * wf / 2;  Wr = W * (1 - wf) / 2;                % statisch je Rad
    dFx = m .* ax .* h ./ L / 2;                            % Laengsverlagerung je Rad
    dFyv = (m*wf)     .* ay .* h ./ tf;                     % quer vorn (aussen +)
    dFyh = (m*(1-wf)) .* ay .* h ./ tr;                     % quer hinten
    fz_a.fl = zeile(Wf - dFx - dFyv);
    fz_a.fr = zeile(Wf - dFx + dFyv);
    fz_a.rl = zeile(Wr + dFx - dFyh);
    fz_a.rr = zeile(Wr + dFx + dFyh);

    % (b) aus Federverformung (relativ; Rocker-Nullpunkt/Skalierung noch zu kalibrieren)
    fz_f.fl = zeile(fz_aus_feder(store, x, 'rocker_fl_can', params.fahrwerk.federrate_vorn_n_mm,   params.fahrwerk.motion_ratio_vorn,   Wf));
    fz_f.fr = zeile(fz_aus_feder(store, x, 'rocker_fr_can', params.fahrwerk.federrate_vorn_n_mm,   params.fahrwerk.motion_ratio_vorn,   Wf));
    fz_f.rl = zeile(fz_aus_feder(store, x, 'rocker_rl_can', params.fahrwerk.federrate_hinten_n_mm, params.fahrwerk.motion_ratio_hinten, Wr));
    fz_f.rr = zeile(fz_aus_feder(store, x, 'rocker_rr_can', params.fahrwerk.federrate_hinten_n_mm, params.fahrwerk.motion_ratio_hinten, Wr));
    pl.panels.radlast = struct('aus_accel', fz_a, 'aus_feder', fz_f);

    %% Berechnung: Reifen-Laengskraft je Ecke [N]
    % F = (Radmoment aus Antrieb/Regen - Bremsmoment) / Reifenradius
    tb_v = res(store, x, 'pbrake_front_can') * params.bremse.moment_pro_bar_vorn_nm   / 2;  % je Rad
    tb_h = res(store, x, 'pbrake_rear_can')  * params.bremse.moment_pro_bar_hinten_nm / 2;
    kraft.fl = zeile((res(store,x,'unitek_fl_torque_motor_ist_can')*ue - tb_v) / r);
    kraft.fr = zeile((res(store,x,'unitek_fr_torque_motor_ist_can')*ue - tb_v) / r);
    kraft.rl = zeile((res(store,x,'unitek_rl_torque_motor_ist_can')*ue - tb_h) / r);
    kraft.rr = zeile((res(store,x,'unitek_rr_torque_motor_ist_can')*ue - tb_h) / r);
    pl.panels.reifenkraft = kraft;

    %% Berechnung: g-g und Eigenlenkgradient
    pl.panels.gg = struct('ax', zeile(ax), 'ay', zeile(ay));
    pl.panels.eigenlenkgradient = struct('lenkwinkel', zeile(delta), 'ay', zeile(ay));
end

% =========================================================================
%  Functions
% =========================================================================

function y = res(store, x, name)
% Signal ueber signal_holen auf die x-Achse resampeln (NaN wo nicht vorhanden).
    sig = signal_holen(store, name);
    if strcmp(sig.status, 'fehlt') || isempty(sig.t)
        y = nan(size(x.t_ref(:)));
        return;
    end
    methode = 'linear'; if sig.is_bool, methode = 'previous'; end
    [tu, iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), methode, NaN);
end

function yaw = yaw_rate(store, x)
% Bevorzugt INS_ang_vel_z, sonst DL_Yaw_rate (Annahme rad/s).
    s = signal_holen(store, 'INS_ang_vel_z_can');
    if strcmp(s.status, 'gueltig')
        yaw = res(store, x, 'INS_ang_vel_z_can');
    else
        yaw = res(store, x, 'DL_Yaw_rate_can');
    end
end

function v_y = quergeschw(store, x, v_x, ax, ay, yaw) %#ok<INUSL>
% Quergeschwindigkeit: primaer gemessen (INS_vel_y), sonst grob geschaetzt
% ueber v_y_dot = a_y - v_x*yaw (driftet, daher nur Rueckfall).
    s = signal_holen(store, 'INS_vel_y_can');
    if strcmp(s.status, 'gueltig')
        v_y = res(store, x, 'INS_vel_y_can');
        return;
    end
    t = x.t_ref(:);
    vy_dot = ay - v_x .* yaw;
    vy_dot(isnan(vy_dot)) = 0;
    gueltig = isfinite(t);
    v_y = nan(size(t));
    if nnz(gueltig) > 1
        v_y(gueltig) = cumtrapz(t(gueltig), vy_dot(gueltig));
    end
end

function fz = fz_aus_feder(store, x, name, federrate_n_mm, motion_ratio, statisch)
% Relative Radlast aus Federweg: F_dyn = (rocker - Mittel) * k / MR + statisch.
% ANNAHME: rocker in mm, Nullpunkt = Signalmittel (bis echte Kalibrierung da ist).
    rock = res(store, x, name);
    if all(isnan(rock))
        fz = nan(size(rock));
        return;
    end
    dyn = (rock - mean(rock, 'omitnan')) * federrate_n_mm / motion_ratio;
    fz  = statisch + dyn;
end

function z = zeile(v)
% Als Zeilenvektor fuer sauberes JSON.
    z = v(:).';
end