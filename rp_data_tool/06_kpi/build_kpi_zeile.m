function build_kpi_zeile(parent, kpi_daten, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

n = size(kpi_daten, 1);
w = floor(position(3) / n) - 5;
for i = 1:n
    build_kpi_karte(parent, kpi_daten{i, 1}, kpi_daten{i, 2}, kpi_daten{i, 3}, cfg, ...
        [position(1) + (i - 1) * (w + 5), position(2), w, position(4)]);
end
end