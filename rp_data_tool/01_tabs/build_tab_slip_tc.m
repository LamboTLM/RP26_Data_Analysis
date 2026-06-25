function build_tab_slip_tc(tab, signale, cfg)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
kpis = {
    'TC enabled', letzter_bool_str(signale, 'tqv_status_tc_enabled_b_can'), '';
    'TQV enabled', letzter_bool_str(signale, 'tqv_status_tqv_enabled_b_can'), '';
    'GPS Fix', letzter_bool_str(signale, 'tqv_status_gps_fix_aquired_b_can'), '';
    'TQV Strength', letzter_wert(signale, signal_zu_feldname('tqv_status_tqv_strength_can'), '--'), '';
    'µ Factor', letzter_wert(signale, signal_zu_feldname('tqv_status_tc_mu_factor_can'), '--'), '';
    };
build_kpi_zeile_custom(tab, kpis, cfg, [10, 840, 1560, 80]);

ax1 = erstelle_plot_bereich(tab, [10, 600, 770, 230], 'Slip Compare alle Raeder', cfg);
plot_oder_leer(ax1, signale, {'slip_compare_val_fl_can', 'slip_compare_val_fr_can', ...
    'slip_compare_val_rl_can', 'slip_compare_val_rr_can'}, {'Slip FL', 'Slip FR', 'Slip RL', 'Slip RR'}, cfg);

ax2 = erstelle_plot_bereich(tab, [800, 600, 770, 230], 'TC Eingriff & Slip Target', cfg);
plot_oder_leer(ax2, signale, {'tqv_status_tc_slip_target_can', 'tqv_status_tqv_strength_can', ...
    'tqv_status_tqv_base_strength_can'}, {'Slip Target', 'TQV Strength', 'Base Strength'}, cfg);

ax3 = erstelle_plot_bereich(tab, [10, 370, 770, 220], 'Radgeschwindigkeiten (rpm)', cfg);
plot_oder_leer(ax3, signale, {'tqv_rot_spd_fl_can', 'tqv_rot_spd_fr_can', 'tqv_rot_spd_rl_can', 'tqv_rot_spd_rr_can'}, ...
    {'FL', 'FR', 'RL', 'RR'}, cfg);

ax4 = erstelle_plot_bereich(tab, [800, 370, 770, 220], 'Tq Limits Front / Rear (Nm)', cfg);
plot_oder_leer(ax4, signale, {'tqv_tqLimitPos_front_can', 'tqv_tqLimitNeg_front_can', ...
    'tqv_tqLimitPos_rear_can', 'tqv_tqLimitNeg_rear_can'}, ...
    {'Lim+ Front', 'Lim- Front', 'Lim+ Rear', 'Lim- Rear'}, cfg);

ax5 = erstelle_plot_bereich(tab, [10, 140, 770, 220], 'TQV Torque Results (Nm)', cfg);
plot_oder_leer(ax5, signale, {'tqv_result_fl_can', 'tqv_result_fr_can', 'tqv_result_rl_can', 'tqv_result_rr_can'}, ...
    {'TQV FL', 'TQV FR', 'TQV RL', 'TQV RR'}, cfg);

ax6 = erstelle_plot_bereich(tab, [800, 140, 770, 220], 'µ Faktor & TQV Strength ueber Zeit', cfg);
plot_oder_leer(ax6, signale, {'tqv_status_tc_mu_factor_can', 'tqv_status_tqv_strength_can'}, ...
    {'µ factor', 'TQV strength'}, cfg);
end