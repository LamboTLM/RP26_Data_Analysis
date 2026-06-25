function build_ams_fehler(parent, signale, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
checks = {
    'ams_cell_overvoltage_b_can', 'Overvoltage';
    'ams_cell_undervoltage_b_can', 'Undervoltage';
    'ams_cell_overtemp_b_can', 'Overtemp';
    'ams_cell_undertemp_b_can', 'Undertemp';
    'ams_com_error_can', 'COM Error';
    'ams_slave_fail_b_can', 'Slave Fail';
    'ams_ok_b_can', 'AMS OK';
    };

pnl = uipanel(parent, 'Position', position, 'BackgroundColor', C.panel, 'BorderType', 'none');
uilabel(pnl, 'Position', [0, position(4) - 18, 200, 16], 'Text', 'AMS Fehler & Status', ...
    'FontSize', 10, 'FontWeight', 'bold', 'FontColor', C.rot, 'BackgroundColor', 'none');

xp = 5;
for i = 1:size(checks, 1)
    fn = signal_zu_feldname(checks{i, 1});
    lbl = checks{i, 2};

    if isfield(signale, fn) && isfield(signale, [fn, '_ok']) && signale.([fn, '_ok'])
        try
            v = max(signale.(fn).Data);
            if strcmp(lbl, 'AMS OK')
                ok = v >= 1;
                bgc = ok * [0.1, 0.3, 0.1] + (~ok) * [0.3, 0.1, 0.1];
                fc = ok * C.gruen + (~ok) * C.rot;
            else
                ok = v < 0.5;
                bgc = ok * [0.1, 0.3, 0.1] + (~ok) * [0.3, 0.1, 0.1];
                fc = ok * C.gruen + (~ok) * C.rot;
                if ~ok
                    lbl = [lbl, ' !'];
                end
            end
        catch
            bgc = [0.2, 0.15, 0.1];
            fc = C.fehlend;
            lbl = [lbl, ' (N/A)'];
        end
    else
        bgc = [0.15, 0.15, 0.15];
        fc = C.fehlend;
        lbl = [lbl, ' (N/A)'];
    end

    p2 = uipanel(pnl, 'Position', [xp, 5, 140, 35], 'BackgroundColor', bgc, 'BorderType', 'none');
    uilabel(p2, 'Position', [5, 8, 130, 20], 'Text', lbl, ...
        'FontSize', 9, 'FontWeight', 'bold', 'FontColor', fc, 'BackgroundColor', 'none');
    xp = xp + 148;
end
end