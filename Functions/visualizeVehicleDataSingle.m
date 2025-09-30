function [f, all_axes] = visualizeVehicleDataSingle(Data,fahrzeitBereich)
try
    f = figure('Name', '2. Fahrzeugdaten Analyse', 'NumberTitle', 'off');
    t = tiledlayout(f, 3, 1);
    title(t, 'Fahrzeug- & Radmetriken', 'FontSize', 14);

    % Motordrehzahlen
    unitek_fl_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_fl_speed_motor_ist_can');
    unitek_fr_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_fr_speed_motor_ist_can');
    unitek_rl_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_rl_speed_motor_ist_can');
    unitek_rr_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_rr_speed_motor_ist_can');

    VehicleData=synchronize(unitek_fl_speed_motor_ist_can, unitek_fr_speed_motor_ist_can, unitek_rl_speed_motor_ist_can, unitek_rr_speed_motor_ist_can,"union","spline");
    VehicleData=VehicleData(fahrzeitBereich,:);

    % Plot 1: Rad-RPM (alle vier Räder)
    ax1 = nexttile(t);
    if ~(all(isnan(VehicleData.unitek_fl_speed_motor_ist_can)) && all(isnan(VehicleData.unitek_fr_speed_motor_ist_can)) && all(isnan(VehicleData.unitek_rl_speed_motor_ist_can)) && all(isnan(VehicleData.unitek_rr_speed_motor_ist_can)))
        hold(ax1, 'on');
        plot(ax1, VehicleData.t, VehicleData.unitek_fl_speed_motor_ist_can, 'DisplayName', 'FL');
        plot(ax1, VehicleData.t, VehicleData.unitek_fr_speed_motor_ist_can, 'DisplayName', 'FR');
        plot(ax1, VehicleData.t, VehicleData.unitek_rl_speed_motor_ist_can, 'DisplayName', 'RL');
        plot(ax1, VehicleData.t, VehicleData.unitek_rr_speed_motor_ist_can, 'DisplayName', 'RR');
        hold(ax1, 'off');
    else
        plotDataMissingBox(ax1)
    end
    title(ax1, 'Rad-RPM');
    xlabel(ax1, 'Zeit [s]');
    ylabel(ax1, 'RPM');
    grid(ax1, 'on');
    hold(ax1, 'on');
    hold(ax1, 'off');
    legend(ax1, 'FL', 'FR', 'RL', 'RR' ,'ItemHitFcn',@cb_legend)


    % Plot 2: Fahrzeuggeschwindigkeit
    wheelRPMs = VehicleData{:, {'unitek_fl_speed_motor_ist_can', 'unitek_fr_speed_motor_ist_can', 'unitek_rl_speed_motor_ist_can', 'unitek_rr_speed_motor_ist_can'}};
    Tyre_speed=Speed_calculator(mean(abs(wheelRPMs), 2),'RP24e');
    Tyre_speed=timetable(VehicleData.t, Tyre_speed);
    
    ax2 = nexttile(t);
    if ~all(isnan(Tyre_speed.Var1))
        plot(ax2, Tyre_speed.Time, Tyre_speed.Var1, 'DisplayName', 'Geschw.');
    else
        plotDataMissingBox(ax1)
    end
    title(ax2, 'Fahrzeuggeschwindigkeit über reifen');
    xlabel(ax2, 'Zeit [s]');
    ylabel(ax2, 'Geschwindigkeit');
    grid(ax2, 'on');
    hold(ax2, 'on');
    hold(ax2, 'off');


    % Plot 3: Motortoruqe soll
    ax3 = nexttile(t);
    title(ax3, 'Rad-RPM');
    xlabel(ax3, 'Zeit [s]');
    ylabel(ax3, 'RPM');
    grid(ax3, 'on');
    if ~all(isnan(VehicleData.unitek_fl_speed_motor_ist_can)) && ~all(isnan(VehicleData.unitek_fr_speed_motor_ist_can)) && ~all(isnan(VehicleData.unitek_rl_speed_motor_ist_can)) && ~all(isnan(VehicleData.unitek_rr_speed_motor_ist_can))
        hold(ax3, 'on');
        plot(ax3, VehicleData.t, VehicleData.unitek_fl_speed_motor_ist_can, 'DisplayName', 'FL');
        plot(ax3, VehicleData.t, VehicleData.unitek_fr_speed_motor_ist_can, 'DisplayName', 'FR');
        plot(ax3, VehicleData.t, VehicleData.unitek_rl_speed_motor_ist_can, 'DisplayName', 'RL');
        plot(ax3, VehicleData.t, VehicleData.unitek_rr_speed_motor_ist_can, 'DisplayName', 'RR');
        hold(ax3, 'off');
    else
        plotDataMissingBox(ax3)
    end

    title(ax3, 'Rad-RPM');
    xlabel(ax3, 'Zeit [s]');
    ylabel(ax3, 'RPM');
    grid(ax3, 'on');
    legend(ax3, 'FL','FR','RL','RR','ItemHitFcn',@cb_legend)

    all_axes = [ax1, ax2];
    linkaxes (all_axes, 'x');
catch
    f=[];
    all_axes=[];
end
end