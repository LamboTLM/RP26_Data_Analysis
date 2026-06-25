function kpi_daten = berechne_kpis(signale, cfg)
% Autor: [Benutzer]
% Datum: 2026-06-24

fn_soc = signal_zu_feldname('ams_capacity_fl_can');
kpi_daten = {
    'V max', signal_max_wert(signale, 'speed_can', '--'), 'km/h';
    'SoC', letzter_wert(signale, fn_soc, '--'), '%';
    'Verbrauch', feld_wert_str(signale, 'E_total_kWh', 'E_total_ok', '--'), 'kWh';
    'T mot max', signal_max_wert(signale, 'unitek_rl_motor_temp_can', '--'), '°C';
    'T bat max', signal_max_wert(signale, 'ams_cell_max_temp_can', '--'), '°C';
    'η Ø', feld_wert_str(signale, 'eta_powertrain', 'eta_powertrain_ok', '--', 'mean_data'), '%';
    };
end