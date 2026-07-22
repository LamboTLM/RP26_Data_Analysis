% =========================================================================
%  scratchconfigs_loeschen  –  Scratchbook-Layout entfernen
% -------------------------------------------------------------------------
%  Zweck         : Loescht ein benanntes Layout aus der Datei.
%  Abhaengigkeiten: scratchconfigs_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function scratchconfigs_loeschen(pfad, name)
%SCRATCHCONFIGS_LOESCHEN  SCRATCHCONFIGS_LOESCHEN(pfad, name)
%   Changelog: 2026-07-15  Erststand.

    if isempty(pfad) || ~isfile(pfad), return; end
    configs = scratchconfigs_laden(pfad);
    if isempty(configs), return; end
    configs = configs(~strcmp({configs.name}, char(name)));
    save(pfad, 'configs');
end
