function build_tab_effizienz(tab, signale, cfg)
%BUILD_TAB_EFFIZIENZ Erstellt den Efficiency-Analyse-Tab.
%
%   Eingabe:
%       tab     — ui.Tab Objekt
%       signale — Struct mit extrahierten Signalen
%       cfg     — Config-Struct
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

    C = farben();

    %% --- KPI-Berechnungen ---
    e_total   = '--';
    e_regen   = '--';
    e_net     = '--';
    eta_avg   = '--';
    regen_pct = '--';

    if isfield(signale, 'E_total_ok') && signale.E_total_ok
        val = sicherer_skalar(signale, 'E_total_kWh');
        if ~isempty(val)
            e_total = sprintf('%.2f', val);
        end
    end

    if isfield(signale, 'E_regen_ok') && signale.E_regen_ok
        val = sicherer_skalar(signale, 'E_regen_kWh');
        if ~isempty(val)
            e_regen = sprintf('%.2f', val);
        end
    end

    if isfield(signale, 'E_total_ok') && signale.E_total_ok && ...
       isfield(signale, 'E_regen_ok') && signale.E_regen_ok
        e_total_val = sicherer_skalar(signale, 'E_total_kWh');
        e_regen_val = sicherer_skalar(signale, 'E_regen_kWh');
        if ~isempty(e_total_val) && ~isempty(e_regen_val)
            e_net = sprintf('%.2f', e_total_val - e_regen_val);
            if abs(e_total_val) > 0.001
                regen_pct = sprintf('%.1f', e_regen_val / e_total_val * 100);
            end
        end
    end

    if isfield(signale, 'eta_powertrain_ok') && signale.eta_powertrain_ok
        eta_roh = util.extrahiere_rohdaten(signale.eta_powertrain);
        if ~isempty(eta_roh)
            eta_gueltig = eta_roh(eta_roh > cfg.schwellen.eta_min_wert);
            if ~isempty(eta_gueltig)
                eta_avg = sprintf('%.1f', mean(eta_gueltig, 'omitnan'));
            end
        end
    end

    kpis = {
        'Energie gesamt',  e_total,   'kWh';
        'Rekuperation',    e_regen,   'kWh';
        'Netto-Verbrauch', e_net,     'kWh';
        'Regen-Anteil',    regen_pct, '%';
        'Ø η Powertrain',  eta_avg,   '%';
    };
    build_kpi_zeile_custom(tab, kpis, cfg, [10, 840, 1560, 80]);

    %% --- Plot 1: Powertrain Wirkungsgrad ---
    ax1 = erstelle_plot_bereich(tab, [10, 600, 770, 230], 'Powertrain Wirkungsgrad η (%)', cfg);
    plot_oder_leer(ax1, signale, {'eta_powertrain'}, {'η (Pack→Rad)'}, cfg, true);

    if isfield(signale, 'eta_powertrain_ok') && signale.eta_powertrain_ok
        eta_roh = util.extrahiere_rohdaten(signale.eta_powertrain);
        eta_gueltig = eta_roh(eta_roh > cfg.schwellen.eta_min_wert);
        if ~isempty(eta_gueltig)
            eta_mittel = mean(eta_gueltig, 'omitnan');
            hold(ax1, 'on');
            yline(ax1, eta_mittel, '--', 'Color', C.orange, 'LineWidth', 1.2, 'Label', 'Ø');
            hold(ax1, 'off');
        end
    end

    %% --- Plot 2: Pack vs. Mech. Leistung ---
    ax2 = erstelle_plot_bereich(tab, [800, 600, 770, 230], 'Pack vs. Mech. Leistung (W)', cfg);
    plot_oder_leer(ax2, signale, {'P_pack', 'P_mech_total'}, {'P pack', 'P mech total'}, cfg, true);

    %% --- Plot 3: Inverter Verlustleistung ---
    ax3 = erstelle_plot_bereich(tab, [10, 370, 770, 220], 'Inverter Verlustleistung pro Achse (W)', cfg);
    plot_oder_leer(ax3, signale, {'P_loss_fl', 'P_loss_fr', 'P_loss_rl', 'P_loss_rr'}, ...
        {'P loss FL', 'P loss FR', 'P loss RL', 'P loss RR'}, cfg, true);

    %% --- Plot 4: Motor Temperaturen ---
    ax4 = erstelle_plot_bereich(tab, [800, 370, 770, 220], 'Motor Temperaturen (°C)', cfg);
    plot_oder_leer(ax4, signale, {
        'unitek_fl_motor_temp_can', 'unitek_fr_motor_temp_can', ...
        'unitek_rl_motor_temp_can', 'unitek_rr_motor_temp_can'}, ...
        {'T mot FL', 'T mot FR', 'T mot RL', 'T mot RR'}, cfg, true);

    %% --- Plot 5: Rekuperationsleistung ---
    ax5 = erstelle_plot_bereich(tab, [10, 60, 770, 290], 'Rekuperationsleistung (kW)', cfg);
    plot_oder_leer(ax5, signale, {'P_regen_total'}, {'P regen'}, cfg, true);

    %% --- Plot 6: DC-Link Spannung pro Achse ---
    ax6 = erstelle_plot_bereich(tab, [800, 60, 770, 290], 'DC-Link Spannung pro Achse (V)', cfg);
    plot_oder_leer(ax6, signale, {
        'unitek_fl_v_dc_link_can', 'unitek_fr_v_dc_link_can', ...
        'unitek_rl_v_dc_link_can', 'unitek_rr_v_dc_link_can'}, ...
        {'U dc FL', 'U dc FR', 'U dc RL', 'U dc RR'}, cfg, true);
end

%% Lokale Hilfsfunktion
function val = sicherer_skalar(signale, feldname)
%SICHERER_SKALAR Extrahiert den letzten Skalarwert aus einem Signal.
%
%   Unterstuetzt timeseries, Struct mit .Data und numerische Arrays.

    val = [];
    if ~isfield(signale, feldname)
        return;
    end

    roh = signale.(feldname);

    if isa(roh, 'timeseries')
        daten = roh.Data;
    elseif isstruct(roh) && isfield(roh, 'Data')
        daten = roh.Data;
    elseif isnumeric(roh)
        daten = roh;
    else
        return;
    end

    if isempty(daten)
        return;
    end

    val = daten(end);
end