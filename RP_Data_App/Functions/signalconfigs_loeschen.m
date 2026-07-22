% =========================================================================
%  signalconfigs_loeschen  –  Signal-Auswahl-Config entfernen
% -------------------------------------------------------------------------
%  Zweck         : Loescht eine benannte Config aus der Datei.
%  Abhaengigkeiten: signalconfigs_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function signalconfigs_loeschen(pfad, name)
%SIGNALCONFIGS_LOESCHEN  SIGNALCONFIGS_LOESCHEN(pfad, name)
%   Changelog: 2026-07-15  Erststand.

    if isempty(pfad) || ~isfile(pfad), return; end
    configs = signalconfigs_laden(pfad);
    if isempty(configs), return; end
    configs = configs(~strcmp({configs.name}, char(name)));
    save(pfad, 'configs');
end
