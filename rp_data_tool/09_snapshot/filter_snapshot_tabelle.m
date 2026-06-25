function filter_snapshot_tabelle(uit, alle_namen, alle_werte, filter_str, lbl_anzahl, n_gesamt)
% Filtert Snapshot-Tabelle
% Autor: [Benutzer]
% Datum: 2026-06-24

fs = strtrim(filter_str);
if isempty(fs)
    mask = true(numel(alle_namen), 1);
else
    mask = contains(lower(alle_namen(:)), lower(fs));
end
uit.Data = [alle_namen(mask)', alle_werte(mask)'];
lbl_anzahl.Text = sprintf('%d / %d Signale', sum(mask), n_gesamt);
end