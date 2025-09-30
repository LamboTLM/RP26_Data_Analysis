function [f, all_axes] = visualizeTemperatureDataSingle(Data,fahrzeitBereich)
% try
f = figure('Name', '5. Temperatur Analyse', 'NumberTitle', 'off');
t = tiledlayout(f, 4, 1);
title(t, 'Bremstemperaturen', 'FontSize', 14);

% Motortemps
unitek_fl_motor_temp_can = extractTimetableFromCell(Data,'unitek_fl_motor_temp_can');
unitek_fr_motor_temp_can = extractTimetableFromCell(Data,'unitek_fr_motor_temp_can');
unitek_rl_motor_temp_can = extractTimetableFromCell(Data,'unitek_rl_motor_temp_can');
unitek_rr_motor_temp_can = extractTimetableFromCell(Data,'unitek_rr_motor_temp_can');

motor_temp_data=synchronize(unitek_fl_motor_temp_can,unitek_fr_motor_temp_can,unitek_rl_motor_temp_can,unitek_rr_motor_temp_can,"union","spline");

% Invertertemps
unitek_fl_igbt_temp_can  = extractTimetableFromCell(Data,'unitek_fl_igbt_temp_can');
unitek_fr_igbt_temp_can  = extractTimetableFromCell(Data,'unitek_fr_igbt_temp_can');
unitek_rl_igbt_temp_can  = extractTimetableFromCell(Data,'unitek_rl_igbt_temp_can');
unitek_rr_igbt_temp_can  = extractTimetableFromCell(Data,'unitek_rr_igbt_temp_can');

inverter_temp_data=synchronize(unitek_fl_igbt_temp_can,unitek_fr_igbt_temp_can,unitek_rl_igbt_temp_can,unitek_rr_igbt_temp_can,"union","spline");

% Bremstemperaturen
wpmd_brake_temp_fl_can = extractTimetableFromCell(Data,'wpmd_brake_temp_fl_can');
wpmd_brake_temp_fr_can = extractTimetableFromCell(Data,'wpmd_brake_temp_fr_can');
wpmd_brake_temp_rl_can = extractTimetableFromCell(Data,'wpmd_brake_temp_rl_can');
wpmd_brake_temp_rr_can = extractTimetableFromCell(Data,'wpmd_brake_temp_rr_can');

%brake_temp_data=synchronize(wpmd_brake_temp_fl_can, wpmd_brake_temp_fr_can,'union','next');
brake_temp_data=synchronize(wpmd_brake_temp_fl_can,wpmd_brake_temp_fr_can,wpmd_brake_temp_rl_can,wpmd_brake_temp_rr_can,"union","spline");

% Zellemperaturen
ams_cell_avg_temp_can = extractTimetableFromCell(Data,'ams_cell_avg_temp_can');
ams_cell_max_temp_can = extractTimetableFromCell(Data,'ams_cell_max_temp_can');
ams_cell_min_temp_can = extractTimetableFromCell(Data,'ams_cell_min_temp_can');

Cell_temp_data=synchronize(ams_cell_avg_temp_can,ams_cell_max_temp_can,ams_cell_min_temp_can,"union","spline");

TemperatureData=synchronize(motor_temp_data,inverter_temp_data,Cell_temp_data,brake_temp_data,"union","spline");

TemperatureData=TemperatureData(fahrzeitBereich,:);

% Plot 1: Motortemperaturen über Zeit
ax1 = nexttile(t);
hold(ax1, 'on');
if ~all(isnan(TemperatureData.unitek_fl_motor_temp_can)) && ~all(isnan(TemperatureData.unitek_fr_motor_temp_can)) && ~all(isnan(TemperatureData.unitek_rl_motor_temp_can)) && ~all(isnan(TemperatureData.unitek_rr_motor_temp_can))
    plot(ax1, TemperatureData.t, TemperatureData.unitek_fl_motor_temp_can, 'DisplayName', 'FL');
    plot(ax1, TemperatureData.t, TemperatureData.unitek_fr_motor_temp_can, 'DisplayName', 'FR');
    plot(ax1, TemperatureData.t, TemperatureData.unitek_rl_motor_temp_can, 'DisplayName', 'RL');
    plot(ax1, TemperatureData.t, TemperatureData.unitek_rr_motor_temp_can, 'DisplayName', 'RR');
else
    plotDataMissingBox(ax1);
