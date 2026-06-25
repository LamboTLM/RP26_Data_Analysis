function [tabs, tab_namen] = erstelle_tabs(fig, cfg)
% Erstellt Tab-Group
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
tab_h = cfg.fenster.hoehe_px - cfg.layout.topbar_hoehe - cfg.layout.slider_hoehe;
tg = uitabgroup(fig, 'Position', [0, 0, cfg.fenster.breite_px, tab_h], 'TabLocation', 'top');

tab_namen = {'Dashboard', 'Battery & AMS', 'Powertrain', ...
    'Vehicle Dynamics', 'Efficiency', 'Temperaturen', ...
    'Slip & TC', 'PDU & Power', 'Brake Balance', ...
    'Efficiency Map', 'Compare', 'Alle Signale'};

tabs = gobjects(numel(tab_namen), 1);
for i = 1:numel(tab_namen)
    tabs(i) = uitab(tg, 'Title', tab_namen{i}, 'BackgroundColor', C.hintergrund);
end
end