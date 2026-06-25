function build_temp_status_zeile(parent, signale, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
checks = {
    'unitek_fl_motor_temp_can', 'T mot FL', 80, 100;
    'unitek_fr_motor_temp_can', 'T mot FR', 80, 100;
    'unitek_rl_motor_temp_can', 'T mot RL', 80, 100;
    'unitek_rr_motor_temp_can', 'T mot RR', 80, 100;
    'unitek_fl_igbt_temp_can', 'T IGBT FL', 70, 90;
    'unitek_fr_igbt_temp_can', 'T IGBT FR', 70, 90;
    'ams_cell_max_temp_can', 'T bat max', 45, 60;
    'wpmd_brake_temp_fl_can', 'T brake FL', 200, 400;
    };

pnl = uipanel(parent, 'Position', position, 'BackgroundColor', C.panel, 'BorderType', 'none');
uilabel(pnl, 'Position', [0, position(4) - 18, 300, 16], 'Text', 'Temperatur Status — Spitzenwerte', ...
    'FontSize', 10, 'FontWeight', 'bold', 'FontColor', C.rot, 'BackgroundColor', 'none');

xp = 5;
for i = 1:size(checks, 1)
    fn = signal_zu_feldname(checks{i, 1});
    lbl = checks{i, 2};
    warn = checks{i, 3};
    crit = checks{i, 4};

    if isfield(signale, fn) && isfield(signale, [fn, '_ok']) && signale.([fn, '_ok'])
        try
            vmax = max(signale.(fn).Data);
            val_str = sprintf('%.0f°C', vmax);
            if vmax >= crit
                fc = C.rot;
                bgc = [0.3, 0.05, 0.05];
            elseif vmax >= warn
                fc = C.orange;
                bgc = [0.25, 0.15, 0.0];
            else
                fc = C.gruen;
                bgc = [0.05, 0.2, 0.05];
            end
        catch
            val_str = 'ERR';
            fc = C.fehlend;
            bgc = [0.15, 0.15, 0.15];
        end
    else
        val_str = 'N/A';
        fc = C.fehlend;
        bgc = [0.15, 0.15, 0.15];
    end

    p2 = uipanel(pnl, 'Position', [xp, 5, 175, 35], 'BackgroundColor', bgc, 'BorderType', 'none');
    uilabel(p2, 'Position', [5, 18, 100, 14], 'Text', lbl, 'FontSize', 8, 'FontColor', C.grau, 'BackgroundColor', 'none');
    uilabel(p2, 'Position', [5, 3, 100, 16], 'Text', val_str, 'FontSize', 11, 'FontWeight', 'bold', ...
        'FontColor', fc, 'BackgroundColor', 'none');
    xp = xp + 182;
end
end