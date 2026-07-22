% =========================================================================
%  parameterconfigs_laden  –  Gespeicherte Fahrzeug-Parametersaetze laden
% -------------------------------------------------------------------------
%  Zweck         : Laedt benannte, vollstaendige Parametersaetze aus einer
%                  .mat-Datei (Variable 'configs'). Fehlt sie, kommt ein leeres
%                  Array zurueck. Die Standard-Config ist fahrzeug_parameter().
%  Abhaengigkeiten: keine
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function configs = parameterconfigs_laden(pfad)
%PARAMETERCONFIGS_LADEN  configs = PARAMETERCONFIGS_LADEN(pfad)
%   configs : struct-Array mit .name (char) .params (Parameter-Struct)
%   Changelog: 2026-07-15  Erststand.

    leer = struct('name', {}, 'params', {});
    if isempty(pfad) || ~isfile(pfad), configs = leer; return; end
    S = load(pfad);
    if isfield(S, 'configs'), configs = S.configs; else, configs = leer; end
end
