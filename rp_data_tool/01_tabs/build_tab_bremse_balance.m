function build_tab_bremse_balance(tab, signale, cfg)
    % Detaillierte Bremsanalyse mit Balance-Berechnung
    % Autor: [Benutzer]
    % Datum: 2026-06-24

    C = cfg.farben;
    
    % KPIs
    p_front_max = signal_max_wert(signale, 'pbrake_front_can', '--');
    p_rear_max = signal_max_wert(signale, 'pbrake_rear_can', '--');
    apps_max = signal_max_wert(signale, 'apps_res_can', '--');
    
    kpis = {
        'p front max', p_front_max, 'bar';
        'p rear max', p_rear_max, 'bar';
        'Balance Ø', letzter_wert(signale, signal_zu_feldname('brake_balance_front_can'), '--'), '%';
        'APPS max', apps_max, '%';
    };
    build_kpi_zeile_custom(tab, kpis, cfg, [10, 840, 1560, 80]);

    % Bremsdruck Front/Rear
    ax1 = erstelle_plot_bereich(tab, [10, 620, 770, 210], 'Bremsdruck Front vs. Rear', cfg);
    plot_oder_leer(ax1, signale, {'pbrake_front_can', 'pbrake_rear_can'}, ...
        {'p front (bar)', 'p rear (bar)'}, cfg);

    % Balance ueber Zeit
    ax2 = erstelle_plot_bereich(tab, [800, 620, 770, 210], 'Bremsbalance Front (%)', cfg);
    plot_oder_leer(ax2, signale, {'brake_balance_front_can'}, {'Balance front (%)'}, cfg);

    % p-Vergleich als Scatter (Balance-Diagnose)
    ax3 = erstelle_plot_bereich(tab, [10, 340, 770, 270], 'Bremsdruck-Korrelation Front/Rear', cfg);
    fn_pf = signal_zu_feldname('pbrake_front_can');
    fn_pr = signal_zu_feldname('pbrake_rear_can');
    fn_spd = signal_zu_feldname('speed_can');
    
    if isfield(signale, fn_pf) && signale.([fn_pf '_ok']) && ...
       isfield(signale, fn_pr) && signale.([fn_pr '_ok'])
        try
            pf = signale.(fn_pf);
            pr = sicheres_resample(signale.(fn_pr), pf.Time);
            
            % Nur Bremsphasen (p > 1 bar)
            brems_mask = pf.Data > 1 & pr.Data > 1;
            
            if any(brems_mask)
                pf_b = pf.Data(brems_mask);
                pr_b = pr.Data(brems_mask);
                
                % Farbe nach Geschwindigkeit
                if isfield(signale, fn_spd) && signale.([fn_spd '_ok'])
                    spd = sicheres_resample(signale.(fn_spd), pf.Time);
                    spd_b = spd.Data(brems_mask);
                    scatter(ax3, pf_b, pr_b, 8, spd_b, 'filled', 'MarkerFaceAlpha', 0.6);
                    colormap(ax3, 'hot');
                    cb = colorbar(ax3);
                    cb.Color = C.grau;
                    cb.Label.String = 'Speed (km/h)';
                else
                    scatter(ax3, pf_b, pr_b, 8, 'filled', ...
                        'MarkerFaceColor', C.rot, 'MarkerFaceAlpha', 0.5);
                end
                
                % Ideale Balance-Linie (1:1)
                hold(ax3, 'on');
                p_max = max(max(pf_b), max(pr_b));
                plot(ax3, [0, p_max], [0, p_max], '--', 'Color', C.grau2, 'LineWidth', 1.2, ...
                    'DisplayName', '1:1 Balance');
                hold(ax3, 'off');
                
                xlabel(ax3, 'p front (bar)', 'Color', C.grau, 'FontSize', 8);
                ylabel(ax3, 'p rear (bar)', 'Color', C.grau, 'FontSize', 8);
                axis(ax3, 'equal');
                legend(ax3, 'Location', 'best', 'TextColor', C.grau, ...
                    'Color', [0.13, 0.13, 0.13], 'EdgeColor', C.grau2, 'FontSize', 8);
            else
                markiere_leer(ax3, 'Keine Bremsdaten > 1 bar', cfg);
            end
        catch ME
            markiere_leer(ax3, sprintf('Fehler: %s', ME.message), cfg);
        end
    else
        markiere_leer(ax3, 'Bremsdruck-Daten nicht verfuegbar', cfg);
    end

    % APPS vs. Bremsdruck (Plausibilitaet)
    ax4 = erstelle_plot_bereich(tab, [800, 340, 770, 270], 'APPS vs. Bremsdruck (Plausibilitaet)', cfg);
    fn_apps = signal_zu_feldname('apps_res_can');
    
    if isfield(signale, fn_pf) && signale.([fn_pf '_ok']) && ...
       isfield(signale, fn_apps) && signale.([fn_apps '_ok'])
        try
            apps = sicheres_resample(signale.(fn_apps), pf.Time);
            
            % Farbe nach Zeit fuer Trace-Erkennung
            n_punkte = numel(pf.Data);
            scatter(ax4, apps.Data, pf.Data, 6, pf.Time, 'filled', 'MarkerFaceAlpha', 0.5);
            colormap(ax4, 'parula');
            cb = colorbar(ax4);
            cb.Color = C.grau;
            cb.Label.String = 'Zeit (s)';
            
            xlabel(ax4, 'APPS (%)', 'Color', C.grau, 'FontSize', 8);
            ylabel(ax4, 'p front (bar)', 'Color', C.grau, 'FontSize', 8);
            
            % APPS-Bremsen-Implausibilitaet markieren
            hold(ax4, 'on');
            impl_mask = apps.Data > 25 & pf.Data > 5; % APPS > 25% UND Bremsen > 5 bar
            if any(impl_mask)
                scatter(ax4, apps.Data(impl_mask), pf.Data(impl_mask), 20, ...
                    'MarkerFaceColor', 'none', 'MarkerEdgeColor', C.rot, ...
                    'LineWidth', 1.5, 'DisplayName', 'Implausibilitaet!');
                legend(ax4, 'Location', 'best', 'TextColor', C.grau, ...
                    'Color', [0.13, 0.13, 0.13], 'EdgeColor', C.grau2, 'FontSize', 8);
            end
            hold(ax4, 'off');
        catch ME
            markiere_leer(ax4, sprintf('Fehler: %s', ME.message), cfg);
        end
    else
        markiere_leer(ax4, 'APPS oder Bremsdruck nicht verfuegbar', cfg);
    end

    % Bremsleistung (abschaetzung)
    ax5 = erstelle_plot_bereich(tab, [10, 60, 1560, 270], 'Bremsleistung & Rekuperation', cfg);
    if signale.P_pack_ok
        try
            t = signale.P_pack.Time;
            P = signale.P_pack.Data;
            
            % Bremsleistung = negative Pack-Leistung
            P_bremse = -P .* (P < 0); % [W] nur Rekuperation
            
            % Bremsdruck als Proxy fuer mechanische Bremsleistung
            if isfield(signale, fn_pf) && signale.([fn_pf '_ok'])
                pf_r = sicheres_resample(signale.(fn_pf), t);
                % Annahme: p * konstante = mechanische Bremsleistung (qualitativ)
                P_mech_bremse = pf_r.Data * 100; % [a.u.]
                
                yyaxis(ax5, 'left');
                plot(ax5, t, P_bremse / 1000, 'Color', C.gruen, 'LineWidth', 1.2, ...
                    'DisplayName', 'Rekuperation (kW)');
                ylabel(ax5, 'Rekuperation (kW)', 'Color', C.gruen, 'FontSize', 8);
                ax5.YColor = C.gruen;
                
                yyaxis(ax5, 'right');
                plot(ax5, t, P_mech_bremse, 'Color', C.orange, 'LineWidth', 1.0, ...
                    'DisplayName', 'Bremsdruck proxy (a.u.)');
                ylabel(ax5, 'Bremsdruck proxy (a.u.)', 'Color', C.orange, 'FontSize', 8);
                ax5.YColor = C.orange;
                
                xlabel(ax5, 'Zeit (s)', 'Color', C.grau, 'FontSize', 8);
                legend(ax5, 'Location', 'best', 'TextColor', C.grau, ...
                    'Color', [0.13, 0.13, 0.13], 'EdgeColor', C.grau2, 'FontSize', 8);
            else
                plot(ax5, t, P_bremse / 1000, 'Color', C.gruen, 'LineWidth', 1.2);
                xlabel(ax5, 'Zeit (s)', 'Color', C.grau, 'FontSize', 8);
                ylabel(ax5, 'Rekuperation (kW)', 'Color', C.grau, 'FontSize', 8);
            end
        catch ME
            markiere_leer(ax5, sprintf('Fehler: %s', ME.message), cfg);
        end
    else
        markiere_leer(ax5, 'Pack-Leistung nicht verfuegbar', cfg);
    end
end