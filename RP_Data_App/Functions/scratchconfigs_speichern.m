% =========================================================================
%  scratchconfigs_speichern  –  Scratchbook-Layout speichern
% -------------------------------------------------------------------------
%  Zweck         : Speichert ein benanntes Layout (Plots + Math-Kanaele).
%                  Existiert der Name, wird er ueberschrieben.
%  Abhaengigkeiten: scratchconfigs_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function scratchconfigs_speichern(pfad, name, config)
%SCRATCHCONFIGS_SPEICHERN  SCRATCHCONFIGS_SPEICHERN(pfad, name, config)
%   config : struct mit Feldern plots (Array) und math (Array)
%   Changelog: 2026-07-15  Erststand.

    if isempty(pfad)
        error('scratchconfigs_speichern:Pfad', 'Kein Scratchbook-Config-Pfad gesetzt.');
    end
    configs = scratchconfigs_laden(pfad);

    eintrag.name   = char(name);
    eintrag.config = config;

    idx = find(strcmp({configs.name}, eintrag.name), 1);
    if isempty(idx), configs(end+1) = eintrag; else, configs(idx) = eintrag; end
    save(pfad, 'configs');
end
