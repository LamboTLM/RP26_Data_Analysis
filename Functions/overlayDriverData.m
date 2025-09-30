function overlayDriverData(Data, fahrzeitBereich, Driverdata_axes, FahrerName)
    % gleiche Daten extrahieren wie in visualizeDriverData
    apps_res_can = extractTimetableFromCell(Data,'apps_res_can');
    apps1_can = extractTimetableFromCell(Data,'apps1_can');
    apps2_can = extractTimetableFromCell(Data,'apps2_can');
    apps3_can = extractTimetableFromCell(Data,'apps3_can');
    pbrake_front_can = extractTimetableFromCell(Data,'pbrake_front_can');
    pbrake_rear_can = extractTimetableFromCell(Data,'pbrake_rear_can');
    steering_wheel_angle_can = extractTimetableFromCell(Data,'steering_wheel_angle_can');

    Driver_data = synchronize(apps_res_can,apps1_can,apps2_can,apps3_can,...
        pbrake_front_can,steering_wheel_angle_can,pbrake_rear_can,"union","spline");
    Driver_data = Driver_data(fahrzeitBereich,:);

    % --- Plot 1 (Throttle) ---
    ax1 = Driverdata_axes(1);
    hold(ax1, 'on')
    plot(ax1, Driver_data.t, Driver_data.apps_res_can, ...
        'DisplayName', [FahrerName ' apps_res']);
    plot(ax1, Driver_data.t, Driver_data.apps1_can, ...
        'DisplayName', [FahrerName ' apps1']);
    plot(ax1, Driver_data.t, Driver_data.apps2_can, ...
        'DisplayName', [FahrerName ' apps2']);
    plot(ax1, Driver_data.t, Driver_data.apps3_can, ...
        'DisplayName', [FahrerName ' apps3']);
    hold(ax1, 'off')
    legend(ax1, 'show', 'ItemHitFcn',@cb_legend);

    % --- Plot 2 (Brake) ---
    ax2 = Driverdata_axes(2);
    hold(ax2, 'on')
    plot(ax2, Driver_data.t, Driver_data.pbrake_front_can, ...
        'DisplayName', [FahrerName ' Brake Front']);
    plot(ax2, Driver_data.t, Driver_data.pbrake_rear_can, ...
        'DisplayName', [FahrerName ' Brake Rear']);

    % Brake Balance berechnen
    mask = (Driver_data.pbrake_front_can > 5) & (Driver_data.pbrake_rear_can > 5);
    if any(mask)
        bal_press = Driver_data.pbrake_front_can(mask) ./ ...
            (Driver_data.pbrake_front_can(mask) + Driver_data.pbrake_rear_can(mask));
        bal_press_mean = mean(bal_press) * 100;

        front_eff = Driver_data.pbrake_front_can(mask) * 2;
        rear_eff  = Driver_data.pbrake_rear_can(mask) * 1;
        bal_real  = front_eff ./ (front_eff + rear_eff);
        bal_real_mean = mean(bal_real) * 100;

        % Dummy-Linien nur für Legende
        plot(ax2, Driver_data.t, nan(size(Driver_data.t)), ...
            'DisplayName', sprintf('%s Bal P: %.1f%%', FahrerName, bal_press_mean));
        plot(ax2, Driver_data.t, nan(size(Driver_data.t)), ...
            'DisplayName', sprintf('%s Bal Eff: %.1f%%', FahrerName, bal_real_mean));
    end
    hold(ax2, 'off');
    legend(ax2, 'show', 'ItemHitFcn',@cb_legend);

    % --- Plot 3 (Steering) ---
    ax3 = Driverdata_axes(3);
    hold(ax3, 'on')
    plot(ax3, Driver_data.t, Driver_data.steering_wheel_angle_can, ...
        'DisplayName', [FahrerName ' Lenkwinkel']);
    hold(ax3, 'off')
    legend(ax3, 'show', 'ItemHitFcn',@cb_legend);
end
