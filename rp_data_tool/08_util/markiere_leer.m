function markiere_leer(ax, nachricht, cfg)
% Zeigt "Keine Daten" in einem Plot-Bereich an
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
ax.Color = [0.11, 0.11, 0.11];
xlim(ax, [0, 1]);
ylim(ax, [0, 1]);
text(ax, 0.5, 0.55, 'KEINE DATEN', 'Color', C.fehlend, 'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
text(ax, 0.5, 0.38, nachricht, 'Color', [0.45, 0.45, 0.45], 'FontSize', 8, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
ax.XTick = [];
ax.YTick = [];
end