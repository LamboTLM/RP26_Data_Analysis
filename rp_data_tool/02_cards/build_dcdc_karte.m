function build_dcdc_karte(parent, signale, name, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
fn_v = signal_zu_feldname(['PDU_DCDC_', name, '_vout_can']);
fn_i = signal_zu_feldname(['PDU_DCDC_', name, '_iout_can']);
fn_t = signal_zu_feldname(['PDU_DCDC_', name, '_temp_can']);
fn_e = signal_zu_feldname(['PDU_DCDC_', name, '_e_b_can']);

pnl = uipanel(parent, 'Position', position, 'BackgroundColor', C.karte, ...
    'BorderType', 'line', 'HighlightColor', C.grau2);
uilabel(pnl, 'Position', [5, position(4) - 18, position(3) - 10, 16], ...
    'Text', strrep(name, '_', ' '), 'FontSize', 8, 'FontWeight', 'bold', ...
    'FontColor', C.rot, 'BackgroundColor', 'none');

pairs = {fn_v, 'V'; fn_i, 'A'; fn_t, '°C'};
for j = 1:3
    fn = pairs{j, 1};
    einheit = pairs{j, 2};
    if isfield(signale, fn) && isfield(signale, [fn, '_ok']) && signale.([fn, '_ok'])
        try
            v = signale.(fn).Data(end);
            vstr = sprintf('%.1f%s', v, einheit);
        catch
            vstr = ['--', einheit];
        end
        fc = C.weiss;
    else
        vstr = ['N/A ', einheit];
        fc = C.fehlend;
    end
    uilabel(pnl, 'Position', [5, position(4) - 35 - j * 16, position(3) - 10, 14], ...
        'Text', vstr, 'FontSize', 8, 'FontColor', fc, 'BackgroundColor', 'none');
end

has_err = false;
if isfield(signale, fn_e) && isfield(signale, [fn_e, '_ok']) && signale.([fn_e, '_ok'])
    try
        has_err = max(signale.(fn_e).Data) > 0.5;
    catch
        % ignore
    end
end
fc2 = has_err * C.rot + (~has_err) * C.gruen;
uilabel(pnl, 'Position', [5, 5, position(3) - 10, 14], 'Text', tern_str(has_err, 'FEHLER', 'OK'), 'FontSize', 8, 'FontWeight', 'bold', 'FontColor', fc2, 'BackgroundColor', 'none');
end