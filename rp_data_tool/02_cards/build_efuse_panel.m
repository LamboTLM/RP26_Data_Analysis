function build_efuse_panel(parent, signale, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
pnl = uipanel(parent, 'Position', position, 'BackgroundColor', C.panel, 'BorderType', 'none');
uilabel(pnl, 'Position', [0, position(4) - 18, 200, 16], 'Text', 'eFuse Monitor', ...
    'FontSize', 10, 'FontWeight', 'bold', 'FontColor', C.rot, 'BackgroundColor', 'none');

fuse_namen = {'ACE', 'AMS', 'AMS_Fans', 'DVSC', 'Ewp_Inv', 'Inv_FL', 'Inv_FR', 'Inv_RL', 'Inv_RR', 'SDC', '12V_Gen'};
col_w = floor((position(3) - 10) / 4);

headers = {'eFuse', 'I mon (A)', 'Error', 'Occurrence'};
for h = 1:4
    uilabel(pnl, 'Position', [5 + (h - 1) * col_w, position(4) - 36, col_w - 2, 16], ...
        'Text', headers{h}, 'FontSize', 8, 'FontWeight', 'bold', 'FontColor', C.rot, 'BackgroundColor', 'none');
end

n_show = min(numel(fuse_namen), floor((position(4) - 45) / 20));
for i = 1:n_show
    yp = position(4) - 40 - i * 20;
    fn_I = signal_zu_feldname(['PDU_eFuse_', fuse_namen{i}, '_IMON_can']);
    fn_e = signal_zu_feldname(['PDU_eFuse_', fuse_namen{i}, '_e_b_can']);

    bgc = tern_str(mod(i, 2) == 0, C.karte, C.panel);       % Tippfehler korrigiert
    bk = uipanel(pnl, 'Position', [0, yp, position(3), 19], 'BackgroundColor', bgc, 'BorderType', 'none');

    uilabel(bk, 'Position', [5, 2, col_w - 2, 15], 'Text', strrep(fuse_namen{i}, '_', ' '), 'FontSize', 8, 'FontColor', C.weiss, 'BackgroundColor', 'none');

    if isfield(signale, fn_I) && isfield(signale, [fn_I, '_ok']) && signale.([fn_I, '_ok'])
        try
            v = mean(signale.(fn_I).Data, 'omitnan');
            istr = sprintf('%.2f', v);
            fc = C.weiss;
        catch
            istr = '--';
            fc = C.fehlend;
        end
    else
        istr = 'N/A';
        fc = C.fehlend;
    end
    uilabel(bk, 'Position', [5 + col_w, 2, col_w - 2, 15], 'Text', istr, ...
        'FontSize', 8, 'FontColor', fc, 'BackgroundColor', 'none');

    has_err = false;
    occ = 0;
    if isfield(signale, fn_e) && isfield(signale, [fn_e, '_ok']) && signale.([fn_e, '_ok'])
        try
            ed = signale.(fn_e).Data;
            has_err = max(ed) > 0.5;
            occ = sum(diff(ed > 0.5) > 0);
        catch
            % ignore
        end
        estr = tern_str(has_err, 'JA', 'nein');           % Tippfehler korrigiert
        efc = has_err * C.rot + (~has_err) * C.gruen;
    else
        estr = 'N/A';
        efc = C.fehlend;
    end
    uilabel(bk, 'Position', [5 + 2 * col_w, 2, col_w - 2, 15], 'Text', estr, ...
        'FontSize', 8, 'FontWeight', 'bold', 'FontColor', efc, 'BackgroundColor', 'none');
    uilabel(bk, 'Position', [5 + 3 * col_w, 2, col_w - 2, 15], 'Text', num2str(occ), ...
        'FontSize', 8, 'FontColor', C.grau, 'BackgroundColor', 'none');
end
end