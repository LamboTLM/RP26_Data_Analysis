% =========================================================================
%  scratchconfigs_laden  –  Gespeicherte Scratchbook-Layouts laden
% -------------------------------------------------------------------------
%  Zweck         : Laedt benannte Scratchbook-Layouts (Plots + Math-Kanaele)
%                  aus einer .mat-Datei (Variable 'configs').
%  Abhaengigkeiten: keine
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function configs = scratchconfigs_laden(pfad)
%SCRATCHCONFIGS_LADEN  configs = SCRATCHCONFIGS_LADEN(pfad)
%   configs : struct-Array mit .name (char) .config (struct: plots, math)
%   Changelog: 2026-07-15  Erststand.

    leer = struct('name', {}, 'config', {});
    if isempty(pfad) || ~isfile(pfad), configs = leer; return; end
    S = load(pfad);
    if isfield(S, 'configs'), configs = S.configs; else, configs = leer; end
end
