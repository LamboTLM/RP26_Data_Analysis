function ax = erstelle_plot_bereich(parent, position, titel, cfg)
% Erstellt einen standardisierten Plot-Bereich
% Autor: [Benutzer]
% Datum: 2026-06-24

C = farben;
pnl = uipanel(parent, 'Position', position, 'BackgroundColor', C.panel, 'BorderType', 'line',  'BorderWidth', 1, 'HighlightColor', C.grau2);
uilabel(pnl, 'Position', [0, position(4) - 52, position(3), 18], 'Text', titel, 'FontSize', 10, 'FontWeight', 'bold', 'FontColor', C.rot, 'BackgroundColor', 'none');
ax = uiaxes(pnl, 'Position', [5, 5, position(3) - 10, position(4) - 58]);

% +RP Theme anwenden wenn verfuegbar
apply_rp_theme(ax, cfg);
end