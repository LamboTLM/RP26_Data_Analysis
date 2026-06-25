function wert = letzter_wert(signale, feldname, fallback)
%LETZTER_WERT Gibt den letzten Wert eines Signals zurück.
%
%   Eingabe:
%       signale  — Struct mit Signalen (timeseries oder numerisch)
%       feldname — String, Feldname des Signals
%       fallback — Wert, falls Signal fehlt oder leer
%
%   Ausgabe:
%       wert     — Letzter gültiger Wert oder fallback
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

if ~isfield(signale, feldname)
    wert = fallback;
    return;
end

daten = signale.(feldname);
daten = extrahiere_rohdaten(daten);

if isempty(daten) || ~isnumeric(daten) || all(isnan(daten))
    wert = fallback;
    return;
end

gueltige_idx = find(~isnan(daten), 1, 'last');

if isempty(gueltige_idx)
    wert = fallback;
else
    wert = daten(gueltige_idx);
end
end