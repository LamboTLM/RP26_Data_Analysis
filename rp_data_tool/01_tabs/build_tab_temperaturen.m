function build_tab_temperaturen(tab, signale, cfg)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
ax1 = erstelle_plot_bereich(tab, [10, 680, 770, 220], 'Motor Temperaturen (°C)', cfg);
plot_oder_leer(ax1, signale, {'unitek_fl_motor_temp_can', 'unitek_fr_motor_temp_can', ...
    'unitek_rl_motor_temp_can', 'unitek_rr_motor_temp_can'}, ...
    {'T mot FL', 'T mot FR', 'T mot RL', 'T mot RR'}, cfg);

ax2 = erstelle_plot_bereich(tab, [800, 680, 770, 220], 'IGBT / Inverter Temperaturen (°C)', cfg);
plot_oder_leer(ax2, signale, {'unitek_fl_igbt_temp_can', 'unitek_fr_igbt_temp_can', ...
    'unitek_rl_igbt_temp_can', 'unitek_rr_igbt_temp_can'}, ...
    {'T IGBT FL', 'T IGBT FR', 'T IGBT RL', 'T IGBT RR'}, cfg);

ax3 = erstelle_plot_bereich(tab, [10, 460, 770, 210], 'Akku Zelltemperaturen (°C)', cfg);
plot_oder_leer(ax3, signale, {'ams_cell_max_temp_can', 'ams_cell_avg_temp_can', 'ams_cell_min_temp_can'}, ...
    {'T max', 'T avg', 'T min'}, cfg);

ax4 = erstelle_plot_bereich(tab, [800, 460, 770, 210], 'Bremsscheiben & Rotoren (°C)', cfg);
plot_oder_leer(ax4, signale, {'wpmd_brake_temp_fl_can', 'wpmd_brake_temp_fr_can', ...
    'wpmd_rotor_temp_fl_can', 'wpmd_rotor_temp_fr_can'}, ...
    {'Brake FL', 'Brake FR', 'Rotor FL', 'Rotor FR'}, cfg);

ax_hm = erstelle_plot_bereich(tab, [10, 220, 770, 230], 'Zelltemperatur-Heatmap (48 Sensoren)', cfg);
plot_zellen_heatmap(ax_hm, signale, 'temp', cfg);

ax5 = erstelle_plot_bereich(tab, [800, 220, 770, 230], 'Getriebe & Transmission Temp (°C)', cfg);
plot_oder_leer(ax5, signale, {'wpmd_trans_temp_fl_can', 'wpmd_trans_temp_fr_can'}, ...
    {'Trans FL', 'Trans FR'}, cfg);

build_temp_status_zeile(tab, signale, cfg, [10, 120, 1560, 90]);
end