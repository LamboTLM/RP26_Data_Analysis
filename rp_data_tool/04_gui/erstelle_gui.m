function erstelle_gui(signale, meta, datei_pfad_voll, cfg)
% Erstellt Haupt-GUI mit Tabs und Slider
% Autor: [Benutzer]
% Datum: 2026-06-24
% Changelog: Tab-Funktionsaufrufe korrigiert (direkt statt tabs.xxx)

C = cfg.farben;

% Gesamtzeit bestimmen
t_gesamt = 0;
if isfield(signale, 't_base') && ~isempty(signale.t_base)
    t_gesamt = max(signale.t_base);
end
if t_gesamt < 1
    t_gesamt = 3600;
end

% Hauptfigure
fig = uifigure('Name', sprintf('RP FSAE Data Tool — %s — %s', meta.fahrzeug, meta.event), ...
    'Position', [cfg.fenster.x_pos_px, cfg.fenster.y_pos_px, cfg.fenster.breite_px, cfg.fenster.hoehe_px], ...
    'Color', C.hintergrund);

% Top Bar
btn_snap = erstelle_top_bar(fig, meta, datei_pfad_voll, signale, cfg);

% Slider Panel
[ef_start, sl_start, ef_ende, sl_ende, lbl_bereich] = erstelle_slider_panel(fig, cfg, t_gesamt);

% Tabs
[tabs, tab_namen] = erstelle_tabs(fig, cfg);

% --- Tabs aufbauen (DIREKTE Funktionsaufrufe, nicht tabs.xxx!) ---
build_tab_dashboard(tabs(1), signale, meta, cfg);
build_tab_batterie(tabs(2), signale, cfg);
build_tab_powertrain(tabs(3), signale, cfg);
build_tab_dynamik(tabs(4), signale, cfg);
build_tab_effizienz(tabs(5), signale, cfg);
build_tab_temperaturen(tabs(6), signale, cfg);
build_tab_slip_tc(tabs(7), signale, cfg);
build_tab_pdu(tabs(8), signale, cfg);

% NEUE TABS
build_tab_bremse_balance(tabs(9), signale, cfg);
build_tab_efficiency_map(tabs(10), signale, cfg);
build_tab_compare(tabs(11), signale, cfg);

% Tab "Alle Signale" gibt Handles zurueck
[wert_label, signal_info] = build_tab_alle_signale(tabs(12), signale, cfg);

% Snapshot-Button Callback
ef_snap = btn_snap.UserData;
btn_snap.ButtonPushedFcn = @(~,~) snapshot.on_snapshot_btn(signale, ef_snap, wert_label, signal_info, cfg);

% --- Slider Callbacks ---
    function apply_time_window(t_s, t_e)
        t_s = max(0, min(t_s, t_e - 0.1));
        t_e = min(t_gesamt, max(t_e, t_s + 0.1));
        sl_start.Value = t_s; ef_start.Value = t_s;
        sl_ende.Value = t_e; ef_ende.Value = t_e;
        lbl_bereich.Text = sprintf('%.1f – %.1f s  (%.1f s)', t_s, t_e, t_e - t_s);
        ax_liste = findall(fig, 'Type', 'axes');
        for ai = 1:numel(ax_liste)
            try
                xlim(ax_liste(ai), [t_s, t_e]);
            catch
                % ignore
            end
        end
    end

sl_start.ValueChangedFcn = @(src,~) apply_time_window(src.Value, sl_ende.Value);
sl_ende.ValueChangedFcn = @(src,~) apply_time_window(sl_start.Value, src.Value);
ef_start.ValueChangedFcn = @(src,~) apply_time_window(src.Value, sl_ende.Value);
ef_ende.ValueChangedFcn = @(src,~) apply_time_window(sl_start.Value, src.Value);

fprintf('GUI gestartet.\n');
end