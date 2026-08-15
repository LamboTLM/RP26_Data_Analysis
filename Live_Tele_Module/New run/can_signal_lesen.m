function wert = can_signal_lesen(daten, startbit, laenge_bit, byteorder, vorzeichen, faktor, offset)
% CAN_SIGNAL_LESEN  Extrahiert ein Signal aus den Datenbytes eines CAN-Frames.
%
%   wert = can_signal_lesen(daten, startbit, laenge_bit, byteorder, vorzeichen, faktor, offset)
%
%   Zweck:           Bitgenaue Signalextraktion nach DBC-Definition, sowohl
%                    Intel (little endian, @1) als auch Motorola (big endian, @0).
%   Abhaengigkeiten: keine
%   Autor:           Claude / Dynamics e.V.
%   Datum:           03.08.2026
%
%   Eingang:
%     daten       uint8-Vektor der Frame-Datenbytes (Byte 0 zuerst)
%     startbit    Startbit laut DBC [-]
%     laenge_bit  Signallaenge [bit]
%     byteorder   1 = Intel/little endian, 0 = Motorola/big endian
%     vorzeichen  '+' unsigned, '-' signed (two's complement)
%     faktor      Skalierung [physikalisch/LSB], optional (Standard 1)
%     offset      Nullpunktverschiebung [physikalisch], optional (Standard 0)
%
%   Ausgang:
%     wert        physikalischer Wert; NaN, wenn der Frame zu kurz ist
%
%   Changelog:
%     03.08.2026  Erstfassung

%% Konfiguration
if nargin < 6 || isempty(faktor), faktor = 1; end
if nargin < 7 || isempty(offset), offset = 0; end

daten = uint8(daten(:)');
n_bit = 8 * numel(daten);

%% Vorberechnungen
% Bitvektor aufbauen: globaler Bitindex = byte_index*8 + bit_in_byte
bits = false(1, n_bit);
for k = 1:numel(daten)
    b = double(daten(k));
    for j = 0:7
        bits((k-1)*8 + j + 1) = bitand(bitshift(b, -j), 1) == 1;
    end
end

%% Berechnung
if byteorder == 1
    % --- Intel / little endian: Startbit ist das LSB, aufsteigend ---
    idx = startbit + (0:laenge_bit-1);
else
    % --- Motorola / big endian: Startbit ist das MSB, Saegezahn-Zaehlung ---
    idx = zeros(1, laenge_bit);
    pos = startbit;
    for k = 1:laenge_bit
        idx(k) = pos;                       % k = 1 -> MSB
        if mod(pos, 8) == 0
            pos = pos + 15;                 % Bytegrenze: ins naechste Byte springen
        else
            pos = pos - 1;
        end
    end
    idx = fliplr(idx);                      % ab hier aufsteigende Wertigkeit
end

if any(idx < 0) || any(idx >= n_bit)
    wert = NaN;
    return
end

roh = 0;
for k = 1:laenge_bit
    if bits(idx(k) + 1)
        roh = roh + 2^(k-1);
    end
end

% Zweierkomplement
if vorzeichen == '-' && roh >= 2^(laenge_bit - 1)
    roh = roh - 2^laenge_bit;
end

%% Ausgabe
wert = roh * faktor + offset;
end
