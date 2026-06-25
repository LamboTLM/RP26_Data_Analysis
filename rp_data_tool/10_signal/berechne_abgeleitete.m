function signale = berechne_abgeleitete(signale, cfg)
    % Berechnet abgeleitete Groessen aus Rohsignalen
    % Autor: [Benutzer]
    % Datum: 2026-06-24
    % Changelog: 
    %   - trapz fuer Energie
    %   - cumtrapz fuer GPS (statt cumsum)
    %   - alpha konfigurierbar
    %   - sicheres_resample statt resample

    raeder = cfg.fahrzeug.raeder;

    % --- Radweise Groessen ---
    for i = 1:numel(raeder)
        rad = raeder{i};
        spd_fn = signal_zu_feldname(['unitek_' rad '_speed_motor_ist_can']);
        tq_fn = signal_zu_feldname(['unitek_' rad '_torque_motor_ist_can']);
        vdc_fn = signal_zu_feldname(['unitek_' rad '_Vdc_Bus_can']);
        iist_fn = signal_zu_feldname(['unitek_' rad '_i_ist_can']);

        signale.(['omega_' rad '_ok']) = false;
        signale.(['P_mech_' rad '_ok']) = false;
        signale.(['P_dc_' rad '_ok']) = false;
        signale.(['P_loss_' rad '_ok']) = false;

        % Omega [rad/s]
        if isfield(signale, spd_fn) && signale.([spd_fn '_ok'])
            try
                omega = signale.(spd_fn);
                omega.Data = omega.Data * cfg.phys.rad_pro_rpm;
                signale.(['omega_' rad]) = omega;
                signale.(['omega_' rad '_ok']) = true;
            catch
                % continue
            end
        end

        % Mechanische Leistung [W]
        if signale.(['omega_' rad '_ok']) && isfield(signale, tq_fn) && signale.([tq_fn '_ok'])
            try
                tq = util.sicheres_resample(signale.(tq_fn), signale.(['omega_' rad]).Time);
                P_mech = tq;
                P_mech.Data = tq.Data .* signale.(['omega_' rad]).Data;
                signale.(['P_mech_' rad]) = P_mech;
                signale.(['P_mech_' rad '_ok']) = true;
            catch
                % continue
            end
        end

        % DC-Leistung [W]
        if isfield(signale, vdc_fn) && signale.([vdc_fn '_ok']) && ...
           isfield(signale, iist_fn) && signale.([iist_fn '_ok'])
            try
                vdc = signale.(vdc_fn);
                ii = util.sicheres_resample(signale.(iist_fn), vdc.Time);
                P_dc = vdc;
                P_dc.Data = vdc.Data .* ii.Data;
                signale.(['P_dc_' rad]) = P_dc;
                signale.(['P_dc_' rad '_ok']) = true;
            catch
                % continue
            end
        end

        % Verlustleistung [W]
        if signale.(['P_dc_' rad '_ok']) && signale.(['P_mech_' rad '_ok'])
            try
                P_mech_r = util.sicheres_resample(signale.(['P_mech_' rad]), signale.(['P_dc_' rad]).Time);
                P_loss = signale.(['P_dc_' rad]);
                P_loss.Data = signale.(['P_dc_' rad]).Data - P_mech_r.Data;
                signale.(['P_loss_' rad]) = P_loss;
                signale.(['P_loss_' rad '_ok']) = true;
            catch
                % continue
            end
        end
    end

    % --- Pack-Leistung [W] ---
    vfn = signal_zu_feldname('IVT_Result_U2_Post_Airs_can');
    ifn = signal_zu_feldname('IVT_Result_I_can');
    signale.P_pack_ok = false;
    if isfield(signale, vfn) && signale.([vfn '_ok']) && isfield(signale, ifn) && signale.([ifn '_ok'])
        try
            ii = util.sicheres_resample(signale.(ifn), signale.(vfn).Time);
            P_pack = signale.(vfn);
            P_pack.Data = signale.(vfn).Data .* ii.Data;
            signale.P_pack = P_pack;
            signale.P_pack_ok = true;
        catch
            % continue
        end
    end

    % --- Mechanische Gesamtleistung [W] ---
    signale.P_mech_total_ok = false;
    if signale.P_mech_fl_ok && signale.P_mech_fr_ok && signale.P_mech_rl_ok && signale.P_mech_rr_ok
        try
            t_ref = signale.P_mech_fl.Time;
            Ptot = signale.P_mech_fl;
            for j = 1:numel(raeder)
                rad = raeder{j};
                if strcmp(rad, 'fl')
                    continue;
                end
                Pr = util.sicheres_resample(signale.(['P_mech_' rad]), t_ref);
                Ptot.Data = Ptot.Data + Pr.Data;
            end
            signale.P_mech_total = Ptot;
            signale.P_mech_total_ok = true;
        catch
            % continue
        end
    end

    % --- Powertrain-Wirkungsgrad [%] ---
    signale.eta_powertrain_ok = false;
    if signale.P_pack_ok && signale.P_mech_total_ok
        try
            P_pack_r = util.sicheres_resample(signale.P_pack, signale.P_mech_total.Time);
            eta = signale.P_mech_total;
            gueltig = abs(P_pack_r.Data) > cfg.schwellen.pack_leistung_min;
            eta.Data = zeros(size(P_pack_r.Data));
            eta.Data(gueltig) = signale.P_mech_total.Data(gueltig) ./ P_pack_r.Data(gueltig) * 100;
            eta.Data = max(0, min(100, eta.Data));
            signale.eta_powertrain = eta;
            signale.eta_powertrain_ok = true;
        catch
            % continue
        end
    end

    % --- Energie gesamt (Antrieb) [kWh] ---
    signale.E_total_ok = false;
    if signale.P_pack_ok
        try
            t_vec = signale.P_pack.Time;
            P_vec = signale.P_pack.Data;
            P_antrieb = P_vec .* (P_vec > 0);
            signale.E_total_kWh = trapz(t_vec, P_antrieb) * cfg.phys.kwh_pro_j;
            signale.E_total_ok = true;
        catch
            % continue
        end
    end

    % --- Rekuperation [kWh] ---
    signale.E_regen_ok = false;
    if signale.P_pack_ok
        try
            t_vec = signale.P_pack.Time;
            P_vec = signale.P_pack.Data;
            P_regen = abs(P_vec .* (P_vec < 0));
            signale.E_regen_kWh = trapz(t_vec, P_regen) * cfg.phys.kwh_pro_j;
            signale.E_regen_ok = true;
        catch
            % continue
        end
    end

    % --- GPS Track (aus Geschwindigkeit) [m] ---
    signale.gps_x_ok = false;
    vx_fn = signal_zu_feldname('INS_vel_x_can');
    vy_fn = signal_zu_feldname('INS_vel_y_can');
    ax_fn = signal_zu_feldname('INS_acc_x_can');
    ay_fn = signal_zu_feldname('INS_acc_y_can');

    if isfield(signale, vx_fn) && signale.([vx_fn '_ok']) && ...
       isfield(signale, vy_fn) && signale.([vy_fn '_ok'])
        try
            vx = signale.(vx_fn);
            vy = util.sicheres_resample(signale.(vy_fn), vx.Time);
            % FIX: cumtrapz statt cumsum!
            signale.gps_x = cumtrapz(vx.Time, vx.Data);
            signale.gps_y = cumtrapz(vx.Time, vy.Data);
            signale.gps_t = vx.Time;
            signale.gps_x_ok = true;
            fprintf('  GPS: velocity integration OK (%d points)\n', numel(signale.gps_x));
        catch ME
            fprintf('  GPS: velocity integration failed - %s\n', ME.message);
        end
    end

    % --- GPS Track (aus Beschleunigung, Fallback) [m] ---
    if ~signale.gps_x_ok && isfield(signale, ax_fn) && signale.([ax_fn '_ok']) && ...
                             isfield(signale, ay_fn) && signale.([ay_fn '_ok'])
        try
            ax_ts = signale.(ax_fn);
            ay_ts = util.sicheres_resample(signale.(ay_fn), ax_ts.Time);
            t_vec = ax_ts.Time;
            ax = ax_ts.Data;
            ay = ay_ts.Data;

            alpha = cfg.filter.alpha_hp_track; % FIX: 0.998 fuer Track!

            % Hochpass auf Beschleunigung
            ax_hp = zeros(size(ax));
            ay_hp = zeros(size(ay));
            for k = 2:numel(ax)
                ax_hp(k) = alpha * (ax_hp(k-1) + ax(k) - ax(k-1));
                ay_hp(k) = alpha * (ay_hp(k-1) + ay(k) - ay(k-1));
            end

            % 1. Integration: acc -> vel
            vx_i = cumtrapz(t_vec, ax_hp);
            vy_i = cumtrapz(t_vec, ay_hp);

            % Hochpass auf Geschwindigkeit
            vx_hp = zeros(size(vx_i));
            vy_hp = zeros(size(vy_i));
            for k = 2:numel(vx_i)
                vx_hp(k) = alpha * (vx_hp(k-1) + vx_i(k) - vx_i(k-1));
                vy_hp(k) = alpha * (vy_hp(k-1) + vy_i(k) - vy_i(k-1));
            end

            % 2. Integration: vel -> pos
            signale.gps_x = cumtrapz(t_vec, vx_hp);
            signale.gps_y = cumtrapz(t_vec, vy_hp);
            signale.gps_t = t_vec;
            signale.gps_x_ok = true;
            fprintf('  GPS: double-integration from acc OK (%d points)\n', numel(signale.gps_x));
        catch ME
            fprintf('  GPS: failed - %s\n', ME.message);
        end
    end
end