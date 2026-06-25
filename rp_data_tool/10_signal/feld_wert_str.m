function wert_str = feld_wert_str(signale, feldname, ok_feldname, fallback, modus)
%FELD_WERT_STR Gibt einen formatierten Wert aus einem Signal-Struct zurück.
%
%   Eingabe:
%       signale      — Struct mit Signalen und OK-Flags
%       feldname     — String, Feldname des Hauptsignals
%       ok_feldname  — String, Feldname des OK-Flags (optional, '' wenn nicht benötigt)
%       fallback     — Wert/String, falls Signal ungültig
%       modus        — String, optional:
%                      'mean_data' → Mittelwert über alle Datenpunkte
%                      '' oder fehlend → letzter Wert
%
%   Ausgabe:
%       wert_str     — Formatierter Wert als String/Double
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

    arguments
        signale
        feldname (1, :) char
        ok_feldname (1, :) char = ''
        fallback = '--'
        modus (1, :) char = ''
    end

    % Pruefen ob OK-Flag existiert und false ist
    if ~isempty(ok_feldname) && isfield(signale, ok_feldname)
        ok_wert = signale.(ok_feldname);
        if islogical(ok_wert) && ~ok_wert
            wert_str = fallback;
            return;
        end
        if isnumeric(ok_wert) && ok_wert == 0
            wert_str = fallback;
            return;
        end
    end

    % Pruefen ob Hauptfeld existiert
    if ~isfield(signale, feldname)
        wert_str = fallback;
        return;
    end

    daten = signale.(feldname);
    daten = extrahiere_rohdaten(daten);

    if isempty(daten) || ~isnumeric(daten) || all(isnan(daten))
        wert_str = fallback;
        return;
    end

    % Modus auswerten
    if strcmp(modus, 'mean_data')
        wert = mean(daten, 'omitnan');
    else
        gueltige_idx = find(~isnan(daten), 1, 'last');
        if isempty(gueltige_idx)
            wert_str = fallback;
            return;
        end
        wert = daten(gueltige_idx);
    end

    wert_str = wert;
end