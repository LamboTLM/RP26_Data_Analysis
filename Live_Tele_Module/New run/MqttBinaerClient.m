classdef MqttBinaerClient < handle
% MQTTBINAERCLIENT  Binaersicherer MQTT-3.1.1-Client in reinem MATLAB.
%
%   Zweck:           Ersatz fuer mqttclient (Industrial Communication Toolbox).
%                    Dessen read()/Callback liefert die Payload als string und
%                    zerstoert damit binaere Daten auf zwei Wegen:
%                      1. UTF-8-Dekodierung: Bytes >= 0x80 werden zu U+FFFD
%                      2. C-String-Terminierung: alles ab dem ersten 0x00 faellt weg
%                    Diese Klasse spricht MQTT direkt ueber tcpclient und
%                    liefert die Payload als uint8-Vektor, Byte fuer Byte.
%   Abhaengigkeiten: tcpclient (MATLAB base bzw. Instrument Control Toolbox)
%   Autor:           Claude / Dynamics e.V.
%   Datum:           03.08.2026
%
%   Verwendung:
%     mq = MqttBinaerClient("mqtt-livetele.dynamics-regensburg.de", 1883, ...
%                           "liveTele_winApp", "dynamics", "MATLAB_" + randi(9999));
%     mq.verbinden();
%     mq.abonnieren("CAN");
%     while true
%         nachr = mq.empfangen();       % Struct-Array: .topic (string), .payload (uint8)
%         ...
%     end
%     mq.trennen();
%
%   Changelog:
%     03.08.2026  Erstfassung

    properties (SetAccess = private)
        host        string
        port        double
        benutzer    string
        passwort    string
        client_id   string
        keepalive_s double = 30      % Keepalive-Intervall [s]
        verbunden   logical = false
    end

    properties (Access = private)
        sock                          % tcpclient-Objekt
        puffer      uint8 = uint8([])  % noch nicht geparste Bytes
        letzter_ping double = 0
        paket_id    uint16 = uint16(1)
    end

    methods
        % -----------------------------------------------------------------
        function obj = MqttBinaerClient(host, port, benutzer, passwort, client_id, keepalive_s)
        % Konstruktor. host OHNE Schema ("tcp://" weglassen oder wird entfernt).

            if nargin < 5
                error('MqttBinaerClient:ZuWenigArgumente', ...
                    'host, port, benutzer, passwort und client_id sind erforderlich.');
            end
            host = string(host);
            host = regexprep(host, '^\w+://', '');    % "tcp://" entfernen
            obj.host      = host;
            obj.port      = double(port);
            obj.benutzer  = string(benutzer);
            obj.passwort  = string(passwort);
            obj.client_id = string(client_id);
            if nargin >= 6 && ~isempty(keepalive_s)
                obj.keepalive_s = keepalive_s;
            end
        end

        % -----------------------------------------------------------------
        function verbinden(obj, timeout_s)
        % VERBINDEN  TCP-Verbindung aufbauen und MQTT-CONNECT senden.

            if nargin < 2 || isempty(timeout_s), timeout_s = 10; end

            obj.sock = tcpclient(obj.host, obj.port, 'Timeout', timeout_s);
            obj.sock.ByteOrder = "big-endian";

            % --- CONNECT zusammensetzen ---
            flags = uint8(0);
            if strlength(obj.benutzer) > 0, flags = bitor(flags, uint8(128)); end
            if strlength(obj.passwort) > 0, flags = bitor(flags, uint8(64));  end
            flags = bitor(flags, uint8(2));               % Clean Session

            ka = uint16(obj.keepalive_s);
            var_header = [obj.mqtt_string("MQTT"), uint8(4), flags, ...
                          uint8(bitshift(ka, -8)), uint8(bitand(ka, 255))];

            nutzlast = obj.mqtt_string(obj.client_id);
            if strlength(obj.benutzer) > 0
                nutzlast = [nutzlast, obj.mqtt_string(obj.benutzer)];
            end
            if strlength(obj.passwort) > 0
                nutzlast = [nutzlast, obj.mqtt_string(obj.passwort)];
            end

            rest = [var_header, nutzlast];
            write(obj.sock, [uint8(16), obj.laenge_kodieren(numel(rest)), rest], "uint8");

            % --- CONNACK abwarten ---
            t0 = tic;
            while obj.sock.NumBytesAvailable < 4
                if toc(t0) > timeout_s
                    error('MqttBinaerClient:KeinConnack', ...
                        'Keine Antwort (CONNACK) vom Broker %s:%d.', obj.host, obj.port);
                end
                pause(0.01);
            end
            antw = read(obj.sock, 4, "uint8");
            if antw(1) ~= 32
                error('MqttBinaerClient:UnerwartetesPaket', ...
                    'Erwartet CONNACK (0x20), erhalten 0x%02X.', antw(1));
            end
            if antw(4) ~= 0
                error('MqttBinaerClient:ConnackFehler', ...
                    'Broker lehnt Verbindung ab, Return-Code %d (%s).', ...
                    antw(4), obj.connack_text(antw(4)));
            end

            obj.verbunden    = true;
            obj.letzter_ping = 0;
            obj.puffer       = uint8([]);
        end

        % -----------------------------------------------------------------
        function abonnieren(obj, topic, qos)
        % ABONNIEREN  SUBSCRIBE fuer ein Topic senden.

            if ~obj.verbunden
                error('MqttBinaerClient:NichtVerbunden', 'Erst verbinden() aufrufen.');
            end
            if nargin < 3 || isempty(qos), qos = 0; end

            pid  = obj.paket_id;
            obj.paket_id = obj.paket_id + 1;

            rest = [uint8(bitshift(pid, -8)), uint8(bitand(pid, 255)), ...
                    obj.mqtt_string(string(topic)), uint8(qos)];
            write(obj.sock, [uint8(130), obj.laenge_kodieren(numel(rest)), rest], "uint8");
        end

        % -----------------------------------------------------------------
        function nachrichten = empfangen(obj)
        % EMPFANGEN  Alle aktuell verfuegbaren PUBLISH-Nachrichten abholen.
        %
        %   Ausgang: Struct-Array mit Feldern
        %     .topic    string
        %     .payload  uint8-Zeilenvektor (unveraendert, binaersicher)
        %     .qos      double
        %
        %   Blockiert nicht. Kuemmert sich nebenbei um den Keepalive-Ping.

            nachrichten = struct('topic', {}, 'payload', {}, 'qos', {});
            if ~obj.verbunden, return; end

            % --- neue Bytes einsammeln ---
            n_verf = obj.sock.NumBytesAvailable;
            if n_verf > 0
                obj.puffer = [obj.puffer, uint8(read(obj.sock, n_verf, "uint8"))];
            end

            % --- Pakete aus dem Puffer schneiden ---
            while true
                [typ, kopf_len, rest_len, vollstaendig] = obj.paket_kopf(obj.puffer);
                if ~vollstaendig, break; end

                gesamt = kopf_len + rest_len;
                paket  = obj.puffer(1:gesamt);
                obj.puffer = obj.puffer(gesamt+1:end);

                if typ == 3          % PUBLISH
                    n = obj.publish_parsen(paket, kopf_len, rest_len);
                    if ~isempty(n), nachrichten(end+1) = n; end %#ok<AGROW>
                end
                % PINGRESP (13), SUBACK (9) usw. werden still verworfen
            end

            % --- Keepalive ---
            if obj.letzter_ping == 0
                obj.letzter_ping = tic;
            elseif toc(obj.letzter_ping) > obj.keepalive_s / 2
                write(obj.sock, uint8([192 0]), "uint8");   % PINGREQ
                obj.letzter_ping = tic;
            end
        end

        % -----------------------------------------------------------------
        function trennen(obj)
        % TRENNEN  DISCONNECT senden und Socket schliessen.

            if ~isempty(obj.sock) && obj.verbunden
                try
                    write(obj.sock, uint8([224 0]), "uint8");   % DISCONNECT
                catch
                    % Socket bereits weg
                end
            end
            obj.sock      = [];
            obj.verbunden = false;
        end

        % -----------------------------------------------------------------
        function delete(obj)
            obj.trennen();
        end
    end

    methods (Access = private, Static)
        % -----------------------------------------------------------------
        function b = mqtt_string(s)
        % MQTT_STRING  String als 2-Byte-Laenge (big endian) + UTF-8-Bytes.
            roh = uint8(unicode2native(char(s), 'UTF-8'));
            n   = numel(roh);
            b   = [uint8(bitshift(n, -8)), uint8(bitand(n, 255)), roh(:)'];
        end

        % -----------------------------------------------------------------
        function b = laenge_kodieren(n)
        % LAENGE_KODIEREN  MQTT-Variable-Length-Integer (Remaining Length).
            b = uint8([]);
            if n == 0, b = uint8(0); return; end
            while n > 0
                teil = mod(n, 128);
                n    = floor(n / 128);
                if n > 0, teil = teil + 128; end
                b(end+1) = uint8(teil);   %#ok<AGROW>
            end
        end

        % -----------------------------------------------------------------
        function [typ, kopf_len, rest_len, vollstaendig] = paket_kopf(puf)
        % PAKET_KOPF  Fixed Header auswerten, ohne den Puffer zu veraendern.
            typ = 0; kopf_len = 0; rest_len = 0; vollstaendig = false;
            if numel(puf) < 2, return; end

            typ = double(bitshift(puf(1), -4));

            % Variable-Length-Integer dekodieren (max. 4 Byte)
            wert = 0; faktor = 1; k = 2;
            while true
                if k > numel(puf) || k > 5, return; end   % noch nicht komplett
                b = double(puf(k));
                wert = wert + mod(b, 128) * faktor;
                faktor = faktor * 128;
                k = k + 1;
                if b < 128, break; end
            end

            kopf_len = k - 1;
            rest_len = wert;
            vollstaendig = numel(puf) >= kopf_len + rest_len;
        end

        % -----------------------------------------------------------------
        function n = publish_parsen(paket, kopf_len, rest_len)
        % PUBLISH_PARSEN  Topic und Payload aus einem PUBLISH-Paket holen.
            n = [];
            qos = double(bitand(bitshift(paket(1), -1), 3));

            i = kopf_len + 1;
            if numel(paket) < i + 1, return; end
            topic_len = double(paket(i)) * 256 + double(paket(i+1));
            i = i + 2;
            if numel(paket) < i + topic_len - 1, return; end
            topic_bytes = paket(i : i + topic_len - 1);
            i = i + topic_len;

            if qos > 0
                i = i + 2;      % Packet Identifier ueberspringen
            end

            ende = kopf_len + rest_len;
            if i > ende
                nutz = uint8([]);
            else
                nutz = paket(i:ende);
            end

            n = struct('topic',   string(native2unicode(topic_bytes, 'UTF-8')), ...
                       'payload', nutz(:)', ...
                       'qos',     qos);
        end

        % -----------------------------------------------------------------
        function t = connack_text(code)
        % CONNACK_TEXT  Klartext zum CONNACK-Return-Code.
            switch code
                case 1, t = 'Protokollversion nicht unterstuetzt';
                case 2, t = 'Client-ID abgelehnt';
                case 3, t = 'Broker nicht verfuegbar';
                case 4, t = 'Benutzername oder Passwort falsch';
                case 5, t = 'nicht autorisiert';
                otherwise, t = 'unbekannt';
            end
        end
    end
end