end
hold(ax1, 'off');
title(ax1, 'Motortemperaturen');
xlabel(ax1, 'Zeit [s]');
ylabel(ax1, 'Temperatur [°C]');
grid(ax1, 'on');
legend ('FL', 'FR', 'RL', 'RR','ItemHitFcn',@cb_legend);

% Plot 2: Invertertemperatur über Zeit
ax2 = nexttile(t);
if ~all(isnan(TemperatureData.unitek_fl_igbt_temp_can)) && ~all(isnan(TemperatureData.unitek_fr_igbt_temp_can)) && ~all(isnan(TemperatureData.unitek_rl_igbt_temp_can)) && ~all(isnan(TemperatureData.unitek_rr_igbt_temp_can))
    hold(ax2, 'on');
    plot(ax2, TemperatureData.t, TemperatureData.unitek_fl_igbt_temp_can, 'DisplayName', 'FL');
    plot(ax2, TemperatureData.t, TemperatureData.unitek_fr_igbt_temp_can, 'DisplayName', 'FR');
    plot(ax2, TemperatureData.t, TemperatureData.unitek_rl_igbt_temp_can, 'DisplayName', 'RL');
    plot(ax2, TemperatureData.t, TemperatureData.unitek_rr_igbt_temp_can, 'DisplayName', 'RR');
    hold(ax2, 'off');
else
    plotDataMissingBox(ax2);
end
title(ax2, 'Inverter temp');
xlabel(ax2, 'Zeit [s]');
ylabel(ax2, 'Temperatur [°C]');
grid(ax2, 'on');
legend ('FL', 'FR', 'RL', 'RR','ItemHitFcn',@cb_legend);
ylim(ax2, [0,150]);

% Plot 3: Bremstemperaturen über Zeit
ax3 = nexttile(t);
if ~(all(isnan(TemperatureData.unitek_fl_igbt_temp_can)) && all(isnan(TemperatureData.unitek_fr_igbt_temp_can)) && all(isnan(TemperatureData.unitek_rl_igbt_temp_can)) && all(isnan(TemperatureData.unitek_rr_igbt_temp_can)))
    hold(ax3, 'on');
    plot(ax3, TemperatureData.t, TemperatureData.wpmd_brake_temp_fl_can, 'DisplayName', 'FL');
    plot(ax3, TemperatureData.t, TemperatureData.wpmd_brake_temp_fr_can, 'DisplayName', 'FR');
    plot(ax3, TemperatureData.t, TemperatureData.wpmd_brake_temp_rl_can, 'DisplayName', 'RL');
    plot(ax3, TemperatureData.t, TemperatureData.wpmd_brake_temp_rr_can, 'DisplayName', 'RR');
    hold(ax3, 'off');
else
    plotDataMissingBox(ax3);
end

title(ax3, 'Bremstemperaturen');
xlabel(ax3, 'Zeit [s]');
ylabel(ax3, 'Temperatur [°C]');
grid(ax3, 'on');
legend ('FL', 'FR', 'RL', 'RR','ItemHitFcn',@cb_legend);
ylim(ax3, [0,400]);

% Plot 4: Akkutemperaturen über Zeit
ax4 = nexttile(t);
if ~(all(isnan(TemperatureData.unitek_fl_igbt_temp_can)) && all(isnan(TemperatureData.unitek_fr_igbt_temp_can)) && all(isnan(TemperatureData.unitek_rl_igbt_temp_can)) && all(isnan(TemperatureData.unitek_rr_igbt_temp_can)))
    hold(ax4, 'on');
    plot(ax4, TemperatureData.t, TemperatureData.ams_cell_avg_temp_can, 'DisplayName', 'avg');
    plot(ax4, TemperatureData.t, TemperatureData.ams_cell_max_temp_can, 'DisplayName', 'max');
    plot(ax4, TemperatureData.t, TemperatureData.ams_cell_min_temp_can, 'DisplayName', 'min');
    hold(ax4, 'off');
else
    plotDataMissingBox(ax4);
end
title(ax4, 'Akuzellen Temp');
xlabel(ax4, 'Zeit [s]');
ylabel(ax4, 'Temperatur [°C]');
grid(ax4, 'on');
hold(ax4, 'on');
hold(ax4, 'off')
legend ('avg', 'max', 'min','ItemHitFcn',@cb_legend);
ylim(ax4, [0,70]);

try
    all_axes = [ax1,ax2,ax3,ax4];
catch
    all_axes = [ax1,ax2,ax4];
end
linkaxes (all_axes, 'x');

% catch
%     f=[];
%     all_axes=[];
% end
end