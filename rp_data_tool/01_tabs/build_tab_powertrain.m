function build_tab_powertrain(tab, signale, cfg)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
raeder = cfg.fahrzeug.raeder;
labels = {'FL — Front Left', 'FR — Front Right', 'RL — Rear Left', 'RR — Rear Right'};
xpos = [10, 400, 800, 1190];

for i = 1:numel(raeder)
    build_inverter_karte(tab, signale, raeder{i}, labels{i}, cfg, [xpos(i), 730, 375, 175]);
end

ax1 = erstelle_plot_bereich(tab, [10, 510, 770, 210], 'Drehzahl alle Achsen (rpm)', cfg);
plot_oder_leer(ax1, signale, arrayfun(@(w) sprintf('unitek_%s_speed_motor_ist_can', w{1}), raeder, 'uni', 0), {'FL', 'FR', 'RL', 'RR'}, cfg);

ax2 = erstelle_plot_bereich(tab, [800, 510, 780, 210], 'Drehmoment alle Achsen (Nm)', cfg);
plot_oder_leer(ax2, signale, arrayfun(@(w) sprintf('unitek_%s_torque_motor_ist_can', w{1}), raeder, 'uni', 0), {'FL', 'FR', 'RL', 'RR'}, cfg);

ax3 = erstelle_plot_bereich(tab, [10, 280, 770, 220], 'Torque Vectoring — tqv_result', cfg);
plot_oder_leer(ax3, signale, {'tqv_result_fl_can', 'tqv_result_fr_can', 'tqv_result_rl_can', 'tqv_result_rr_can'}, {'FL', 'FR', 'RL', 'RR'}, cfg);

ax4 = erstelle_plot_bereich(tab, [800, 280, 780, 220], 'Derating Flags', cfg);
plot_oder_leer(ax4, signale, {'drive_deratingMotorTemp_b_can', 'drive_deratingAccuTemp_b_can', 'drive_deratingInverterTemp_b_can', 'drive_deratingAccuSoc_b_can'}, {'MotorTemp', 'AccuTemp', 'InvTemp', 'AccuSoC'}, cfg);

ax5 = erstelle_plot_bereich(tab, [10, 60, 770, 210], 'Tq Limits & Target', cfg);
plot_oder_leer(ax5, signale, {'tq_vehicle_pos_limit_can', 'tq_vehicle_neg_limit_can', 'drive_pwtrTqTarget_can'}, {'Limit+', 'Limit-', 'Target'}, cfg);

build_rad_leistung_zusammenfassung(tab, signale, cfg, [800, 60, 780, 210]);
end