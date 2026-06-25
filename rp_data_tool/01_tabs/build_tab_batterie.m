function build_tab_batterie(tab, signale, cfg)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
fn_V = signal_zu_feldname('ams_overall_voltage_can');
fn_I = signal_zu_feldname('IVT_Result_I_can');
fn_mn = signal_zu_feldname('ams_cell_min_voltage_can');
fn_mx = signal_zu_feldname('ams_cell_max_voltage_can');
fn_Tm = signal_zu_feldname('ams_cell_max_temp_can');
fn_soc = signal_zu_feldname('ams_capacity_fl_can');

kpis = {
    'Gesamtspannung', letzter_wert(signale, fn_V, '--'), 'V';
    'SoC', letzter_wert(signale, fn_soc, '--'), '%';
    'Strom (IVT)', letzter_wert(signale, fn_I, '--'), 'A';
    'V cell min', letzter_wert(signale, fn_mn, '--'), 'V';
    'V cell max', letzter_wert(signale, fn_mx, '--'), 'V';
    'T cell max', letzter_wert(signale, fn_Tm, '--'), '°C';
    };
build_kpi_zeile_custom(tab, kpis, cfg, [10, 840, 1560, 80]);

ax1 = erstelle_plot_bereich(tab, [10, 620, 770, 210], 'Spannung & Strom', cfg);
plot_oder_leer(ax1, signale, {'ams_overall_voltage_can', 'IVT_Result_I_can'}, {'V pack (V)', 'I (A)'}, cfg);

ax2 = erstelle_plot_bereich(tab, [10, 400, 770, 210], 'Zelltemperaturen', cfg);
plot_oder_leer(ax2, signale, {'ams_cell_max_temp_can', 'ams_cell_avg_temp_can', 'ams_cell_min_temp_can'}, ...
    {'T max', 'T avg', 'T min'}, cfg);

ax3 = erstelle_plot_bereich(tab, [10, 180, 770, 210], 'AIR Status', cfg);
plot_oder_leer(ax3, signale, {'air_minus_closed_b_can', 'air_plus_closed_b_can', 'precharge_closed_b_can'}, ...
    {'AIR-', 'AIR+', 'Precharge'}, cfg);

ax_hm = erstelle_plot_bereich(tab, [800, 400, 770, 440], 'Zellspannungs-Heatmap (144 Zellen)', cfg);
plot_zellen_heatmap(ax_hm, signale, 'voltage', cfg);

ax_hm2 = erstelle_plot_bereich(tab, [800, 180, 770, 210], 'Zelltemperatur-Heatmap (48 Sensoren)', cfg);
plot_zellen_heatmap(ax_hm2, signale, 'temp', cfg);

build_ams_fehler(tab, signale, cfg, [10, 80, 1560, 90]);
end