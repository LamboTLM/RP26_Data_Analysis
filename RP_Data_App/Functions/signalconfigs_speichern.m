% =========================================================================
%  signalconfigs_speichern  –  Signal-Auswahl-Config speichern
% -------------------------------------------------------------------------
%  Zweck         : Speichert eine benannte Signal-Auswahl. Existiert der Name,
%                  wird er ueberschrieben, sonst angehaengt.
%  Abhaengigkeiten: signalconfigs_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function signalconfigs_speichern(pfad, name, signale)
%SIGNALCONFIGS_SPEICHERN  SIGNALCONFIGS_SPEICHERN(pfad, name, signale)
%   pfad    : Zielpfad der .mat-Datei
%   name    : char, Config-Name
%   signale : cellstr der Signalnamen
%   Changelog: 2026-07-15  Erststand.

    if isempty(pfad)
        error('signalconfigs_speichern:Pfad', 'Kein Config-Datei-Pfad gesetzt.');
    end
    configs = signalconfigs_laden(pfad);

    eintrag.name    = char(name);
    eintrag.signale = cellstr(signale);
    eintrag.signale = eintrag.signale(:).';

    idx = find(strcmp({configs.name}, eintrag.name), 1);
    if isempty(idx)
        configs(end+1) = eintrag;
    else
        configs(idx)   = eintrag;
    end
    save(pfad, 'configs');
end
