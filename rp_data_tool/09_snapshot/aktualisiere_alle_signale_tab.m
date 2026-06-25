function aktualisiere_alle_signale_tab(wert_label, signal_info, signale, t_snap, cfg)
% Aktualisiert Tab "Alle Signale" mit Snapshot-Werten
% Autor: [Benutzer]
% Datum: 2026-06-24

C = cfg.farben;
if ~isempty(wert_label) && isvalid(wert_label(1))
    wert_label(1).Text = sprintf('● Snapshot  @  t = %.3f s', t_snap);
    wert_label(1).FontColor = C.orange;
end
for i = 2:numel(wert_label)
    if ~isvalid(wert_label(i))
        continue;
    end
    fn = signal_info{i}{1};
    ok_fn = signal_info{i}{2};
    [v, fc] = util.signal_wert_zu_zeitpunkt(signale, fn, ok_fn, t_snap);
    wert_label(i).Text = v;
    wert_label(i).FontColor = fc;
end
end