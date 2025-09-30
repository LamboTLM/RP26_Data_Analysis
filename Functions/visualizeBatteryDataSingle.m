function [f, all_axes] = visualizeBatteryDataSingle(Data,fahrzeitBereich)
try
    f = figure('Name', '4. Akkudaten Analyse', 'NumberTitle', 'off');
    t = tiledlayout(f, 3, 1);
    title(t, 'Akkuleistung & -management', 'FontSize', 14);

    ams_overall_voltage_can = extractTimetableFromCell(Data,'ams_overall_voltage_can');
    IVT_Result_I_can = extractTimetableFromCell(Data,'IVT_Result_I_can');
    IVT_Result_W_can = extractTimetableFromCell(Data,'IVT_Result_W_can');

    BatteryData=synchronize(ams_overall_voltage_can,IVT_Result_I_can,IVT_Result_W_can,"union","spline");
    BatteryData=BatteryData(fahrzeitBereich,:);

    % Plot 1: Batteriespannung über Zeit
    ax1 = nexttile(t);
    if ~all(isnan(BatteryData.ams_overall_voltage_can))
        plot(ax1, BatteryData.t, BatteryData.ams_overall_voltage_can, 'DisplayName', 'Spannung');
        title(ax1, 'Batteriespannung');
        xlabel(ax1, 'Zeit [s]');
        ylabel(ax1, 'Spannung [V]');
        grid(ax1, 'on');
    else
        plotDataMissingBox(ax1);
    end

    % % Plot 2: Batteriestrom über Zeit
    ax2 = nexttile(t);
    if ~all(isnan(BatteryData.IVT_Result_W_can))
        plot(ax2, BatteryData.t, BatteryData.IVT_Result_W_can, 'DisplayName', 'Strom');
        title(ax2, 'Batteriestrom');
        xlabel(ax2, 'Zeit [s]');
        ylabel(ax2, 'Strom [A]');
        grid(ax2, 'on');
    else
        plotDataMissingBox(ax2);
    end

    % Plot 3: Batterieleistung über Zeit
    ax3 = nexttile(t);

    if ~all(isnan(BatteryData.IVT_Result_W_can))
        % Grundplot
        plot(ax3, BatteryData.t, BatteryData.IVT_Result_W_can, ...
            'DisplayName', 'Leistung', 'Color', 'b');
        title(ax3, 'Batterieleistung');
        xlabel(ax3, 'Zeit [s]');
        ylabel(ax3, 'Leistung [W]');
        grid(ax3, 'on');
        hold(ax3, 'on');

        % --- Schwellwert definieren ---
        threshold = 80e3; % 80 kW in Watt
        mask = BatteryData.IVT_Result_W_can > threshold;

        % --- Verbundene Intervalle oberhalb 80 kW finden ---
        dmask = diff([false; mask; false]); % Übergänge finden
        start_idx = find(dmask == 1);
        end_idx   = find(dmask == -1) - 1;

        % --- Jedes Intervall plotten ---
        for i = 1:numel(start_idx)
            idx_range = start_idx(i):end_idx(i);

            % Zeitdauer berechnen
            if istimetable(BatteryData)
                dt = seconds(diff(BatteryData.t(idx_range)));
            else
                dt = diff(BatteryData.t(idx_range));
            end
            duration = sum(dt);

            % Bereich oberhalb 80 kW als rote Linie markieren
            plot(ax3, BatteryData.t(idx_range), ...
                BatteryData.IVT_Result_W_can(idx_range), ...
                'r', 'LineWidth', 2, 'DisplayName', sprintf('>80 kW #%d', i));

            % Dauer im Plot eintragen (in die Mitte des Intervalls)
            t_mid = BatteryData.t(round(mean(idx_range)));
            y_mid = threshold + 500; % etwas oberhalb der Grenze anzeigen
            text(ax3, t_mid, y_mid, sprintf('%.2f s', duration), ...
                'Color','r','FontWeight','bold', 'HorizontalAlignment','center');
        end

    else
        plotDataMissingBox(ax2);
    end

    % Threshold-Linie einzeichnen
    yline(ax3, threshold, '--k', '80 kW');
    hold(ax3, 'off');


    all_axes = [ax1, ax2, ax3];
    linkaxes (all_axes, 'x');

catch
    f=[];
    all_axes=[];
end
end