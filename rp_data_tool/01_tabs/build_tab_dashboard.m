function build_tab_dashboard(tab, signale, meta, cfg)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
kpi_daten = berechne_kpis(signale, cfg);
build_kpi_zeile(tab, kpi_daten, cfg, [10, 820, 760, 90]);
build_status_badges(tab, signale, cfg, [10, 760, 760, 55]);

ax1 = erstelle_plot_bereich(tab, [10, 540, 760, 210], 'Speed & Torque', cfg);
plot_oder_leer(ax1, signale, {'speed_can', 'drive_pwtrTqTarget_can', 'tq_vehicle_pos_limit_can'}, ...
    {'Speed (km/h)', 'Tq Target (Nm)', 'Tq Limit+ (Nm)'}, cfg);

build_runden_tabelle(tab, signale, cfg, [10, 350, 760, 180]);

ax2 = erstelle_plot_bereich(tab, [10, 130, 760, 210], 'Pack Power', cfg);
plot_oder_leer(ax2, signale, {'P_pack'}, {'P pack (W)'}, cfg, true);

ax_gps = erstelle_plot_bereich(tab, [800, 540, 780, 370], 'GPS Track (INS dead-reckoning)', cfg);
plot_gps(ax_gps, signale, cfg);

ax_gg = erstelle_plot_bereich(tab, [800, 290, 780, 240], 'g-g Diagramm', cfg);
plot_gg(ax_gg, signale, cfg);

ax3 = erstelle_plot_bereich(tab, [800, 80, 780, 200], 'SoC & Energie', cfg);
plot_oder_leer(ax3, signale, {'ams_capacity_fl_can'}, {'SoC (%)'}, cfg);
end