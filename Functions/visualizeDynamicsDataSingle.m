function [f, all_axes] = visualizeDynamicsDataSingle(Data,fahrzeitBereich)
try
    f = figure('Name', '3. Fahrdynamik Analyse', 'NumberTitle', 'off');
    t = tiledlayout(f, 2, 2);
    title(t, 'Fahrdynamik und Schlupfwinkel', 'FontSize', 14);

    INS_acc_x_can = extractTimetableFromCell(Data,'INS_acc_x_can');
    INS_acc_y_can = extractTimetableFromCell(Data,'INS_acc_y_can');
    INS_acc_z_can = extractTimetableFromCell(Data,'INS_acc_z_can');

    INS_ang_vel_z_can= extractTimetableFromCell(Data,'INS_ang_vel_z_can');

    Dynamics_Data_=synchronize(INS_acc_x_can,INS_acc_y_can,INS_acc_z_can,INS_ang_vel_z_can,"union","spline");
    Dynamics_Data_=Dynamics_Data_(fahrzeitBereich,:);

    % Plot 1: Längs- & Querbeschleunigung über Zeit
    % Plot 1: Längs- & Querbeschleunigung über Zeit
    ax1 = nexttile(t);
    hold(ax1, 'off');

    if ~all(isnan(Dynamics_Data_.INS_acc_y_can)) && ~all(isnan(Dynamics_Data_.INS_acc_x_can))
        hold(ax1, 'on');
        plot(ax1, Dynamics_Data_.t, Dynamics_Data_.INS_acc_y_can, 'DisplayName', 'Längs a_x');
        plot(ax1, Dynamics_Data_.t, Dynamics_Data_.INS_acc_x_can, 'DisplayName', 'Quer a_y');
        hold(ax1, 'off');
    else
        plotDataMissingBox(ax1);
    end
    title(ax1, 'Fahrzeugbeschleunigung');
    xlabel(ax1, 'Zeit [s]');
    ylabel(ax1, 'Beschleunigung [m/s²]');
    grid(ax1, 'on');

    % Plot 2: Gierrate über Zeit
    ax2 = nexttile(t);
    if ~all(isnan(Dynamics_Data_.INS_ang_vel_z_can)) % Muss den richtigen sensor wert noch raussuchen
        plot(ax2, Dynamics_Data_.t, Dynamics_Data_.INS_ang_vel_z_can, 'DisplayName', 'Gierrate');
    else
        plotDataMissingBox(ax2)
    end
    title(ax2, 'Gierrate');
    xlabel(ax2, 'Zeit [s]');
    ylabel(ax2, 'Gierrate [rad/s]');
    grid(ax2, 'on');

    % Plot 3: G-G-Diagramm
    ax3 = nexttile(t, [1 2]);
    if ~all(isnan(Dynamics_Data_.INS_acc_y_can)) && ~all(isnan(Dynamics_Data_.INS_acc_x_can))
        scatter(ax3, Dynamics_Data_.INS_acc_x_can, Dynamics_Data_.INS_acc_y_can, 10, seconds(Dynamics_Data_.t), 'filled');
    else
        plotDataMissingBox(ax3);
    end
    colormap(ax3, 'jet');
    c = colorbar(ax3);
    ylabel(c, 'Zeit [s]');
    title(ax3, 'G-G-Diagramm (a_y vs. a_x)');
    xlabel(ax3, 'ax (m/s^2)');
    ylabel(ax3, 'ay (m/s^2)');
    axis(ax3, 'equal');
    grid(ax3, 'on');

    %Plot g circles into scatter
    % Kreise bei 1g, 1.5g, 2g hinzufügen
    % Kreise bei 1g, 1.5g, 2g hinzufügen mit Beschriftung bei 45°
    hold(ax3, 'on');
    g = 9.81;
    radii = [1, 1.5, 2] * g;
    theta = linspace(0, 2*pi, 360); % für Kreise
    circleColor = [0.6 0.6 0.6];    % gut sichtbar in Light & Dark Mode

    % Winkel für die Beschriftung (45° = pi/4)
    labelAngle = pi / 4;

    for i = 1:length(radii)
        r = radii(i);
        x = r * cos(theta);
        y = r * sin(theta);

        % Kreis plotten
        plot(ax3, x, y, 'Color', circleColor, 'LineStyle', '--', 'LineWidth', 1);

        % Position für Beschriftung bei 45°
        xLabel = r * cos(labelAngle);
        yLabel = r * sin(labelAngle);

        % Text-Label (z. B. '1.0g', '1.5g', ...)
        label = sprintf('%.1fg', r / g);
        text(ax3, xLabel + 0.5, yLabel + 0.5, label, ...
            'Color', circleColor, ...
            'FontSize', 10, ...
            'FontWeight', 'normal', ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom');
    end

    all_axes = [ax1, ax2];
    linkaxes (all_axes, 'x');

catch
    f=[];
    all_axes=[];
end
end