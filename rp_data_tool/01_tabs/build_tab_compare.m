function build_tab_compare(tab, signale, cfg)
    % Session-Vergleich mit Zeit-Offset-Steuerung und GPS-Track
    % Autor: [Benutzer]
    % Datum: 2026-06-24

    C = cfg.farben;
    
    % UI fuer zweite Session und Zeit-Offset
    pnl_ctrl = uipanel(tab, 'Position', [10, 840, 1560, 80], ...
        'BackgroundColor', C.panel, 'BorderType', 'line', 'HighlightColor', C.grau2);
    
    uilabel(pnl_ctrl, 'Position', [10, 45, 200, 20], ...
        'Text', 'SESSION VERGLEICH', 'FontSize', 12, 'FontWeight', 'bold', ...
        'FontColor', C.rot, 'BackgroundColor', 'none');
    
    uibutton(pnl_ctrl, 'Position', [10, 10, 150, 28], ...
        'Text', '2. Session laden', ...
        'BackgroundColor', C.karte, 'FontColor', C.weiss, ...
        'ButtonPushedFcn', @(~,~) lade_zweite_session(tab, cfg));
    
    uilabel(pnl_ctrl, 'Position', [180, 45, 120, 18], ...
        'Text', 'Zeit-Offset S1 (s):', 'FontSize', 9, 'FontColor', C.grau, 'BackgroundColor', 'none');
    ef_offset1 = uieditfield(pnl_ctrl, 'numeric', ...
        'Position', [300, 43, 70, 22], 'Value', 0, ...
        'FontSize', 9, 'BackgroundColor', C.karte, 'FontColor', C.weiss);
    
    uilabel(pnl_ctrl, 'Position', [180, 15, 120, 18], ...
        'Text', 'Zeit-Offset S2 (s):', 'FontSize', 9, 'FontColor', C.grau, 'BackgroundColor', 'none');
    ef_offset2 = uieditfield(pnl_ctrl, 'numeric', ...
        'Position', [300, 13, 70, 22], 'Value', 0, ...
        'FontSize', 9, 'BackgroundColor', C.karte, 'FontColor', C.weiss);
    
    uibutton(pnl_ctrl, 'Position', [390, 10, 100, 28], ...
        'Text', 'Anwenden', ...
        'BackgroundColor', C.gruen, 'FontColor', C.weiss, ...
        'ButtonPushedFcn', @(~,~) update_vergleich(tab, signale, cfg, ef_offset1.Value, ef_offset2.Value));
    
    % Status
    lbl_status = uilabel(pnl_ctrl, 'Position', [510, 30, 400, 20], ...
        'Text', 'Keine 2. Session geladen', 'FontSize', 9, ...
        'FontColor', C.grau, 'BackgroundColor', 'none');
    
    % Speichere Handles im Tab UserData
    tab.UserData = struct('signale2', [], 'offset1', 0, 'offset2', 0, ...
        'lbl_status', lbl_status, 'cfg', cfg);

    % Initial-Plots mit nur einer Session
    erstelle_vergleichs_plots(tab, signale, [], cfg, 0, 0);
end

function lade_zweite_session(tab, cfg)
    % Laedt zweite MDF4-Datei
    [datei_name, datei_pfad] = uigetfile('*.mf4;*.MF4', '2. MDF4 Session auswaehlen');
    if isequal(datei_name, 0)
        return;
    end
    
    datei_pfad_voll = fullfile(datei_pfad, datei_name);
    try
        roh_daten = io.lade_mdf4(datei_pfad_voll, cfg);
        signale2 = extrahiere_signale(roh_daten, cfg);
        signale2 = berechne_abgeleitete(signale2, cfg);
        
        tab.UserData.signale2 = signale2;
        tab.UserData.lbl_status.Text = sprintf('Geladen: %s', datei_name);
        tab.UserData.lbl_status.FontColor = cfg.farben.gruen;
        
        % Auto-Update
        update_vergleich(tab, [], cfg, tab.UserData.offset1, tab.UserData.offset2);
    catch ME
        tab.UserData.lbl_status.Text = sprintf('Fehler: %s', ME.message);
        tab.UserData.lbl_status.FontColor = cfg.farben.rot;
    end
