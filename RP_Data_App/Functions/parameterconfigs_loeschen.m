% =========================================================================
%  parameterconfigs_loeschen  –  Fahrzeug-Parametersatz entfernen
% -------------------------------------------------------------------------
%  Zweck         : Loescht eine benannte Parameter-Config aus der Datei.
%  Abhaengigkeiten: parameterconfigs_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function parameterconfigs_loeschen(pfad, name)
%PARAMETERCONFIGS_LOESCHEN  PARAMETERCONFIGS_LOESCHEN(pfad, name)
%   Changelog: 2026-07-15  Erststand.

    if isempty(pfad) || ~isfile(pfad), return; end
    configs = parameterconfigs_laden(pfad);
    if isempty(configs), return; end
    configs = configs(~strcmp({configs.name}, char(name)));
    save(pfad, 'configs');
end
