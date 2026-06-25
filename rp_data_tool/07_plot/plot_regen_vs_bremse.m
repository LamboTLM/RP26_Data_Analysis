function plot_regen_vs_bremse(ax, signale, cfg)
% Plottet Rekuperation vs. Bremsleistung
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
if ~isfield(signale, 'P_pack_ok') || ~signale.P_pack_ok
    util.markiere_leer(ax, 'Pack-Leistung nicht verfuegbar', cfg);
    return;
end

try
    t = signale.P_pack.Time;
    P = signale.P_pack.Data;
    plot(ax, t, P .* (P > 0) / 1000, 'Color', C.rot, 'LineWidth', 1.0, 'DisplayName', 'Antrieb (kW)');
    hold(ax, 'on');
    plot(ax, t, -P .* (P < 0) / 1000, 'Color', C.gruen, 'LineWidth', 1.0, 'DisplayName', 'Rekuperation (kW)');
    hold(ax, 'off');
    legend(ax, 'Location', 'best', 'TextColor', C.grau, 'Color', [0.13, 0.13, 0.13], ...
        'EdgeColor', C.grau2, 'FontSize', 8);
    xlabel(ax, 'Zeit (s)', 'Color', C.grau, 'FontSize', 8);
    ylabel(ax, 'Leistung (kW)', 'Color', C.grau, 'FontSize', 8);
catch ME
    util.markiere_leer(ax, sprintf('Fehler: %s', ME.message), cfg);
end
end