end

function update_vergleich(tab, signale, cfg, offset1, offset2)
    % Aktualisiert Vergleichs-Plots mit neuen Offsets
    if nargin < 4
        offset1 = 0;
        offset2 = 0;
    end
    
    tab.UserData.offset1 = offset1;
    tab.UserData.offset2 = offset2;
    
    % Loesche alte Plots
    delete(findall(tab, 'Type', 'uiaxes'));
    delete(findall(tab, 'Type', 'axes'));
    
    % Hole aktuelle Daten
    signale1 = signale;
    signale2 = tab.UserData.signale2;
    
    erstelle_vergleichs_plots(tab, signale1, signale2, cfg, offset1, offset2);
end

function erstelle_vergleichs_plots(tab, signale1, signale2, cfg, offset1, offset2)
    % Erstellt alle Vergleichs-Plots
    C = cfg.farben;
    
    % 1. GPS Track Vergleich (wichtig fuer Zeit-Synchronisation)
    ax_gps = erstelle_plot_bereich(tab, [10, 470, 770, 360], 'GPS Track Vergleich', cfg);
    
    if signale1.gps_x_ok
        plot(ax_gps, signale1.gps_x, signale1.gps_y, 'Color', C.teal, 'LineWidth', 1.5, ...
            'DisplayName', 'Session 1');
        hold(ax_gps, 'on');
        plot(ax_gps, signale1.gps_x(1), signale1.gps_y(1), 'o', 'Color', C.teal, ...
            'MarkerSize', 10, 'MarkerFaceColor', C.teal, 'DisplayName', 'Start S1');
    end
    
    if ~isempty(signale2) && signale2.gps_x_ok
        plot(ax_gps, signale2.gps_x, signale2.gps_y, 'Color', C.rot, 'LineWidth', 1.5, ...
            'DisplayName', 'Session 2');
        plot(ax_gps, signale2.gps_x(1), signale2.gps_y(1), 's', 'Color', C.rot, ...
            'MarkerSize', 10, 'MarkerFaceColor', C.rot, 'DisplayName', 'Start S2');
    end
    
    if ishold(ax_gps)
        hold(ax_gps, 'off');
        legend(ax_gps, 'Location', 'best', 'TextColor', C.grau, ...
            'Color', [0.13, 0.13, 0.13], 'EdgeColor', C.grau2, 'FontSize', 8);
    end
    axis(ax_gps, 'equal');
    xlabel(ax_gps, 'X (m)', 'Color', C.grau, 'FontSize', 8);
    ylabel(ax_gps, 'Y (m)', 'Color', C.grau, 'FontSize', 8);
    
    % 2. Speed Vergleich mit Zeit-Offset
    ax_spd = erstelle_plot_bereich(tab, [800, 470, 770, 360], 'Speed Vergleich (zeitverschoben)', cfg);
    fn_spd = signal_zu_feldname('speed_can');
    
    if isfield(signale1, fn_spd) && signale1.([fn_spd '_ok'])
        ts1 = signale1.(fn_spd);
        plot(ax_spd, ts1.Time + offset1, ts1.Data, 'Color', C.teal, 'LineWidth', 1.2, 'DisplayName', 'S1');
        hold(ax_spd, 'on');
    end
    
    if ~isempty(signale2) && isfield(signale2, fn_spd) && signale2.([fn_spd '_ok'])
        ts2 = signale2.(fn_spd);
        plot(ax_spd, ts2.Time + offset2, ts2.Data, 'Color', C.rot, 'LineWidth', 1.2, ...
            'DisplayName', 'S2');
    end
    
    if ishold(ax_spd)
        hold(ax_spd, 'off');
        legend(ax_spd, 'Location', 'best', 'TextColor', C.grau, ...
            'Color', [0.13, 0.13, 0.13], 'EdgeColor', C.grau2, 'FontSize', 8);
    end
    xlabel(ax_spd, 'Zeit (s)', 'Color', C.grau, 'FontSize', 8);
    ylabel(ax_spd, 'Speed (km/h)', 'Color', C.grau, 'FontSize', 8);
    
    % 3. g-g Diagramm Vergleich
    ax_gg = erstelle_plot_bereich(tab, [10, 60, 770, 360], 'g-g Diagramm Vergleich', cfg);
    fn_ax = signal_zu_feldname('INS_acc_x_can');
    fn_ay = signal_zu_feldname('INS_acc_y_can');
    
    if isfield(signale1, fn_ax) && signale1.([fn_ax '_ok']) && ...
       isfield(signale1, fn_ay) && signale1.([fn_ay '_ok'])
        ax1_d = signale1.(fn_ax).Data / cfg.phys.g;
        ay1_d = signale1.(fn_ay).Data / cfg.phys.g;
        scatter(ax_gg, ay1_d, ax1_d, 2, C.teal, 'filled', 'MarkerFaceAlpha', 0.3, ...
            'DisplayName', 'S1');
        hold(ax_gg, 'on');
    end
    
    if ~isempty(signale2) && isfield(signale2, fn_ax) && signale2.([fn_ax '_ok']) && ...
       isfield(signale2, fn_ay) && signale2.([fn_ay '_ok'])
        ax2_d = signale2.(fn_ax).Data / cfg.phys.g;
        ay2_d = signale2.(fn_ay).Data / cfg.phys.g;
        scatter(ax_gg, ay2_d, ax2_d, 2, C.rot, 'filled', 'MarkerFaceAlpha', 0.3, ...
            'DisplayName', 'S2');
    end
    
    if ishold(ax_gg)
        hold(ax_gg, 'off');
        % Kreise fuer 1g, 2g
        th = linspace(0, 2*pi, 100);
        for r = [1, 2]
            plot(ax_gg, r*cos(th), r*sin(th), '--', 'Color', C.grau2, 'LineWidth', 0.8, ...
                'HandleVisibility', 'off');
        end
        legend(ax_gg, 'Location', 'best', 'TextColor', C.grau, ...
            'Color', [0.13, 0.13, 0.13], 'EdgeColor', C.grau2, 'FontSize', 8);
    end
    axis(ax_gg, 'equal');
    xlim(ax_gg, [-3, 3]);
    ylim(ax_gg, [-3, 3]);
    xlabel(ax_gg, 'a_y (g)', 'Color', C.grau, 'FontSize', 8);
    ylabel(ax_gg, 'a_x (g)', 'Color', C.grau, 'FontSize', 8);
    
    % 4. Pack-Leistung Vergleich
    ax_pwr = erstelle_plot_bereich(tab, [800, 60, 770, 360], 'Pack-Leistung Vergleich', cfg);
    
    if signale1.P_pack_ok
        plot(ax_pwr, signale1.P_pack.Time + offset1, signale1.P_pack.Data / 1000, ...
            'Color', C.teal, 'LineWidth', 1.2, 'DisplayName', 'S1');
        hold(ax_pwr, 'on');
    end
    
    if ~isempty(signale2) && signale2.P_pack_ok
        plot(ax_pwr, signale2.P_pack.Time + offset2, signale2.P_pack.Data / 1000, ...
            'Color', C.rot, 'LineWidth', 1.2, 'DisplayName', 'S2');
    end
    
    if ishold(ax_pwr)
        hold(ax_pwr, 'off');
        legend(ax_pwr, 'Location', 'best', 'TextColor', C.grau, ...
            'Color', [0.13, 0.13, 0.13], 'EdgeColor', C.grau2, 'FontSize', 8);
    end
    xlabel(ax_pwr, 'Zeit (s)', 'Color', C.grau, 'FontSize', 8);
    ylabel(ax_pwr, 'P pack (kW)', 'Color', C.grau, 'FontSize', 8);
end