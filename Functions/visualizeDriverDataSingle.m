function [f, all_axes, play_data] = visualizeDriverDataSingle(Data, fahrzeitBereich)
    f = []; 
    all_axes = []; 
    play_data = struct(); 

    try
        f = figure('Name', '1. Fahrerdaten Analyse', 'NumberTitle', 'off');
        t = tiledlayout(f, 3, 1); 
        title(t, 'Fahrereingaben', 'FontSize', 14);

        %% Laden und Vorbereiten der Daten (Unverändert)
        apps_res_can = extractTimetableFromCell(Data,'apps_res_can');
        apps1_can = extractTimetableFromCell(Data,'apps1_can');
        apps2_can = extractTimetableFromCell(Data,'apps2_can');
        apps3_can = extractTimetableFromCell(Data,'apps3_can');
        pbrake_front_can = extractTimetableFromCell(Data,'pbrake_front_can');
        pbrake_rear_can = extractTimetableFromCell(Data,'pbrake_rear_can');
        steering_wheel_angle_can = extractTimetableFromCell(Data,'steering_wheel_angle_can');
        
        Driver_data = synchronize(apps_res_can, apps1_can, apps2_can, apps3_can, ...
                                  pbrake_front_can, steering_wheel_angle_can, pbrake_rear_can, ...
                                  "union", "spline");
        Driver_data = Driver_data(fahrzeitBereich,:);
        T_data = seconds(Driver_data.t - Driver_data.t(1)); 

        % --- Plotting (T_data als X-Achse) ---
        ax1 = nexttile(t);
        data_available_apps = ~( all(isnan(Driver_data.apps_res_can)) && all(isnan(Driver_data.apps1_can)) && all(isnan(Driver_data.apps2_can)) && all(isnan(Driver_data.apps3_can)) );
        if data_available_apps
            hold(ax1, 'on')
            plot(ax1, T_data, Driver_data.apps_res_can, 'DisplayName', 'apps\_res\_can');
            plot(ax1, T_data, Driver_data.apps1_can, 'DisplayName', 'apps1\_can');
            plot(ax1, T_data, Driver_data.apps2_can, 'DisplayName', 'apps2\_can');
            plot(ax1, T_data, Driver_data.apps3_can, 'DisplayName', 'apps3\_can');
            hold(ax1, 'off')
        else
            % plotDataMissingBox(ax1);
        end
        title(ax1, 'Gaspedalstellung');
        xlabel(ax1, 'Zeit [s]');
        ylabel(ax1, 'Throttle Sensor');
        grid(ax1, 'on');
        legend (ax1,'apps\_res\_can','apps1\_can','apps2\_can','apps3\_can','ItemHitFcn',@cb_legend)
        ax1.Tag = 'AppsPlot';
        
        ax2 = nexttile(t);
        data_available_brake = ~(all(isnan(Driver_data.pbrake_front_can)) && all(isnan(Driver_data.pbrake_rear_can)));
        legend_entries = {};
        if data_available_brake
            hold(ax2, 'on');
            plot(ax2, T_data, Driver_data.pbrake_front_can, 'DisplayName', 'Brake Front');
            plot(ax2, T_data, Driver_data.pbrake_rear_can, 'DisplayName', 'Brake Rear');
            grid(ax2, 'on');
            
            mask = (Driver_data.pbrake_front_can > 5) & (Driver_data.pbrake_rear_can > 5);
            
            if any(mask)
                bal_press = Driver_data.pbrake_front_can(mask)./(Driver_data.pbrake_front_can(mask) + Driver_data.pbrake_rear_can(mask));
                bal_press_mean = mean(bal_press) * 100;
                front_eff = Driver_data.pbrake_front_can(mask) * 2;
                rear_eff = Driver_data.pbrake_rear_can(mask) * 1;
                bal_real = front_eff ./ (front_eff + rear_eff);
                bal_real_mean = mean(bal_real) * 100; 
                
                plot(ax2, T_data, zeros(numel(T_data),1), 'HandleVisibility', 'off'); 
                plot(ax2, T_data, zeros(numel(T_data),1), 'HandleVisibility', 'off');
                
                legend_entries{end+1} = sprintf('Bal P: %.1f%%', bal_press_mean);
                legend_entries{end+1} = sprintf('Bal Eff: %.1f%%', bal_real_mean);
            end
            hold(ax2, 'off');
        else
            % plotDataMissingBox(ax2);
        end
        
        title(ax2, 'Bremsdruck');
        legend_all = [{'Brake Front', 'Brake Rear'}, legend_entries];
        legend (ax2, legend_all, 'ItemHitFcn', @cb_legend);
        xlabel(ax2, 'Zeit [s]');
        ylabel(ax2, 'Bar');
        grid(ax2, 'on');
        ylim(ax2, [0,100]);
        ax2.Tag = 'BrakePlot';

        ax3 = nexttile(t);
        if ~all(isnan(Driver_data.steering_wheel_angle_can))
            plot(ax3, T_data, Driver_data.steering_wheel_angle_can, 'DisplayName', 'Lenkwinkel');
        else
            % plotDataMissingBox(ax3);
        end
        title(ax3, 'Lenkwinkel');
        xlabel(ax3, 'Zeit [s]');
        ylabel(ax3, 'Winkel [°]');
        grid(ax3, 'on');
        ax3.Tag = 'SteeringPlot';

        all_axes = [ax1, ax2, ax3];
        linkaxes (all_axes, 'x');

        % --- NEUE ELEMENTE: Cursor und Wertanzeige BOX ---
        
        x_init = T_data(1);
        v_line1 = line(ax1, [x_init, x_init], ax1.YLim, 'Color', 'r', 'LineWidth', 1.5, 'Tag', 'VLine', 'Visible', 'off');
        v_line2 = line(ax2, [x_init, x_init], ax2.YLim, 'Color', 'r', 'LineWidth', 1.5, 'Tag', 'VLine', 'Visible', 'off');
        v_line3 = line(ax3, [x_init, x_init], ax3.YLim, 'Color', 'r', 'LineWidth', 1.5, 'Tag', 'VLine', 'Visible', 'off');
        vertical_lines = [v_line1, v_line2, v_line3];

        % KORRIGIERT: VerticalAlignment entfernt
        value_display = uicontrol(f, 'Style', 'text', 'String', 'Werte (t=0.00s)', ...
            'Units', 'normalized', 'Position', [0.01 0.78 0.25 0.18], ... 
            'FontSize', 10, ...
            'BackgroundColor', [0.95 0.95 0.95], ... 
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'left');

        data_interp_fun = @(t_query) getDriverDataAtTime(t_query, Driver_data, T_data);
        
        f.WindowButtonMotionFcn = {@updateGenericCursor, T_data, all_axes, vertical_lines, value_display, data_interp_fun};

        % --- Playback Data Struktur setzen ---
        play_data.T_data = T_data;
        play_data.vertical_lines = vertical_lines;
        play_data.value_display = value_display;
        play_data.all_axes = all_axes;
        play_data.data_interpolation = data_interp_fun; 
        
        play_data.timer_running = false; 
        play_data.current_time_idx = 1;  
        play_data.play_timer = [];       % WICHTIG: Initialisierung hier

        setappdata(f, 'PlaybackData', play_data);

    catch ME
        warning('Fehler in visualizeDriverDataSingle: %s', ME.message);
    end
end