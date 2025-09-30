function [f, all_axes] = visualizeDriverData(DataList, fahrzeitBereiche)
% DataList:       Cell-Array mit Fahrten {Data1, Data2, ...}
% fahrzeitBereiche: Cell-Array mit Zeitbereichen {bereich1, bereich2, ...}

try
    f = figure('Name', '1. Fahrerdaten Analyse', 'NumberTitle', 'off');
    t = tiledlayout(f, 3, 1);
    title(t, 'Fahrereingaben', 'FontSize', 14);

    % Farben automatisch vergeben
    cmap = lines(numel(DataList));

    % --- Achsen vorbereiten ---
    ax1 = nexttile(t); hold(ax1,'on'); grid(ax1,'on');
    title(ax1,'Gaspedalstellung'); xlabel(ax1,'Zeit [s]'); ylabel(ax1,'Throttle');
    
    ax2 = nexttile(t); hold(ax2,'on'); grid(ax2,'on');
    title(ax2,'Bremsdruck'); xlabel(ax2,'Zeit [s]'); ylabel(ax2,'Bar');
    
    ax3 = nexttile(t); hold(ax3,'on'); grid(ax3,'on');
    title(ax3,'Lenkwinkel'); xlabel(ax3,'Zeit [s]'); ylabel(ax3,'Winkel [°]');

    % --- Über alle Fahrten iterieren ---
    for k = 1:numel(DataList)
        Data = DataList{k};
        bereich = fahrzeitBereiche{k};

        %% Laden der nötigen Daten
        apps_res_can = extractTimetableFromCell(Data,'apps_res_can');
        apps1_can    = extractTimetableFromCell(Data,'apps1_can');
        apps2_can    = extractTimetableFromCell(Data,'apps2_can');
        apps3_can    = extractTimetableFromCell(Data,'apps3_can');
        pbrake_front_can = extractTimetableFromCell(Data,'pbrake_front_can');
        pbrake_rear_can  = extractTimetableFromCell(Data,'pbrake_rear_can');
        steering_wheel_angle_can = extractTimetableFromCell(Data,'steering_wheel_angle_can');

        Driver_data = synchronize(apps_res_can,apps1_can,apps2_can,apps3_can,...
            pbrake_front_can,steering_wheel_angle_can,pbrake_rear_can,"union","spline");
        Driver_data = Driver_data(bereich,:);

        % --- Zeit auf Null setzen (individuell pro Fahrt) ---
        t_rel = seconds(Driver_data.t - Driver_data.t(1));

        % Plot 1: Gaspedal
        plot(ax1, t_rel, Driver_data.apps_res_can, ...
            'Color', cmap(k,:), 'DisplayName', sprintf('Fahrt %d res',k));
        plot(ax1, t_rel, Driver_data.apps1_can, ...
            '--','Color', cmap(k,:), 'DisplayName', sprintf('Fahrt %d apps1',k));
        plot(ax1, t_rel, Driver_data.apps2_can, ...
            ':','Color', cmap(k,:), 'DisplayName', sprintf('Fahrt %d apps2',k));
        plot(ax1, t_rel, Driver_data.apps3_can, ...
            '-.','Color', cmap(k,:), 'DisplayName', sprintf('Fahrt %d apps3',k));

        % Plot 2: Bremse
        plot(ax2, t_rel, Driver_data.pbrake_front_can, ...
            'Color', cmap(k,:), 'DisplayName', sprintf('Fahrt %d Front',k));
        plot(ax2, t_rel, Driver_data.pbrake_rear_can, ...
            '--','Color', cmap(k,:), 'DisplayName', sprintf('Fahrt %d Rear',k));

        % Balance-Berechnung
        mask = (Driver_data.pbrake_front_can > 5) & (Driver_data.pbrake_rear_can > 5);
        if any(mask)
            front_eff = Driver_data.pbrake_front_can(mask) * 2; % 2 Kolben vorne
            rear_eff  = Driver_data.pbrake_rear_can(mask) * 1; % 1 Kolben hinten
            bal_real  = front_eff ./ (front_eff + rear_eff);
            bal_real_mean = mean(bal_real) * 100;
            disp(['Fahrt ',num2str(k),': Brake Balance = ',num2str(bal_real_mean,'%.1f'),' %']);
        end

        % Plot 3: Lenkwinkel
        plot(ax3, t_rel, Driver_data.steering_wheel_angle_can, ...
            'Color', cmap(k,:), 'DisplayName', sprintf('Fahrt %d',k));
    end

    % Legenden
    legend(ax1,'show','Location','best','ItemHitFcn',@cb_legend);
    legend(ax2,'show','Location','best','ItemHitFcn',@cb_legend);
    legend(ax3,'show','Location','best','ItemHitFcn',@cb_legend);

    % Achsen verlinken
    all_axes = [ax1, ax2, ax3];
    linkaxes(all_axes,'x');

catch ME
    disp(getReport(ME))
    f = [];
    all_axes = [];
end
end
