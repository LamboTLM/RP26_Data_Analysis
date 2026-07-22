% =========================================================================
%  fahrerprofile_speichern  –  Fahrerprofil anlegen / aktualisieren
% -------------------------------------------------------------------------
%  Zweck         : Speichert einen Fahrer (name + kennzahlen) in die
%                  Profildatei. Existiert der Name schon, werden die
%                  Kennzahlen als gleitender Mittelwert aktualisiert und
%                  n_runden hochgezaehlt; sonst wird ein neues Profil mit
%                  n_runden = 1 angelegt. Datei/Ordner werden bei Bedarf
%                  erzeugt. Speicherformat: Variable 'profile'.
%
%  Aufruf        : fahrerprofile_speichern(datei, name, kennzahlen)
%
%  Abhaengigkeiten: fahrerprofile_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-18
% =========================================================================

function fahrerprofile_speichern(datei, name, kennzahlen)
%FAHRERPROFILE_SPEICHERN  FAHRERPROFILE_SPEICHERN(datei, name, kennzahlen)
%   Changelog:
%     2026-07-18  Robuste Fassung (Merge per Name, legt Datei/Ordner an).

    %% Eingaben pruefen
    if nargin < 3 || isempty(datei)
        error('fahrerprofile_speichern:keineDatei', ...
              'Keine Profildatei gesetzt. Bitte zuerst eine Profildatei waehlen/anlegen.');
    end
    datei = char(datei);
    name  = strtrim(char(name));
    if isempty(name)
        error('fahrerprofile_speichern:keinName', 'Kein Fahrername angegeben.');
    end
    if ~isstruct(kennzahlen), kennzahlen = struct(); end

    %% Vorhandene Profile laden (robust) und mergen
    profile = fahrerprofile_laden(datei);
    idx = find(strcmp({profile.name}, name), 1);
    if isempty(idx)
        profile(end+1) = struct('name', name, 'n_runden', 1, 'kennzahlen', kennzahlen);
    else
        n = profile(idx).n_runden;
        profile(idx).kennzahlen = mittel_kennzahlen(profile(idx).kennzahlen, kennzahlen, n);
        profile(idx).n_runden   = n + 1;
    end

    %% Ordner sicherstellen und schreiben
    [ordner, ~, ~] = fileparts(datei);
    if ~isempty(ordner) && ~isfolder(ordner), mkdir(ordner); end
    save(datei, 'profile');
end

% =========================================================================
%  Functions
% =========================================================================

function k = mittel_kennzahlen(alt, neu, n)
% Gleitender Mittelwert je Kennzahl: (alt*n + neu)/(n+1); fehlende uebernehmen.
    if ~isstruct(alt), alt = struct(); end
    k  = alt;
    fn = fieldnames(neu);
    for i = 1:numel(fn)
        f  = fn{i};
        nv = neu.(f);
        if isfield(alt, f) && isscalar(alt.(f)) && isfinite(alt.(f)) && isscalar(nv) && isfinite(nv)
            k.(f) = (alt.(f) * n + nv) / (n + 1);
        else
            k.(f) = nv;
        end
    end
end
