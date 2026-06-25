function cfg = get_config()
% Zentrale Konstanten und Konfiguration
% Autor: [Benutzer]
% Datum: 2026-06-24

cfg = struct();

% Fenster
cfg.fenster.breite_px = 1600;
cfg.fenster.hoehe_px  = 980;
cfg.fenster.x_pos_px  = 50;
cfg.fenster.y_pos_px  = 50;

% +RP Theme Integration
cfg.rp_theme.aktiv = true;
cfg.rp_theme.modus = 'dark';

% Farben (Fallback wenn +RP nicht verfuegbar)
cfg.farben.hintergrund = [0.12, 0.12, 0.12];
cfg.farben.hintergrund2 = [0.15, 0.15, 0.15];
cfg.farben.panel = [0.16, 0.16, 0.16];
cfg.farben.karte = [0.20, 0.20, 0.20];
cfg.farben.rot = [0.80, 0.00, 0.00];
cfg.farben.rot_hell = [1.00, 0.42, 0.42];
cfg.farben.weiss = [1.00, 1.00, 1.00];
cfg.farben.grau = [0.55, 0.55, 0.55];
cfg.farben.grau2 = [0.35, 0.35, 0.35];
cfg.farben.gruen = [0.30, 0.75, 0.30];
cfg.farben.orange = [1.00, 0.60, 0.00];
cfg.farben.gelb = [1.00, 0.85, 0.00];
cfg.farben.fehlend = [0.50, 0.50, 0.50];
cfg.farben.topbar = [0.08, 0.08, 0.08];
cfg.farben.slider_hintergrund = [0.10, 0.10, 0.10];
cfg.farben.teal = [0.0, 0.70, 0.70];


% Physikalische Konstanten
cfg.phys.g = 9.81;
cfg.phys.kwh_pro_j = 1 / 3.6e6;
cfg.phys.wh_pro_j = 1 / 3600;
cfg.phys.rad_pro_rpm = 2 * pi / 60;

% Filter
cfg.filter.alpha_hp = 0.995;
cfg.filter.alpha_hp_track = 0.998;

% AMS / Batterie
cfg.ams.anzahl_zellen = 144;
cfg.ams.anzahl_temp_sensoren = 48;
cfg.ams.heatmap_spalten_v = 12;
cfg.ams.heatmap_zeilen_v = 12;
cfg.ams.heatmap_spalten_t = 8;
cfg.ams.heatmap_zeilen_t = 6;

% Fahrzeug
cfg.fahrzeug.raeder = {'fl', 'fr', 'rl', 'rr'};
cfg.fahrzeug.anzahl_raeder = 4;

% GUI Layout
cfg.layout.topbar_hoehe = 45;
cfg.layout.slider_hoehe = 52;
cfg.layout.tab_hoehe = 900;
cfg.layout.zeilen_hoehe_signale = 13;
cfg.layout.sektions_hoehe_signale = 14;
cfg.layout.schrift.signal = 7.5;
cfg.layout.schrift.header = 7;
cfg.layout.spalten_signale = 4;

% Schwellenwerte
cfg.schwellen.eta_min_wert = 5;
cfg.schwellen.pack_leistung_min = 100;
end