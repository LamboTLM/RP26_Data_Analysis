function plot_gps(ax, signale, cfg)
% Plottet GPS-Track
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
if ~isfield(signale, 'gps_x_ok') || ~signale.gps_x_ok
    markiere_leer(ax, 'GPS / INS Daten nicht verfuegbar', cfg);
    return;
end

fn_spd = signal.signal_zu_feldname('speed_can');
try
    if isfield(signale, fn_spd) && signale.([fn_spd, '_ok'])
        spd_r = interp1(signale.(fn_spd).Time, signale.(fn_spd).Data, signale.gps_t, 'linear', 'extrap');
        scatter(ax, signale.gps_x, signale.gps_y, 3, spd_r, 'filled');
        colormap(ax, 'hot');
        cb = colorbar(ax);
        cb.Color = C.grau;
        cb.Label.String = 'Speed (km/h)';
    else
        plot(ax, signale.gps_x, signale.gps_y, 'Color', C.rot, 'LineWidth', 1.5);
    end
catch
    plot(ax, signale.gps_x, signale.gps_y, 'Color', C.rot, 'LineWidth', 1.5);
end

hold(ax, 'on');
plot(ax, signale.gps_x(1), signale.gps_y(1), 'o', 'Color', C.gruen, 'MarkerSize', 8, 'MarkerFaceColor', C.gruen);
hold(ax, 'off');
axis(ax, 'equal');
xlabel(ax, 'X (m)', 'Color', C.grau, 'FontSize', 8);
ylabel(ax, 'Y (m)', 'Color', C.grau, 'FontSize', 8);
end