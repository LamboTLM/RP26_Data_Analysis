function [f, all_axes, f2] = visualizeTQVDataSingle(Data, fahrzeitBereich)
try
    f = figure('Name', '6. Torque Vectoring Analyse', 'NumberTitle', 'off');
    t = tiledlayout(f, 4, 1);
    title(t, 'Torque Vectoring Daten', 'FontSize', 14);

    %% Laden der nötigen Daten
    tqv_fl = extractTimetableFromCell(Data,'tqv_result_fl_can');
    tqv_fr = extractTimetableFromCell(Data,'tqv_result_fr_can');
    tqv_rl = extractTimetableFromCell(Data,'tqv_result_rl_can');
    tqv_rr = extractTimetableFromCell(Data,'tqv_result_rr_can');

    spd_fl = extractTimetableFromCell(Data,'tqv_rot_spd_fl_can');
    spd_fr = extractTimetableFromCell(Data,'tqv_rot_spd_fr_can');
    spd_rl = extractTimetableFromCell(Data,'tqv_rot_spd_rl_can');
    spd_rr = extractTimetableFromCell(Data,'tqv_rot_spd_rr_can');

    steer = extractTimetableFromCell(Data,'steering_wheel_angle_can');
    tqv_steer = extractTimetableFromCell(Data,'tqv_tire_steerangle_can');

    tqv_lim_pos_f = extractTimetableFromCell(Data,'tqv_tqLimitPos_front_can');
    tqv_lim_neg_f = extractTimetableFromCell(Data,'tqv_tqLimitNeg_front_can');
    tqv_lim_pos_r = extractTimetableFromCell(Data,'tqv_tqLimitPos_rear_can');
    tqv_lim_neg_r = extractTimetableFromCell(Data,'tqv_tqLimitNeg_rear_can');

    speed = extractTimetableFromCell(Data,'speed_can');

    acc_x = extractTimetableFromCell(Data,'INS_acc_x_can');
    acc_y = extractTimetableFromCell(Data,'INS_acc_y_can');

    % Synchronisieren
    TQV_data = synchronize(tqv_fl,tqv_fr,tqv_rl,tqv_rr, ...
                           spd_fl,spd_fr,spd_rl,spd_rr, ...
                           steer,tqv_steer, ...
                           tqv_lim_pos_f,tqv_lim_neg_f,tqv_lim_pos_r,tqv_lim_neg_r, ...
                           speed, acc_x, acc_y, ...
                           "union","spline");

    TQV_data = TQV_data(fahrzeitBereich,:);

    %% Plot 1: Drehmomente an den vier Rädern
    ax1 = nexttile(t);
    plot(ax1, TQV_data.t, TQV_data.tqv_result_fl_can, 'DisplayName','FL');
    hold on
    plot(ax1, TQV_data.t, TQV_data.tqv_result_fr_can, 'DisplayName','FR');
    plot(ax1, TQV_data.t, TQV_data.tqv_result_rl_can, 'DisplayName','RL');
    plot(ax1, TQV_data.t, TQV_data.tqv_result_rr_can, 'DisplayName','RR');
    hold off
    title(ax1, 'Radmomente');
    ylabel(ax1, 'Torque [Nm]');
    grid(ax1,'on');
    legend(ax1,'show');

    %% Plot 2: Raddrehzahlen
    ax2 = nexttile(t);
    plot(ax2, TQV_data.t, TQV_data.tqv_rot_spd_fl_can, 'DisplayName','FL');
    hold on
    plot(ax2, TQV_data.t, TQV_data.tqv_rot_spd_fr_can, 'DisplayName','FR');
    plot(ax2, TQV_data.t, TQV_data.tqv_rot_spd_rl_can, 'DisplayName','RL');
    plot(ax2, TQV_data.t, TQV_data.tqv_rot_spd_rr_can, 'DisplayName','RR');
    hold off
    title(ax2, 'Raddrehzahlen');
    ylabel(ax2, 'n [rpm]');
    grid(ax2,'on');
    legend(ax2,'show');

    %% Plot 3: Lenkwinkel und TQV-Sollwinkel
    ax3 = nexttile(t);
    plot(ax3, TQV_data.t, TQV_data.steering_wheel_angle_can, 'DisplayName','SW Winkel');
    hold on
    plot(ax3, TQV_data.t, TQV_data.tqv_tire_steerangle_can, 'DisplayName','Tire Angle');
    hold off
    title(ax3, 'Lenkwinkel');
    ylabel(ax3, 'Winkel [°]');
    grid(ax3,'on');
    legend(ax3,'show');

    %% Plot 4: Limits & Status
    ax4 = nexttile(t);
    plot(ax4, TQV_data.t, TQV_data.tqv_tqLimitPos_front_can, 'DisplayName','+Limit Front');
    hold on
    plot(ax4, TQV_data.t, TQV_data.tqv_tqLimitNeg_front_can, 'DisplayName','-Limit Front');
    plot(ax4, TQV_data.t, TQV_data.tqv_tqLimitPos_rear_can, 'DisplayName','+Limit Rear');
    plot(ax4, TQV_data.t, TQV_data.tqv_tqLimitNeg_rear_can, 'DisplayName','-Limit Rear');
    yyaxis right
    % plot(ax4, TQV_data.t, TQV_data.tqv_status_tqv_enabled_b_can*100, 'k--', 'DisplayName','TQV enabled');
    % plot(ax4, TQV_data.t, TQV_data.tqv_status_tc_enabled_b_can*100, 'm--', 'DisplayName','TC enabled');
    ylabel(ax4, 'Status [%]');
    hold off
    title(ax4, 'Torque Limits & Status');
    ylabel(ax4, 'Torque [Nm]');
    grid(ax4,'on');
    legend(ax4,'show');

    %% Achsen koppeln
    all_axes = [ax1,ax2,ax3,ax4];
    linkaxes(all_axes,'x');
catch
    f=[]; all_axes=[]; f2=[];
end
end
