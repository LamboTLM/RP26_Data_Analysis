function build_inverter_karte(parent, signale, rad, label, cfg, position)
%BUILD_INVERTER_KARTE Zeigt Inverter-Kennwerte fuer ein Rad an.
%
%   Eingabe:
%       parent   — UI-Container (Tab/Panel)
%       signale  — Struct mit extrahierten Signalen
%       rad      — String, z.B. 'fl', 'fr', 'rl', 'rr'
%       label    — Anzeige-Label, z.B. 'FL — Front Left'
%       cfg      — Config-Struct
%       position — [left, bottom, width, height]
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

    C = farben();

    %% Panel
    pnl = uipanel(parent, ...
        'Position',       position, ...
        'BackgroundColor', C.panel, ...
        'BorderType',     'line', ...
        'BorderWidth',    1, ...
        'HighlightColor',  C.grau2);

    %% Titel
    uilabel(pnl, ...
        'Position',   [5, position(4) - 22, position(3) - 10, 18], ...
        'Text',       label, ...
        'FontSize',   9, ...
        'FontWeight', 'bold', ...
        'FontColor',  C.rot, ...
        'BackgroundColor', 'none');

    %% Signalnamen (Primaer + Fallback)
    sigs = {
        sprintf('unitek_%s_speed_motor_ist_can', rad), sprintf('unitek_%s_speed_can', rad),         'n_mot', ' rpm';
        sprintf('unitek_%s_torque_motor_ist_can', rad), sprintf('unitek_%s_torque_can', rad),         'M_mot', ' Nm';
        sprintf('unitek_%s_motor_temp_can', rad),       sprintf('unitek_%s_temp_motor_can', rad),      'T_mot', ' °C';
        sprintf('unitek_%s_inverter_temp_can', rad),    sprintf('unitek_%s_temp_inverter_can', rad),  'T_inv', ' °C';
        sprintf('unitek_%s_v_dc_link_can', rad),        sprintf('unitek_%s_v_dc_can', rad),            'U_dc',  ' V';
        sprintf('unitek_%s_i_dc_link_can', rad),        sprintf('unitek_%s_i_dc_can', rad),            'I_dc',  ' A';
    };

    %% Layout
    col_w = floor((position(3) - 20) / 2);
    row_h = 22;
    y0    = position(4) - 46;
    x_pos = [5, 10 + col_w];

    max_t_mot = 0;

    for k = 1:size(sigs, 1)
        xp   = x_pos(mod(k - 1, 2) + 1);
        yp   = y0 - floor((k - 1) / 2) * row_h;
        name = sigs{k, 3};
        einh = sigs{k, 4};

        [wert, ok, roh] = hole_wert(signale, sigs{k, 1}, sigs{k, 2});

        if ok && strcmp(name, 'T_mot') && ~isempty(roh)
            max_t_mot = max(max_t_mot, max(roh, [], 'omitnan'));
        end

        % Label-Name
        uilabel(pnl, 'Position', [xp, yp, 45, 18], ...
            'Text', [name, ':'], 'FontSize', 8, ...
            'FontColor', C.grau3, 'BackgroundColor', 'none');

        % Wert
        farbe = tern_str(ok, C.weiss, C.grau3);
        uilabel(pnl, 'Position', [xp + 45, yp, col_w - 50, 18], ...
            'Text', [wert, einh], 'FontSize', 8, ...
            'FontColor', farbe, 'BackgroundColor', 'none');
    end

    %% Status-Badge (Temperatur-Status)
    if max_t_mot > 120
        status_text = 'CRIT';
        status_col  = C.rot;
    elseif max_t_mot > 100
        status_text = 'HOT';
        status_col  = C.orange;
    else
        status_text = 'OK';
        status_col  = C.gruen;
    end

    uilabel(pnl, 'Position', [position(3) - 55, 5, 50, 18], ...
        'Text', status_text, 'FontSize', 8, ...
        'FontWeight', 'bold', 'FontColor', status_col, ...
        'BackgroundColor', 'none', 'HorizontalAlignment', 'right');
end

%% Lokale Helper
function [wert_str, ok, roh] = hole_wert(signale, sig, alt)
%HOLE_WERT Liest den letzten Wert eines Signals mit Fallback-Namen.
    wert_str = '--';
    ok = false;
    roh = [];

    feld = '';
    if isfield(signale, sig) && isfield(signale, [sig, '_ok']) && signale.([sig, '_ok'])
        feld = sig;
    elseif isfield(signale, alt) && isfield(signale, [alt, '_ok']) && signale.([alt, '_ok'])
        feld = alt;
    end

    if isempty(feld)
        return;
    end

    try
        roh = extrahiere_rohdaten(signale.(feld));
        if ~isempty(roh)
            wert_str = sprintf('%.1f', roh(end));
            ok = true;
        end
    catch
    end
end