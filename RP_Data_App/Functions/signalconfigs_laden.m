% =========================================================================
%  signalconfigs_laden  –  Gespeicherte Signal-Auswahl-Configs laden
% -------------------------------------------------------------------------
%  Zweck         : Laedt benannte Signal-Auswahlen (fuer den Explorer) aus
%                  einer .mat-Datei (Variable 'configs'). Fehlt sie, kommt ein
%                  leeres Array zurueck.
%  Abhaengigkeiten: keine
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function configs = signalconfigs_laden(pfad)
%SIGNALCONFIGS_LADEN  configs = SIGNALCONFIGS_LADEN(pfad)
%   configs : struct-Array mit .name (char) .signale (cellstr)
%   Changelog: 2026-07-15  Erststand.

    leer = struct('name', {}, 'signale', {});
    if isempty(pfad) || ~isfile(pfad), configs = leer; return; end
    S = load(pfad);
    if isfield(S, 'configs'), configs = S.configs; else, configs = leer; end
end
