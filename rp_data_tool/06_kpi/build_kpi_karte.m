function build_kpi_karte(parent, label, wert, einheit, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
pnl = uipanel(parent, 'Position', position, 'BackgroundColor', C.karte, 'BorderType', 'none');
uilabel(pnl, 'Position', [8, position(4) - 22, position(3) - 16, 14], ...
    'Text', upper(label), 'FontSize', 9, 'FontColor', C.grau, 'BackgroundColor', 'none');
if isnumeric(wert)
    val_str = sprintf('%.1f', wert);
else
    val_str = char(wert);
end
uilabel(pnl, 'Position', [8, 8, position(3) - 16, position(4) - 32], ...
    'Text', [val_str, ' ', einheit], 'FontSize', 18, 'FontWeight', 'bold', ...
    'FontColor', C.weiss, 'BackgroundColor', 'none', 'VerticalAlignment', 'top');
end