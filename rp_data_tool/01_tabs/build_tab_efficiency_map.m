function build_tab_efficiency_map(tab, signale, cfg)
    % Efficiency Map: Wirkungsgrad ueber Drehzahl/Drehmoment
    % Autor: [Benutzer]
    % Datum: 2026-06-24

    C = cfg.farben;
    
    % KPIs
    eta_max = '--'; eta_bereich = '--';
    if isfield(signale, 'eta_powertrain_ok') && signale.eta_powertrain_ok
        eta_daten = signale.eta_powertrain.Data(signale.eta_powertrain.Data > 5);
        if ~isempty(eta_daten)
            eta_max = sprintf('%.1f', max(eta_daten));
            eta_bereich = sprintf('%.1f - %.1f', min(eta_daten), max(eta_daten));
        end
    end
    
    kpis = {
        'η max', eta_max, '%';
        'η Bereich', eta_bereich, '%';
        'P mech max', signal_max_wert(signale, 'P_mech_total', '--'), 'W';
    };
    build_kpi_zeile_custom(tab, kpis, cfg, [10, 840, 1560, 80]);

    % Efficiency Map pro Rad
    raeder = cfg.fahrzeug.raeder;
    pos = {[10, 470, 770, 360], [800, 470, 770, 360], [10, 60, 770, 360], [800, 60, 770, 360]};
    
    for i = 1:numel(raeder)
        rad = raeder{i};
        ax = erstelle_plot_bereich(tab, pos{i}, sprintf('Efficiency Map %s', upper(rad)), cfg);
        
        spd_fn = signal_zu_feldname(['unitek_' rad '_speed_motor_ist_can']);
        tq_fn = signal_zu_feldname(['unitek_' rad '_torque_motor_ist_can']);
        pdc_fn = ['P_dc_' rad];
        pmech_fn = ['P_mech_' rad];
        
        if isfield(signale, pdc_fn) && signale.([pdc_fn '_ok']) && ...
           isfield(signale, pmech_fn) && signale.([pmech_fn '_ok']) && ...
           isfield(signale, spd_fn) && signale.([spd_fn '_ok']) && ...
           isfield(signale, tq_fn) && signale.([tq_fn '_ok'])
            try
                % Resample auf gemeinsame Zeitbasis
                t_ref = signale.(pdc_fn).Time;
                spd = sicheres_resample(signale.(spd_fn), t_ref);
                tq = sicheres_resample(signale.(tq_fn), t_ref);
                P_dc = signale.(pdc_fn).Data;
                P_mech = sicheres_resample(signale.(pmech_fn), t_ref).Data;
                
                % Wirkungsgrad berechnen
                eta = zeros(size(P_dc));
                gueltig = abs(P_dc) > 100;
                eta(gueltig) = P_mech(gueltig) ./ P_dc(gueltig) * 100;
                eta = max(0, min(100, eta));
                
                % Nur gueltige Punkte
                valid = gueltig & eta > 5 & eta < 100;
                spd_v = spd.Data(valid);
                tq_v = tq.Data(valid);
                eta_v = eta(valid);
                
                if numel(eta_v) > 10
                    % 2D-Histogramm / Binning fuer saubere Darstellung
                    spd_edges = linspace(min(spd_v), max(spd_v), 30);
                    tq_edges = linspace(min(tq_v), max(tq_v), 30);
                    
                    eta_map = nan(numel(tq_edges)-1, numel(spd_edges)-1);
                    for si = 1:numel(spd_edges)-1
                        for ti = 1:numel(tq_edges)-1
                            mask = spd_v >= spd_edges(si) & spd_v < spd_edges(si+1) & ...
                                   tq_v >= tq_edges(ti) & tq_v < tq_edges(ti+1);
                            if any(mask)
                                eta_map(ti, si) = mean(eta_v(mask), 'omitnan');
                            end
                        end
                    end
                    
                    imagesc(ax, spd_edges(1:end-1), tq_edges(1:end-1), eta_map);
                    set(ax, 'YDir', 'normal');
                    colormap(ax, C.map.teal);
                    clim(ax, [50, 95]);
                    cb = colorbar(ax);
                    cb.Color = C.grau;
                    cb.Label.String = 'η (%)';
                    
                    xlabel(ax, 'Drehzahl (rpm)', 'Color', C.grau, 'FontSize', 8);
                    ylabel(ax, 'Drehmoment (Nm)', 'Color', C.grau, 'FontSize', 8);
                    
                    hold(ax, 'on');
                    % Betriebspunkte overlay
                    scatter(ax, spd_v(1:5:end), tq_v(1:5:end), 4, eta_v(1:5:end), ...
                        'filled', 'MarkerFaceAlpha', 0.3);
                    hold(ax, 'off');
                else
                    markiere_leer(ax, 'Zu wenig gueltige Daten', cfg);
                end
            catch ME
                markiere_leer(ax, sprintf('Fehler: %s', ME.message), cfg);
            end
        else
            markiere_leer(ax, sprintf('Daten fuer %s nicht verfuegbar', upper(rad)), cfg);
        end
    end
end