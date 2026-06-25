function daten = extrahiere_rohdaten(roh)
%EXTRAHIERE_ROHDATEN Normalisiert Signal-Rohdaten zu einem numerischen Array.
%
%   Unterstuetzt:
%       - timeseries  → .Data
%       - Struct .Data → .Data
%       - Numerisch   → direkt
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

if isa(roh, 'timeseries')
    daten = roh.Data;
elseif isstruct(roh) && isfield(roh, 'Data')
    daten = roh.Data;
elseif isnumeric(roh) || islogical(roh)
    daten = roh;
else
    daten = [];
end

% Sicherstellen dass es ein Spaltenvektor oder Array ist
if ~isempty(daten) && isvector(daten)
    daten = daten(:);
end
end