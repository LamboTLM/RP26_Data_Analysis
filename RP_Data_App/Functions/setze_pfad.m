% =========================================================================
%  setze_pfad  –  Verschachtelten Struct-Wert ueber einen Punkt-Pfad setzen
% -------------------------------------------------------------------------
%  Zweck         : Schreibt einen Wert an einen Punkt-Pfad in einen Struct,
%                  z.B. setze_pfad(params, 'fahrzeug.masse_gesamt_kg', 305).
%                  Fuer das Zurueckschreiben geaenderter Parameter aus dem Tab.
%  Abhaengigkeiten: keine
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function s = setze_pfad(s, pfad, wert)
%SETZE_PFAD  s = SETZE_PFAD(s, pfad, wert)
%   Changelog: 2026-07-15  Erststand.

    teile = strsplit(char(pfad), '.');
    s = setze_rek(s, teile, wert);
end

function s = setze_rek(s, teile, wert)
    if numel(teile) == 1
        s.(teile{1}) = wert;
    else
        if ~isfield(s, teile{1}) || ~isstruct(s.(teile{1}))
            s.(teile{1}) = struct();
        end
        s.(teile{1}) = setze_rek(s.(teile{1}), teile(2:end), wert);
    end
end
