function wert = snap_wert_formatieren(val)
% Formatiert numerischen Wert fuer Snapshot-Anzeige
% Autor: [Benutzer]
% Datum: 2026-06-24

if ~isfinite(val)
    wert = 'NaN';
    return;
end
a = abs(val);
if a == 0
    wert = '0';
elseif a >= 1e5
    wert = sprintf('%.0f', val);
elseif a >= 1000
    wert = sprintf('%.1f', val);
elseif a >= 10
    wert = sprintf('%.2f', val);
elseif a >= 0.1
    wert = sprintf('%.3f', val);
else
    wert = sprintf('%.2e', val);
end
end