function [f, all_axes] = visualizeVehicleDataH2H(DataList, fahrzeitBereiche)
% DataList:        Cell-Array mit Fahrten {Data1, Data2, ...}
% fahrzeitBereiche: Cell-Array mit Zeitbereichen {bereich1, bereich2, ...}

try
    f = figure('Name', '2. Fahrzeugdaten Analyse', 'NumberTitle', 'off');
    t = tiledlayout(f, 2, 1);
    title(t, 'Fahrzeug- & Radmetriken', 'FontSize', 14);

    % Farben automatisch vergeben
    cmap = lines(numel(DataList));

    % --- Achsen vorbereiten ---
    ax1 = nexttile(t); hold(ax1,'on'); grid(ax1,'on');
    title(ax1, 'Rad-RPM'); xlabel(ax1,'Zeit [s]'); ylabel(ax1,'RPM');

    ax2 = nexttile(t); hold(ax2,'on'); grid(ax2,'on');
    title(ax2, 'Fahrzeuggeschwindigkeit über Reifen');
    xlabel(ax2,'Zeit [s]'); ylabel(ax2,'Geschwindigkeit [km/h]');

    % --- Über alle Fahrten iterieren ---
    for k = 1:numel(DataList)
        Data    = DataList{k};
        bereich = fahrzeitBereiche{k};

        %% Laden der nötigen Daten
        fl = extractTimetableFromCell(Data,'unitek_fl_speed_motor_ist_can');
        fr = extractTimetableFromCell(Data,'unitek_fr_speed_motor_ist_can');
        rl = extractTimetableFromCell(Data,'unitek_rl_speed_motor_ist_can');
        rr = extractTimetableFromCell(Data,'unitek_rr_speed_motor_ist_can');

        VehicleData = synchronize(fl, fr, rl, rr,"union","spline");
        VehicleData = VehicleData(bereich,:);

        % --- Zeit auf Null setzen ---
        t_rel = seconds(VehicleData.t - VehicleData.t(1));
        t_rel = seconds(t_rel);

        % Plot 1: Rad-RPM (alle vier Räder)
        plot(ax1, t_rel, VehicleData.unitek_fl_speed_motor_ist_can, ...
            'Color', cmap(k,:), 'LineStyle','-', 'DisplayName', sprintf('Fahrt %d FL',k));
        plot(ax1, t_rel, VehicleData.unitek_fr_speed_motor_ist_can, ...
            'Color', cmap(k,:), 'LineStyle','--','DisplayName', sprintf('Fahrt %d FR',k));
        plot(ax1, t_rel, VehicleData.unitek_rl_speed_motor_ist_can, ...
            'Color', cmap(k,:), 'LineStyle',':', 'DisplayName', sprintf('Fahrt %d RL',k));
        plot(ax1, t_rel, VehicleData.unitek_rr_speed_motor_ist_can, ...
            'Color', cmap(k,:), 'LineStyle','-.','DisplayName', sprintf('Fahrt %d RR',k));

        % Plot 2: Fahrzeuggeschwindigkeit
        wheelRPMs = VehicleData{:, {'unitek_fl_speed_motor_ist_can', ...
                                    'unitek_fr_speed_motor_ist_can', ...
                                    'unitek_rl_speed_motor_ist_can', ...
                                    'unitek_rr_speed_motor_ist_can'}};
        
        Tyre_speed = Speed_calculator(mean(abs(wheelRPMs), 2),'RP24e');
        Tyre_speed = timetable(t_rel, Tyre_speed);

        plot(ax2, Tyre_speed.t_rel, Tyre_speed.Tyre_speed, ...
            'Color', cmap(k,:), 'DisplayName', sprintf('Fahrt %d Geschw.',k));
    end

    % Legenden
    legend(ax1,'show','Location','best','ItemHitFcn',@cb_legend);
    legend(ax2,'show','Location','best','ItemHitFcn',@cb_legend);

    % Achsen verlinken
    all_axes = [ax1, ax2];
    linkaxes(all_axes,'x');

catch ME
    disp(getReport(ME))
    f = [];
    all_axes = [];
end
end
