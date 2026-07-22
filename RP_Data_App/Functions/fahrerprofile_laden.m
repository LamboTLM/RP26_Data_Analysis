% =========================================================================
%  fahrerprofile_laden  –  Fahrerprofile aus einer .mat-Datei laden
% -------------------------------------------------------------------------
%  Zweck         : Laedt die hinterlegten Fahrerprofile und liefert IMMER ein
%                  sauberes Struct-Array mit den Feldern:
%                     name (char), n_runden (double), kennzahlen (struct)
%                  Fehlende Datei -> leeres Array. Unbekanntes/altes Format
%                  wird best moeglich normalisiert (kein Absturz beim Aufrufer).
%
%  Speicherformat: Variable 'profile' (Struct-Array). Aeltere Dateien mit
%                  anderem Variablennamen werden ebenfalls erkannt (erste
%                  struct-Variable).
%
%  Abhaengigkeiten: (keine)
%  Autor         : <dein Name>
%  Datum         : 2026-07-18
% =========================================================================

function profile = fahrerprofile_laden(datei)
%FAHRERPROFILE_LADEN  profile = FAHRERPROFILE_LADEN(datei)
%   Changelog:
%     2026-07-18  Robuste Fassung (tolerant gegen Format/fehlende Felder).

    profile = struct('name', {}, 'n_runden', {}, 'kennzahlen', {});
    if nargin < 1 || isempty(datei) || ~ischar(datei) && ~isstring(datei), return; end
    datei = char(datei);
    if exist(datei, 'file') ~= 2, return; end

    try
        S = load(datei);
    catch
        return;   % beschaedigte Datei -> leer statt Fehler
    end

    % Variable finden: bevorzugt 'profile', sonst erste struct-Variable
    roh = [];
    if isfield(S, 'profile') && isstruct(S.profile)
        roh = S.profile;
    else
        fn = fieldnames(S);
        for k = 1:numel(fn)
            if isstruct(S.(fn{k})), roh = S.(fn{k}); break; end
        end
    end
    if isempty(roh) || ~isstruct(roh), return; end

    % Normalisieren auf festes Schema
    for i = 1:numel(roh)
        profile(i) = struct( ...
            'name',       char(feld(roh(i), 'name', sprintf('Fahrer %d', i))), ...
            'n_runden',   max(1, feld(roh(i), 'n_runden', 1)), ...
            'kennzahlen', feld(roh(i), 'kennzahlen', struct()) );
    end
end

% =========================================================================
%  Functions
% =========================================================================

function v = feld(s, name, default)
    if isstruct(s) && isscalar(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end
