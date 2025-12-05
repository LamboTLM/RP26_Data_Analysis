function [f, all_axes, avg_P_wheel, avg_Eff] = visuelizeMotorpowerSingle(Data,fahrzeitBereich)
% try
    f = figure('Name', '7. Engine Cooling Analyse', 'NumberTitle', 'off');
    % Layout auf 3x1 
    t = tiledlayout(f, 3, 1); 
    title(t, 'Engine Cooling', 'FontSize', 14);

    %% Laden der nötigen Daten
    % (Das Laden der Daten bleibt unverändert)
    unitek_fl_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_fl_speed_motor_ist_can');
    unitek_fr_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_fr_speed_motor_ist_can');
    unitek_rl_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_rl_speed_motor_ist_can');
    unitek_rr_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_rr_speed_motor_ist_can');
    Engine_Speed = synchronize(unitek_fl_speed_motor_ist_can,unitek_fr_speed_motor_ist_can,unitek_rl_speed_motor_ist_can,unitek_rr_speed_motor_ist_can,"union","spline");
    
    unitek_fl_torque_motor_soll_can = extractTimetableFromCell(Data,'unitek_fl_torque_motor_soll_can');
    unitek_fr_torque_motor_soll_can = extractTimetableFromCell(Data,'unitek_fr_torque_motor_soll_can');
    unitek_rl_torque_motor_soll_can = extractTimetableFromCell(Data,'unitek_rl_torque_motor_soll_can');
    unitek_rr_torque_motor_soll_can = extractTimetableFromCell(Data,'unitek_rr_torque_motor_soll_can');
    Engine_Torque = synchronize(unitek_fl_torque_motor_soll_can,unitek_fr_torque_motor_soll_can,unitek_rl_torque_motor_soll_can,unitek_rr_torque_motor_soll_can,"union","spline");
    
    unitek_fl_motor_temp_can = extractTimetableFromCell(Data,'unitek_fl_motor_temp_can');
    unitek_fr_motor_temp_can = extractTimetableFromCell(Data,'unitek_fr_motor_temp_can');
    unitek_rl_motor_temp_can = extractTimetableFromCell(Data,'unitek_rl_motor_temp_can');
    unitek_rr_motor_temp_can = extractTimetableFromCell(Data,'unitek_rr_motor_temp_can');
    motor_temp_data = synchronize(unitek_fl_motor_temp_can,unitek_fr_motor_temp_can,unitek_rl_motor_temp_can,unitek_rr_motor_temp_can,"union","spline");

    P_Battery = extractTimetableFromCell(Data,'IVT_Result_W_can');

    All_Data = synchronize(Engine_Speed, Engine_Torque, P_Battery, motor_temp_data, "union", "spline");
    All_Data = All_Data(fahrzeitBereich,:);
    
    %% Berechnungen
    
    % 1. Mechanische Leistung pro Rad
    rpm_to_rads = 2 * pi / 60;
    All_Data.P_mech_FL = All_Data.unitek_fl_torque_motor_soll_can .* (All_Data.unitek_fl_speed_motor_ist_can * rpm_to_rads);
    All_Data.P_mech_FR = All_Data.unitek_fr_torque_motor_soll_can .* (All_Data.unitek_fr_speed_motor_ist_can * rpm_to_rads);
    All_Data.P_mech_RL = All_Data.unitek_rl_torque_motor_soll_can .* (All_Data.unitek_rl_speed_motor_ist_can * rpm_to_rads);
    All_Data.P_mech_RR = All_Data.unitek_rr_torque_motor_soll_can .* (All_Data.unitek_rr_speed_motor_ist_can * rpm_to_rads);

    % 2. Mechanische Gesamtleistung
    All_Data.P_mech_total = All_Data.P_mech_FL + All_Data.P_mech_FR + All_Data.P_mech_RL + All_Data.P_mech_RR;

    % 3. Durchschnittliche Radleistung (Betrag)
    avg_P_FL = mean(abs(All_Data.P_mech_FL), 'omitnan');
    avg_P_FR = mean(abs(All_Data.P_mech_FR), 'omitnan');
    avg_P_RL = mean(abs(All_Data.P_mech_RL), 'omitnan');
    avg_P_RR = mean(abs(All_Data.P_mech_RR), 'omitnan');
    avg_P_wheel = struct('FL', avg_P_FL, 'FR', avg_P_FR, 'RL', avg_P_RL, 'RR', avg_P_RR);

    % 4. Wirkungsgrade (Antrieb vs. Rekuperation) - ÜBERARBEITET
    
    % NEU: Schwelle definieren (z.B. 100W). Nur oberhalb/unterhalb wird Eta berechnet.
    % Passe diesen Wert ggf. an dein Rauschlevel an.
    power_threshold = 100; 
    
    % Antrieb (Nur wenn P_Batt UND P_Mech > Schwelle)
    idx_propulsion = (All_Data.IVT_Result_W_can > power_threshold) & (All_Data.P_mech_total > power_threshold);
    eta_propulsion_data = All_Data.P_mech_total(idx_propulsion) ./ All_Data.IVT_Result_W_can(idx_propulsion);
    eta_propulsion_data(eta_propulsion_data > 1) = 1; % Kappen bei 100%
    eta_propulsion_data(eta_propulsion_data < 0) = 0; % Kappen bei 0%
    avg_eta_propulsion = mean(eta_propulsion_data, 'omitnan');
    
    % Rekuperation (Nur wenn P_Batt UND P_Mech < -Schwelle)
    idx_recuperation = (All_Data.IVT_Result_W_can < -power_threshold) & (All_Data.P_mech_total < -power_threshold);
    eta_recuperation_data = All_Data.IVT_Result_W_can(idx_recuperation) ./ All_Data.P_mech_total(idx_recuperation);
    eta_recuperation_data(eta_recuperation_data > 1) = 1; % Kappen bei 100%
    eta_recuperation_data(eta_recuperation_data < 0) = 0; % Kappen bei 0%
    avg_eta_recuperation = mean(eta_recuperation_data, 'omitnan');
    
    avg_Eff = struct('Propulsion', avg_eta_propulsion, 'Recuperation', avg_eta_recuperation);

    % 5. Vektor für Momentan-Wirkungsgrad
    All_Data.Eta = nan(size(All_Data.t));
    All_Data.Eta(idx_propulsion) = eta_propulsion_data;
    All_Data.Eta(idx_recuperation) = eta_recuperation_data;


    %% Plot 1: Mechanische Radleistung (Betrag) - MIT AVG IN LEGENDE
    ax1 = nexttile(t);
    if ~(all(isnan(All_Data.P_mech_FL)) && all(isnan(All_Data.P_mech_FR)) && all(isnan(All_Data.P_mech_RL)) && all(isnan(All_Data.P_mech_RR)))
        
        % NEU: Dynamische Anzeigenamen für Legende
        fl_name = sprintf('FL (Avg: %.0f W)', avg_P_wheel.FL);
        fr_name = sprintf('FR (Avg: %.0f W)', avg_P_wheel.FR);
        rl_name = sprintf('RL (Avg: %.0f W)', avg_P_wheel.RL);
        rr_name = sprintf('RR (Avg: %.0f W)', avg_P_wheel.RR);
        
        plot(ax1, All_Data.t, abs(All_Data.P_mech_FL), 'DisplayName', fl_name);
        hold(ax1, 'on');
        plot(ax1, All_Data.t, abs(All_Data.P_mech_FR), 'DisplayName', fr_name);
        plot(ax1, All_Data.t, abs(All_Data.P_mech_RL), 'DisplayName', rl_name);
        plot(ax1, All_Data.t, abs(All_Data.P_mech_RR), 'DisplayName', rr_name);
        hold(ax1, 'off');
    else
        plotDataMissingBox(ax1)
    end
    title(ax1, 'Mechanische Radleistung (Betrag)');
    xlabel(ax1, 'Zeit [s]');
    ylabel(ax1, '|P_mech| [W]');
    grid(ax1, 'on');
    legend(ax1, 'show', 'ItemHitFcn',@cb_legend);

    %% Plot 2: Leistungsvergleich Batterie vs. Motoren (Summe)
    ax2 = nexttile(t);
    if ~(all(isnan(All_Data.P_mech_total)) && all(isnan(All_Data.IVT_Result_W_can)))
        plot(ax2, All_Data.t, All_Data.IVT_Result_W_can, 'DisplayName', 'P_Batt (IVT)');
        hold(ax2, 'on');
        plot(ax2, All_Data.t, All_Data.P_mech_total, 'DisplayName', 'P_Mech_Total (Summe)');
        hold(ax2, 'off');
    else
        plotDataMissingBox(ax2)
    end
    title(ax2, 'Leistungsvergleich: Batterie vs. Motoren (Summe)');
    xlabel(ax2, 'Zeit [s]');
    ylabel(ax2, 'Leistung [W]');
    grid(ax2, 'on');
    legend(ax2, 'show', 'ItemHitFcn',@cb_legend);

    %% Plot 3: Wirkungsgrad (Momentan + Mean im Titel)
    ax3 = nexttile(t);
    
    plot(ax3, All_Data.t, All_Data.Eta, '.', 'MarkerSize', 2, 'DisplayName', '\eta Momentan');
    
    title_str = sprintf('Momentan-Wirkungsgrad | Mean Antrieb: %.2f%% | Mean Reku: %.2f%%', ...
                        avg_Eff.Propulsion * 100, ...
                        avg_Eff.Recuperation * 100);
    title(ax3, title_str);
    
    xlabel(ax3, 'Zeit [s]');
    ylabel(ax3, 'Wirkungsgrad \eta [-]');
    
    ylim(ax3, [0 1.1]); 
    grid(ax3, 'on');
    legend(ax3, 'show', 'ItemHitFcn',@cb_legend);

    %% Achsen koppeln
    all_axes = [ax1; ax2; ax3]; 
    linkaxes(all_axes,'x');
% catch
%     f=[]; all_axes=[]; avg_P_wheel=[]; avg_Eff=[];
% end
end