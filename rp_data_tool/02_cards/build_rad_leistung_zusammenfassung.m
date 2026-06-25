function build_rad_leistung_zusammenfassung(parent, signale, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
pnl = uipanel(parent, 'Position', position, 'BackgroundColor', C.panel, 'BorderType', 'none');
uilabel(pnl, 'Position', [0, position(4) - 20, position(3), 16], 'Text', 'Mittlere Radleistung', ...
    'FontSize', 10, 'FontWeight', 'bold', 'FontColor', C.rot, 'BackgroundColor', 'none');

raeder = cfg.fahrzeug.raeder;
vals = zeros(1, numel(raeder));
gefunden = false;

for i = 1:numel(raeder)
    rad = raeder{i};
    if isfield(signale, ['P_mech_', rad, '_ok']) && signale.(['P_mech_', rad, '_ok'])
        try
            vals(i) = mean(abs(signale.(['P_mech_', rad]).Data)) / 1000;
            gefunden = true;
        catch
            % ignore
        end
    end
end

ax = uiaxes(pnl, 'Position', [5, 5, position(3) - 10, position(4) - 28]);
apply_rp_theme(ax, cfg);
if gefunden
    b = bar(ax, vals, 'FaceColor', 'flat');
    b.CData = repmat(C.rot, numel(raeder), 1);
    set(ax, 'XTickLabel', upper(raeder), 'XTick', 1:numel(raeder));
    ylabel(ax, 'Ø Leistung (kW)', 'Color', C.grau, 'FontSize', 8);
else
    markiere_leer(ax, 'Mech. Leistung nicht verfuegbar', cfg);
end
end