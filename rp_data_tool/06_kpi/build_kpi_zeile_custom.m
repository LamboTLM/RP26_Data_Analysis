function build_kpi_zeile_custom(parent, kpis, cfg, position)
% Autor: [Benutzer]
% Datum: 2026-06-24

n = size(kpis, 1);
w = floor(position(3) / n) - 5;
for i = 1:n
    build_kpi_karte(parent, kpis{i, 1}, kpis{i, 2}, kpis{i, 3}, cfg, ...
        [position(1) + (i - 1) * (w + 5), position(2), w, position(4)]);
end
end