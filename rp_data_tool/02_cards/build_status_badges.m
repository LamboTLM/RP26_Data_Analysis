function build_status_badges(parent, signale, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
checks = {'ams_ok_b_can', 'AMS OK'; 'imd_ok_b_can', 'IMD OK';
    'SDC_AS_closed_b_can', 'SDC closed'; 'DL_EBS_state_can', 'EBS'};
xp = position(1);
for i = 1:size(checks, 1)
    fn = signal_zu_feldname(checks{i, 1});
    lbl = checks{i, 2};
    if isfield(signale, fn) && isfield(signale, [fn, '_ok']) && signale.([fn, '_ok'])
        try
            ts = signale.(fn);
            v = util.tern_str(isa(ts, 'timeseries'), ts.Data(end), ts(end));
            ok = v >= 1;
        catch
            ok = false;
        end
        bgc = C.gruen * 0.25;
        fc = C.gruen;
    else
        ok = false;
        bgc = [0.2, 0.1, 0.1];
        fc = C.fehlend;
        lbl = [lbl, ' (N/A)'];
    end
    p2 = uipanel(parent, 'Position', [xp, position(2), 130, 30], 'BackgroundColor', bgc, 'BorderType', 'none');
    uilabel(p2, 'Position', [5, 5, 120, 20], 'Text', lbl, ...
        'FontSize', 9, 'FontWeight', 'bold', 'FontColor', fc, 'BackgroundColor', 'none');
    xp = xp + 140;
end
end