function build_tab_dynamik(tab, signale, cfg)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
kpis = {
    'V max', signal_max_wert(signale, 'speed_can', '--'), 'km/h';
    'a lat max', signal_max_wert(signale, 'INS_acc_y_can', '--'), 'g';
    'a long max', signal_max_wert(signale, 'INS_acc_x_can', '--'), 'g';
    'Yaw max', signal_max_wert(signale, 'INS_ang_vel_z_can', '--'), '°/s';
    };
build_kpi_zeile_custom(tab, kpis, cfg, [10, 840, 780, 80]);

ax1 = erstelle_plot_bereich(tab, [10, 600, 780, 230], 'Geschwindigkeit & Lenkung', cfg);
plot_oder_leer(ax1, signale, {'speed_can', 'steering_wheel_angle_can', 'DL_Yaw_rate_can'}, ...
    {'Speed (km/h)', 'Lenkwinkel (°)', 'Yaw rate (°/s)'}, cfg);

ax2 = erstelle_plot_bereich(tab, [10, 370, 780, 220], 'Bremsen & APPS', cfg);
plot_oder_leer(ax2, signale, {'pbrake_front_can', 'pbrake_rear_can', 'apps_res_can', 'brake_balance_front_can'}, ...
    {'p front (bar)', 'p rear (bar)', 'APPS (%)', 'Balance front (%)'}, cfg);

ax3 = erstelle_plot_bereich(tab, [10, 140, 780, 220], 'Fahrwerk — Rocker', cfg);
plot_oder_leer(ax3, signale, {'rocker_fl_can', 'rocker_fr_can', 'rocker_rl_can', 'rocker_rr_can'}, ...
    {'Rocker FL', 'Rocker FR', 'Rocker RL', 'Rocker RR'}, cfg);

ax_gg = erstelle_plot_bereich(tab, [810, 560, 770, 360], 'g-g Diagramm', cfg);
plot_gg(ax_gg, signale, cfg);

ax_gps = erstelle_plot_bereich(tab, [810, 300, 770, 250], 'GPS Track (INS dead-reckoning)', cfg);
plot_gps(ax_gps, signale, cfg);

ax4 = erstelle_plot_bereich(tab, [810, 80, 770, 210], 'Beschleunigungen (g)', cfg);
plot_oder_leer(ax4, signale, {'INS_acc_x_can', 'INS_acc_y_can', 'INS_acc_z_can'}, ...
    {'a long (g)', 'a lat (g)', 'a vert (g)'}, cfg);
end