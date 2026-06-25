function max_wert = signal_max_wert(signale, feldname, fallback)
%SIGNAL_MAX_WERT Gibt den maximalen Wert eines Signals zurück.
%
%   Eingabe:
%       signale  — Struct mit Signalen (timeseries oder numerisch)
%       feldname — String, Feldname des Signals
%       fallback — Wert, falls Signal fehlt oder leer
%
%   Ausgabe:
%       max_wert — Numerischer Maximalwert oder fallback
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

    if ~isfield(signale, feldname)
        max_wert = fallback;
        return;
    end

    daten = signale.(feldname);
    daten = extrahiere_rohdaten(daten);

    if isempty(daten) || ~isnumeric(daten) || all(isnan(daten))
        max_wert = fallback;
        return;
    end

    max_wert = max(daten, [], 'omitnan');
end