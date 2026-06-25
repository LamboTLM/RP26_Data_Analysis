function on_snapshot_btn(signale, ef_snap, wert_label, signal_info, cfg)
% Callback fuer Snapshot-Button
% Autor: [Benutzer]
% Datum: 2026-06-24

t = ef_snap.Value;
build_snapshot_fenster(signale, t, cfg);
aktualisiere_alle_signale_tab(wert_label, signal_info, signale, t, cfg);
end