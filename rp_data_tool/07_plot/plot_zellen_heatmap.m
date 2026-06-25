function plot_zellen_heatmap(ax, signale, modus, cfg)
% Plottet Zell-Spannungs- oder Temperatur-Heatmap
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
if strcmp(modus, 'voltage')
    prefix = 'ams_cell_voltage';
    n_zellen = cfg.ams.anzahl_zellen;
    n_zeilen = cfg.ams.heatmap_zeilen_v;
    n_spalten = cfg.ams.heatmap_spalten_v;
    einheit = 'V';
    clim_bereich = [3.5, 4.2];
else
    prefix = 'ams_cell_temp';
    n_zellen = cfg.ams.anzahl_temp_sensoren;
    n_zeilen = cfg.ams.heatmap_zeilen_t;
    n_spalten = cfg.ams.heatmap_spalten_t;
    einheit = '°C';
    clim_bereich = [20, 60];
end

daten = nan(n_zeilen, n_spalten);
n_gefunden = 0;
for i = 1:n_zellen
    r = floor((i - 1) / n_spalten) + 1;
    c = mod(i - 1, n_spalten) + 1;
    fn = signal_zu_feldname(sprintf('%s%03d_can', prefix, i));
    if isfield(signale, fn) && isfield(signale, [fn, '_ok']) && signale.([fn, '_ok'])
        try
            ts = signale.(fn);
            if isa(ts, 'timeseries')
                daten(r, c) = mean(ts.Data, 'omitnan');
            else
                daten(r, c) = mean(ts, 'omitnan');
            end
            n_gefunden = n_gefunden + 1;
        catch
            % ignore
        end
    end
end

if n_gefunden == 0
    util.markiere_leer(ax, sprintf('Keine Zell-%s Daten', einheit), cfg);
    return;
end

imagesc(ax, daten);
colormap(ax, 'hot');
clim(ax, clim_bereich);
cb = colorbar(ax);
cb.Color = C.grau;
cb.Label.String = einheit;
axis(ax, 'tight');
xlabel(ax, sprintf('Spalte  (%d/%d Zellen)', n_gefunden, n_zellen), 'Color', C.grau, 'FontSize', 8);
ylabel(ax, 'Reihe', 'Color', C.grau, 'FontSize', 8);
end