function [codes, bytes_utf8, info] = payload_darstellungen(payload)
% PAYLOAD_DARSTELLUNGEN  Wandelt eine MQTT-Payload in alle Diagnose-Darstellungen.
%
%   [codes, bytes_utf8, info] = payload_darstellungen(payload)
%
%   Zweck:           MATLABs mqttclient liefert die Payload als string. Binaere
%                    Daten koennen dabei durch die UTF-8-Dekodierung zerstoert
%                    werden (ungueltige Bytes -> U+FFFD = 65533). Diese Funktion
%                    liefert alle Sichtweisen, damit genau das erkennbar wird.
%   Abhaengigkeiten: keine
%   Autor:           Claude / Dynamics e.V.
%   Datum:           03.08.2026
%
%   Ausgang:
%     codes       double-Vektor der Unicode-Codepoints (das, was MATLAB sieht)
%     bytes_utf8  uint8-Vektor der UTF-8-Bytes (Originalbytes, falls Text)
%     info        Struct: n_codes, n_bytes_utf8, n_ersatzzeichen,
%                 anteil_druckbar, max_code, ist_numerisch
%
%   Changelog:
%     03.08.2026  Erstfassung

info = struct('n_codes', 0, 'n_bytes_utf8', 0, 'n_ersatzzeichen', 0, ...
              'anteil_druckbar', NaN, 'max_code', 0, 'ist_numerisch', false);

if isempty(payload)
    codes = []; bytes_utf8 = uint8([]); return
end

% Payload kann string, char, cell oder bereits numerisch sein
if iscell(payload)
    payload = payload{1};
end

if isnumeric(payload)
    % Idealfall: MATLAB liefert bereits Bytes
    codes           = double(payload(:)');
    bytes_utf8      = uint8(min(max(codes, 0), 255));
    info.ist_numerisch = true;
else
    txt = char(string(payload));
    codes = double(txt);
    try
        bytes_utf8 = uint8(unicode2native(txt, 'UTF-8'));
    catch
        bytes_utf8 = uint8(min(codes, 255));
    end
end

info.n_codes         = numel(codes);
info.n_bytes_utf8    = numel(bytes_utf8);
info.n_ersatzzeichen = sum(codes == 65533);      % U+FFFD
info.max_code        = max([codes, 0]);
if ~isempty(codes)
    info.anteil_druckbar = mean(codes >= 32 & codes <= 126);
end
end
