function str = letzter_bool_str(signale, feldname)
%LETZTER_BOOL_STR Gibt den letzten Bool-Wert als lesbaren String zurueck.
%
%   Eingabe:
%       signale  — Struct mit Signalen
%       feldname — String, Feldname des booleschen Signals
%
%   Ausgabe:
%       str      — 'ON' / 'OFF' oder '--' bei Fehler
%
%   Autor:  [Benutzer]
%   Datum:  2026-06-24

str = '--';

if ~isfield(signale, feldname)
    return;
end

daten = extrahiere_rohdaten(signale.(feldname));

if isempty(daten)
    return;
end

% Letzten gueltigen Wert holen (nicht NaN)
gueltige_idx = find(~isnan(daten), 1, 'last');

if isempty(gueltige_idx)
    return;
end

wert = daten(gueltige_idx);

% Logisch oder numerisch 0/1 auswerten
if islogical(wert) || wert ~= 0
    str = 'ON';
else
    str = 'OFF';
end
end