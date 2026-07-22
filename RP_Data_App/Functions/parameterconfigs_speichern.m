% =========================================================================
%  parameterconfigs_speichern  –  Fahrzeug-Parametersatz speichern
% -------------------------------------------------------------------------
%  Zweck         : Speichert den aktuellen Parametersatz unter einem Namen.
%                  Existiert der Name, wird er ueberschrieben, sonst angehaengt.
%  Abhaengigkeiten: parameterconfigs_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function parameterconfigs_speichern(pfad, name, params)
%PARAMETERCONFIGS_SPEICHERN  PARAMETERCONFIGS_SPEICHERN(pfad, name, params)
%   pfad   : Zielpfad der .mat-Datei
%   name   : char, Config-Name
%   params : Parameter-Struct (z.B. aus fahrzeug_parameter oder app.params)
%   Changelog: 2026-07-15  Erststand.

    if isempty(pfad)
        error('parameterconfigs_speichern:Pfad', 'Kein Parameter-Config-Pfad gesetzt.');
    end
    configs = parameterconfigs_laden(pfad);

    eintrag.name   = char(name);
    eintrag.params = params;

    idx = find(strcmp({configs.name}, eintrag.name), 1);
    if isempty(idx), configs(end+1) = eintrag; else, configs(idx) = eintrag; end
    save(pfad, 'configs');
end
