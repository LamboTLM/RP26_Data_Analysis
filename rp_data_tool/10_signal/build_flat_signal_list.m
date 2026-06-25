function eintraege = build_flat_signal_list(cfg)
    % Zentrale flache Signalliste fuer Tab "Alle Signale"
    % Autor: [Benutzer]
    % Datum: 2026-06-24

    e = {};

    e{end + 1} = struct('header', 'Geschwindigkeit & Lenkung');
    e = [e, {'speed_can', 'steering_wheel_angle_can', ...
             'steering_wheel_angle_e_b_can', 'INS_ang_vel_z_can', 'DL_Yaw_rate_can'}];

    e{end + 1} = struct('header', 'APPS');
    e = [e, {'apps1_can', 'apps2_can', 'apps3_can', 'apps_res_can', ...
             'apps_state_can', 'apps1_e_b_can', 'apps2_e_b_can', 'apps_bse_impl_b_can'}];

    e{end + 1} = struct('header', 'Bremsen');
    e = [e, {'brake_pressed_b_can', 'pbrake_front_can', 'pbrake_rear_can', ...
             'brake_balance_front_can', 'pbrake_front_e_b_can', 'pbrake_rear_e_b_can'}];

    e{end + 1} = struct('header', 'Fahrwerk / Rocker');
    e = [e, {'rocker_fl_can', 'rocker_fr_can', 'rocker_rl_can', 'rocker_rr_can', ...
             'rocker_fl_e_b_can', 'rocker_fr_e_b_can'}];

    e{end + 1} = struct('header', 'INS / IMU');
    e = [e, {'INS_acc_x_can', 'INS_acc_y_can', 'INS_acc_z_can', ...
             'INS_vel_x_can', 'INS_vel_y_can'}];

    e{end + 1} = struct('header', 'Lap');
    e = [e, {'lap_cnt_can', 'laptime_can', 'lap_time_last_can', ...
             'lap_time_best_can', 'lap_dist_can', 'lap_trigger_b_can'}];

    e{end + 1} = struct('header', 'WPMD');
    e = [e, {'wpmd_brake_temp_fl_can', 'wpmd_brake_temp_fr_can', ...
             'wpmd_rotor_temp_fl_can', 'wpmd_rotor_temp_fr_can', ...
             'wpmd_trans_temp_fl_can', 'wpmd_trans_temp_fr_can', ...
             'wpmd_brake_temp_e_b_fl_can', 'wpmd_brake_temp_e_b_fr_can'}];

    e{end + 1} = struct('header', 'Batterie Ueberblick');
    e = [e, {'ams_overall_voltage_can', 'ams_capacity_fl_can', ...
             'IVT_Result_I_can', 'IVT_Result_U2_Post_Airs_can', ...
             'IVT_Result_U1_Pre_Airs_can', 'IVT_Result_W_can'}];

    e{end + 1} = struct('header', 'Zelle min/max');
    e = [e, {'ams_cell_min_voltage_can', 'ams_cell_max_voltage_can', ...
             'ams_cell_min_temp_can', 'ams_cell_avg_temp_can', 'ams_cell_max_temp_can'}];

    e{end + 1} = struct('header', 'AMS Status');
    e = [e, {'ams_ok_b_can', 'ams_ok_pst_b_can', 'ams_cell_overvoltage_b_can', ...
             'ams_cell_undervoltage_b_can', 'ams_cell_overtemp_b_can', ...
             'ams_cell_undertemp_b_can', 'ams_com_error_can', 'ams_slave_fail_b_can', ...
             'ams_balancing_active_b_can', 'ams_balance_fb_err_b_can', 'ams_fan_duty_can'}];

    e{end + 1} = struct('header', 'AMS Occurences');
    e = [e, {'ams_overvoltage_occu_b_can', 'ams_undervoltage_occu_b_can', ...
             'ams_overtemp_occu_b_can', 'ams_undertemp_occu_b_can', ...
             'ams_overcurrent_occu_b_can', 'ams_ivtTimeout_occu_b_can'}];

    e{end + 1} = struct('header', 'AIR & TS');
    e = [e, {'air_minus_closed_b_can', 'air_plus_closed_b_can', ...
             'precharge_closed_b_can', 'ts_active_b_can', 'ts_state_can', ...
             'ts_precharge_progress_can'}];

    e{end + 1} = struct('header', 'IMD & TSAL');
    e = [e, {'imd_ok_b_can', 'imd_state_can', 'imd_insulation_can', ...
             'tsal_state_can', 'tsal_hv_bat_b_can', 'tsal_error_b_can'}];

    for i = 1:numel(cfg.fahrzeug.raeder)
        w = cfg.fahrzeug.raeder{i};
        e{end + 1} = struct('header', upper(w));
        e{end + 1} = ['unitek_', w, '_speed_motor_ist_can'];
        e{end + 1} = ['unitek_', w, '_torque_motor_ist_can'];
        e{end + 1} = ['unitek_', w, '_torque_motor_soll_can'];
        e{end + 1} = ['unitek_', w, '_motor_temp_can'];
        e{end + 1} = ['unitek_', w, '_igbt_temp_can'];
        e{end + 1} = ['unitek_', w, '_Vdc_Bus_can'];
        e{end + 1} = ['unitek_', w, '_i_ist_can'];
        e{end + 1} = ['unitek_', w, '_rdy_b_can'];
        e{end + 1} = ['unitek_', w, '_run_b_can'];
        e{end + 1} = ['unitek_', w, '_motortemp_b_can'];
        e{end + 1} = ['unitek_', w, '_devicetemp_b_can'];
        e{end + 1} = ['unitek_', w, '_power_fault_b_can'];
    end

    e{end + 1} = struct('header', 'Torque & Derating');
    e = [e, {'drive_pwtrTqTarget_can', 'tq_vehicle_pos_limit_can', 'tq_vehicle_neg_limit_can', ...
             'drive_deratingMotorTemp_b_can', 'drive_deratingAccuTemp_b_can', ...
             'drive_deratingInverterTemp_b_can', 'drive_deratingAccuSoc_b_can', ...
             'drive_stratRecuActive_b_can', 'drive_powerLimitActive_b_can'}];

    e{end + 1} = struct('header', 'TQV Status');
    e = [e, {'tqv_status_tc_enabled_b_can', 'tqv_status_tqv_enabled_b_can', ...
             'tqv_status_gps_fix_aquired_b_can', 'tqv_status_tqv_strength_can', ...
             'tqv_status_tc_mu_factor_can', 'tqv_status_tc_slip_target_can'}];

    e{end + 1} = struct('header', 'TQV Ergebnisse');
    e = [e, {'tqv_result_fl_can', 'tqv_result_fr_can', 'tqv_result_rl_can', 'tqv_result_rr_can', ...
             'tqv_tqLimitPos_front_can', 'tqv_tqLimitNeg_front_can', ...
             'tqv_tqLimitPos_rear_can', 'tqv_tqLimitNeg_rear_can'}];

    e{end + 1} = struct('header', 'Slip');
    e = [e, {'slip_compare_val_fl_can', 'slip_compare_val_fr_can', ...
             'slip_compare_val_rl_can', 'slip_compare_val_rr_can'}];

    e{end + 1} = struct('header', 'PDU DCDC');
    dcdc_namen = {'12V_Gen', '24V_Gen', 'DV', 'Ewp_Mot_1', 'Fan_Inv', 'Fan_Motor'};
    for i = 1:numel(dcdc_namen)
        d = dcdc_namen{i};
        e{end + 1} = ['PDU_DCDC_', d, '_vout_can'];
        e{end + 1} = ['PDU_DCDC_', d, '_iout_can'];
        e{end + 1} = ['PDU_DCDC_', d, '_e_b_can'];
    end

    e{end + 1} = struct('header', 'Kuehlung');
    e = [e, {'ewpInverterDuty_can', 'ewpMotorDuty_can', 'fanInverterDuty_can', 'fanMotorDuty_can'}];

    e{end + 1} = struct('header', 'eFuse (Auswahl)');
    fuse_namen = {'ACE', 'AMS', 'DVSC', 'Inv_FL', 'Inv_FR', 'Inv_RL', 'Inv_RR', 'SDC'};
    for i = 1:numel(fuse_namen)
        f = fuse_namen{i};
        e{end + 1} = ['PDU_eFuse_', f, '_IMON_can'];
        e{end + 1} = ['PDU_eFuse_', f, '_e_b_can'];
    end

    e{end + 1} = struct('header', 'Safety & SDC');
    e = [e, {'SDC_AS_closed_b_can', 'SDC_Latch_Ready_b_can', 'sdc_res_b_can', ...
             'bspd_b_can', 'bots_b_can', 'bspd_avoid_b_can', 'ams_ok_b_can', 'imd_ok_b_can'}];

    e{end + 1} = struct('header', 'Driverless');
    e = [e, {'DL_EBS_state_can', 'DL_AS_state_can', 'DL_speed_actual_can', ...
             'DL_speed_target_can', 'DL_steering_angle_actual_can', ...
             'DL_Motor_moment_actual_can', 'DL_Lap_counter_can', ...
             'VCU_Statemachine_can', 'VCU_AMI_state_can', 'VCU_GO_b_can'}];

    e{end + 1} = struct('header', 'Abgeleitet');
    e{end + 1} = {'P_pack', 'P pack (W)', 'P_pack_ok'};
    e{end + 1} = {'P_mech_total', 'P mech total (W)', 'P_mech_total_ok'};
    e{end + 1} = {'P_mech_fl', 'P mech FL (W)', 'P_mech_fl_ok'};
    e{end + 1} = {'P_mech_fr', 'P mech FR (W)', 'P_mech_fr_ok'};
    e{end + 1} = {'P_mech_rl', 'P mech RL (W)', 'P_mech_rl_ok'};
    e{end + 1} = {'P_mech_rr', 'P mech RR (W)', 'P_mech_rr_ok'};
    e{end + 1} = {'eta_powertrain', 'η Powertrain (%)', 'eta_powertrain_ok'};
    e{end + 1} = {'E_total_kWh', 'E total (kWh)', 'E_total_ok'};
    e{end + 1} = {'E_regen_kWh', 'E regen (kWh)', 'E_regen_ok'};

    eintraege = e;
end