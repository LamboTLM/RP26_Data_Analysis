% =========================================================================
%  signal_holen  –  Gueltiges Vorkommen eines Signals aus dem Store
% -------------------------------------------------------------------------
%  Zweck         : Loest Namensdopplungen auf: bevorzugt das gueltige
%                  Vorkommen; bleiben mehrere gueltig, das erste. Ist der
%                  Name gar nicht vorhanden, wird Status 'fehlt' gemeldet.
%  Abhaengigkeiten: keine
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function sig = signal_holen(store, name)
%SIGNAL_HOLEN  Liefert ein einzelnes Signal (Dopplungen aufgeloest).
%   sig = SIGNAL_HOLEN(store, name)
%
%   store : struct-Array aus load_mf4
%   name  : char/string, gesuchter Signalname
%
%   sig   : struct mit .name .t .value .unit .status .subsystem .is_bool
%           .status = 'fehlt' und leere t/value, falls nicht im Store.
%
%   Changelog:
%     2026-07-15  Erststand.

    %% Vorberechnung: alle Vorkommen finden
    name  = char(name);
    treffer = find(strcmp({store.name}, name));

    %% Ausgabe: nicht vorhanden
    if isempty(treffer)
        sig = struct('name', name, 't', [], 'value', [], 'unit', '', ...
                     'status', 'fehlt', 'subsystem', subsystem_aus_name(name), ...
                     'is_bool', false);
        return;
    end

    %% Berechnung: Dopplungsregel anwenden
    status_liste = {store(treffer).status};
    idx_gueltig  = treffer(strcmp(status_liste, 'gueltig'));

    if ~isempty(idx_gueltig)
        gewaehlt = idx_gueltig(1);   % gueltiges bevorzugt, davon das erste
    else
        gewaehlt = treffer(1);       % sonst schlicht das erste Vorkommen
    end

    %% Ausgabe
    e   = store(gewaehlt);
    sig = struct('name', e.name, 't', e.t, 'value', e.value, 'unit', e.unit, ...
                 'status', e.status, 'subsystem', e.subsystem, 'is_bool', e.is_bool);
end
