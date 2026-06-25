function plot_gg(ax, signale, cfg)
% Plottet g-g-Diagramm
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
fn_ax = signal_zu_feldname('INS_acc_x_can');
fn_ay = signal_zu_feldname('INS_acc_y_can');
fn_sp = signal_zu_feldname('speed_can');

if ~isfield(signale, fn_ax) || ~signale.([fn_ax, '_ok']) || ~isfield(signale, fn_ay) || ~signale.([fn_ay, '_ok'])
    markiere_leer(ax, 'IMU Daten (INS_acc_x/y) nicht verfuegbar', cfg);
    return;
end

ax_d = signale.(fn_ax).Data / cfg.phys.g;
ay_d = signale.(fn_ay).Data / cfg.phys.g;
t_ax = signale.(fn_ax).Time;

try
    if isfield(signale, fn_sp) && signale.([fn_sp, '_ok'])
        spd = interp1(signale.(fn_sp).Time, signale.(fn_sp).Data, t_ax, 'linear', 'extrap');
        scatter(ax, ay_d, ax_d, 2, spd, 'filled', 'MarkerFaceAlpha', 0.6);
        colormap(ax, 'hot');
        cb = colorbar(ax);
        cb.Color = C.grau;
        cb.Label.String = 'Speed (km/h)';
    else
        scatter(ax, ay_d, ax_d, 2, C.rot, 'filled', 'MarkerFaceAlpha', 0.5);
    end
catch
    scatter(ax, ay_d, ax_d, 2, C.rot, 'filled', 'MarkerFaceAlpha', 0.5);
end

hold(ax, 'on');
th = linspace(0, 2 * pi, 100);
for r = [1, 2]
    plot(ax, r * cos(th), r * sin(th), '--', 'Color', C.grau2, 'LineWidth', 0.8);
end
xline(ax, 0, 'Color', C.grau2, 'LineWidth', 0.8);
yline(ax, 0, 'Color', C.grau2, 'LineWidth', 0.8);
hold(ax, 'off');
axis(ax, 'equal');
xlabel(ax, 'a_y (g) — lateral', 'Color', C.grau, 'FontSize', 8);
ylabel(ax, 'a_x (g) — longitudinal', 'Color', C.grau, 'FontSize', 8);
xlim(ax, [-3, 3]);
ylim(ax, [-3, 3]);
end