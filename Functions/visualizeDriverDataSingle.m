function [f, all_axes] = visualizeDriverDataSingle(Data,fahrzeitBereich)
try
f = figure('Name', '1. Fahrerdaten Analyse', 'NumberTitle', 'off');
t = tiledlayout(f, 3, 1); title(t, 'Fahrereingaben', 'FontSize', 14);
%% Laden der notigen daten

apps_res_can = extractTimetableFromCell(Data,'apps_res_can');
apps1_can = extractTimetableFromCell(Data,'apps1_can');
apps2_can = extractTimetableFromCell(Data,'apps2_can');
apps3_can = extractTimetableFromCell(Data,'apps3_can');

pbrake_front_can = extractTimetableFromCell(Data,'pbrake_front_can');
pbrake_rear_can = extractTimetableFromCell(Data,'pbrake_rear_can');

steering_wheel_angle_can = extractTimetableFromCell(Data,'steering_wheel_angle_can');

Driver_data=synchronize(apps_res_can,apps1_can,apps2_can,apps3_can,pbrake_front_can,steering_wheel_angle_can,pbrake_rear_can,"union","spline");
Driver_data=Driver_data(fahrzeitBereich,:);

% Plot 1: Gaspedalstellung über zeit
ax1 = nexttile(t);
if ~( all(isnan(Driver_data.apps_res_can)) && all(isnan(Driver_data.apps1_canb)) && all(isnan(Driver_data.apps2_canb)) && all(isnan(Driver_data.apps3_canb)) )
    hold(ax1, 'on')
    plot(ax1, Driver_data.t, Driver_data.apps_res_can, 'DisplayName', 'apps_res_can');
    plot(ax1, Driver_data.t, Driver_data.apps1_can, 'DisplayName', 'apps1_can');
    plot(ax1, Driver_data.t, Driver_data.apps2_can, 'DisplayName', 'apps2_can');
    plot(ax1, Driver_data.t, Driver_data.apps3_can, 'DisplayName', 'apps3_can');
    hold(ax1, 'off')
else
    plotDataMissingBox(ax1);
end
title(ax1, 'Gaspedalstellung');
xlabel(ax1, 'Zeit [s]');
ylabel(ax1, 'Throttel Sensor');
hold(ax1, 'on'); hold(ax1, 'off');
grid(ax1, 'on');
legend ('apps_res_can','apps1_can','apps2_can','apps3_can','ItemHitFcn',@cb_legend)

% Plot 2: Bremspedalkraft über Zeit
ax2 = nexttile(t);
if ~(all(isnan(Driver_data.pbrake_front_can)) && all(isnan(Driver_data.pbrake_rear_can)))
    hold(ax2, 'on');
    plot(ax2, Driver_data.t, Driver_data.pbrake_front_can, 'DisplayName', 'Brake Front');
    plot(ax2, Driver_data.t, Driver_data.pbrake_rear_can, 'DisplayName', 'Brake Rear');
    grid(ax2, 'on');

    mask = (Driver_data.pbrake_front_can > 5) & (Driver_data.pbrake_rear_can > 5);
    legend_entries = {'Brake Front','Brake Rear'};
    if any(mask)
        bal_press = Driver_data.pbrake_front_can(mask)./(Driver_data.pbrake_front_can(mask) + Driver_data.pbrake_rear_can(mask));
        bal_press_mean = mean(bal_press) * 100;
        front_eff = Driver_data.pbrake_front_can(mask) * 2;
        rear_eff = Driver_data.pbrake_rear_can(mask) * 1;
        bal_real = front_eff ./ (front_eff + rear_eff);
        bal_real_mean = mean(bal_real) * 100; hold(ax2, 'on');
        plot(ax2, Driver_data.t,zeros(numel(Driver_data.t),1));
        plot(ax2, Driver_data.t,zeros(numel(Driver_data.t),1));
        hold(ax2, 'off');
        legend_entries{end+1} = sprintf('Bal P: %.1f%%', bal_press_mean);
        legend_entries{end+1} = sprintf('Bal Eff: %.1f%%', bal_real_mean);
    end
else
    plotDataMissingBox(ax2);
end

title(ax2, 'Bremsdruck');
legend (ax2, 'Brake Front', 'Brake Rear',legend_entries,'ItemHitFcn',@cb_legend)
xlabel(ax2, 'Zeit [s]');
ylabel(ax2, 'Bar');
grid(ax2, 'on');
ylim(ax2, [0,100])

% Plot 3: Lenkwinkel über Zeit
ax3 = nexttile(t);
if ~all(isnan(Driver_data.steering_wheel_angle_can))
    plot(ax3, Driver_data.t, Driver_data.steering_wheel_angle_can, 'DisplayName', 'Lenkwinkel');
    plot(ax3, Driver_data.t, Driver_data.steering_wheel_angle_can, 'DisplayName', 'Lenkwinkel');
else
    plotDataMissingBox(ax3);
end

title(ax3, 'Lenkwinkel');
xlabel(ax3, 'Zeit [s]');
ylabel(ax3, 'Winkel [°]');
grid(ax3, 'on');


all_axes = [ax1, ax2, ax3];
linkaxes (all_axes, 'x');

catch
    f=[]; all_axes=[];
end
end