% =========================================================================
%  DatenanalyseApp  –  Grundgeruest der Datenanalyse-App
% -------------------------------------------------------------------------
%  Zweck         : Programmatische MATLAB-App (Backend) im Dynamics-e.V.-Format.
%                  Rote Kopfzeile + "Auswahl"-Panel wie im Reifen-Tool. Ueber
%                  den Ladeknopf wird ein ORDNER gewaehlt; ein Dropdown listet
%                  alle .mf4-Testdaten darin. Die gewaehlte Datei wird eager mit
%                  Fortschrittsbalken in den Signal-Store geladen; jeder Tab
%                  erhaelt seine Payload ueber eine eigene payload_<tab>-Function.
%                  JavaScript (je Tab eine HTML-Datei) wird separat gebaut;
%                  export_payloads_json liefert die Vertraege zum Testen.
%  Abhaengigkeiten: load_mf4, berechne_x_achse, fahrzeug_parameter,
%                   payload_<tab> (je Tab eine Function)
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

classdef DatenanalyseApp < handle

    %% Eigenschaften
    properties (Access = public)
        fig                          % uifigure
        tabgroup                     % uitabgroup
        html_map                     % containers.Map: tabname -> uihtml
    end

    properties (Access = private)
        store        = struct([])    % Signal-Store (load_mf4)
        x            = struct([])    % aktuelle x-Achse (berechne_x_achse)
        params                       % Fahrzeugparameter
        runden       = struct('name', {}, 't_start', {}, 't_ende', {}, 'fahrer', {})
        ordner       = ''            % aktuell gewaehlter Datenordner
        x_modus      = 'distanz'     % Standard laut Konzept
        payload_map                  % containers.Map: tabname -> function_handle

        dd_datei                     % Dropdown: Testdaten im Ordner
        dd_runde                     % Dropdown: Runde
        lbl_ordner                   % Label: gewaehlter Ordner
        html_dir                     % Ordner mit den Tab-HTML-Dateien (+ ./lib)

        % Reihenfolge = Tab-Reihenfolge in der Oberflaeche
        tab_namen = { 'uebersicht','fahrdynamik','fahrer','fahrerprofile', ...
                      'hardware_software','akku','mechanik','parameter','scratchbook' }
        tab_titel = { 'Übersicht','Fahrdynamik','Fahrer','Fahrerprofile', ...
                      'Hardware/Software','Akku','Mechanik','Fahrzeug-Parameter','Scratchbook' }

        % Team-Branding (aus dem Reifen-Tool uebernommen)
        C_ROT    = [0.7804 0.1333 0.1608]
        C_BG     = [0.1200 0.1200 0.1200]
        C_FG     = [0.9000 0.9000 0.8800]
        FONT_MARKE = 'Rift'
    end

    %% Konstruktor
    methods (Access = public)
        function app = DatenanalyseApp()
            app.params = fahrzeug_parameter();
            % HTML-Ordner: standardmaessig der Ordner dieser Klassendatei
            % (dort liegen die <tab>.html und der ./lib-Ordner). Bei Bedarf
            % vor dem Start anpassen: app.html_dir = 'C:\pfad\zu\html';
            app.html_dir = fileparts(mfilename('fullpath'));
            % Standard-Profildatei (kann im Tab per Dialog gewechselt werden)
            app.params.profil_datei = fullfile(app.html_dir, 'fahrerprofile.mat');
            app.registriere_payloads();
            app.baue_ui();
            app.tab_aktualisieren('fahrerprofile');   % hinterlegte Profile initial zeigen
        end

        function delete(app)
            if ~isempty(app.fig) && isvalid(app.fig), delete(app.fig); end
        end

        function export_payloads_json(app, zielordner)
        %EXPORT_PAYLOADS_JSON  Schreibt je Tab den Dateivertrag als .json.
            if isempty(fieldnames(app.store))
                error('DatenanalyseApp:KeinStore', 'Erst eine Datei laden.');
            end
            if nargin < 2, zielordner = pwd; end
            for i = 1:numel(app.tab_namen)
                name = app.tab_namen{i};
                pl   = app.baue_payload(name);
                fid  = fopen(fullfile(zielordner, [name '.json']), 'w', 'n', 'UTF-8');
                fwrite(fid, jsonencode(pl), 'char'); fclose(fid);
            end
        end
    end

    %% Private: Aufbau
    methods (Access = private)

        function registriere_payloads(app)
            % Je Tab eine eigene Function -> saubere Trennung, eigene HTML-Datei.
            app.payload_map = containers.Map( app.tab_namen, { ...
                @payload_uebersicht, @payload_fahrdynamik, @payload_fahrer, ...
                @payload_fahrerprofile, @payload_hardware_software, @payload_akku, ...
                @payload_mechanik, @payload_parameter, @payload_scratchbook } );
        end

        function baue_ui(app)
            app.fig = uifigure('Name', 'Datenanalyse-Tool', ...
                'Color', app.C_BG, 'Position', [80 80 1280 800]);

            haupt = uigridlayout(app.fig, [3 1], ...
                'RowHeight', {62, 64, '1x'}, 'BackgroundColor', app.C_BG, ...
                'Padding', [6 6 6 6], 'RowSpacing', 6);

            app.baue_kopfzeile(haupt);
            app.baue_auswahl(haupt);
            app.baue_tabs(haupt);
        end

        function baue_kopfzeile(app, parent)
            % Rote Marken-Kopfzeile: links "Dynamics e.V.", rechts Tool | Car No.
            banner = uipanel(parent, 'BackgroundColor', app.C_ROT, ...
                'BorderType', 'none');
            g = uigridlayout(banner, [1 2], 'ColumnWidth', {'fit','1x'}, ...
                'BackgroundColor', app.C_ROT, 'Padding', [10 4 12 4]);

            uilabel(g, 'Text', 'Dynamics e.V.', 'FontName', app.FONT_MARKE, ...
                'FontSize', 36, 'FontColor', [0.11 0.11 0.11]);

            r = uilabel(g, 'Text', 'Datenanalyse | Car No. 62', ...
                'FontName', app.FONT_MARKE, 'FontSize', 18, ...
                'FontColor', [0.11 0.11 0.11], 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'center');
            r.Layout.Column = 2;
        end

        function baue_auswahl(app, parent)
            % "Auswahl"-Panel: Ordner waehlen | Datei-Dropdown | Laden | x-Achse | Runde
            panel = uipanel(parent, 'Title', 'Auswahl', ...
                'ForegroundColor', app.C_ROT, 'FontName', app.FONT_MARKE, ...
                'BackgroundColor', app.C_BG);
            g = uigridlayout(panel, [1 6], ...
                'ColumnWidth', {120, '1x', 80, 70, 110, 120}, ...
                'BackgroundColor', app.C_BG, 'Padding', [8 6 8 6], 'ColumnSpacing', 8);

            uibutton(g, 'Text', 'Ordner wählen…', ...
                'BackgroundColor', app.C_ROT, 'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.ordner_waehlen());

            app.dd_datei = uidropdown(g, ...
                'Items', {'— kein Ordner gewählt —'}, 'ItemsData', {''}, ...
                'BackgroundColor', app.C_BG, 'FontColor', app.C_FG);

            uibutton(g, 'Text', 'Laden', ...
                'BackgroundColor', app.C_ROT, 'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.lade_gewaehlte_datei());

            uilabel(g, 'Text', 'x-Achse:', 'FontColor', app.C_FG, ...
                'HorizontalAlignment', 'right');

            uidropdown(g, 'Items', {'Distanz','Zeit'}, ...
                'ItemsData', {'distanz','zeit'}, 'Value', app.x_modus, ...
                'BackgroundColor', app.C_BG, 'FontColor', app.C_FG, ...
                'ValueChangedFcn', @(s,~) app.x_modus_geaendert(s.Value));

            app.dd_runde = uidropdown(g, 'Items', {'ganzer Run'}, ...
                'ItemsData', {''}, 'BackgroundColor', app.C_BG, 'FontColor', app.C_FG);
        end

        function baue_tabs(app, parent)
            app.tabgroup = uitabgroup(parent);
            app.tabgroup.Layout.Row = 3;
            app.html_map = containers.Map('KeyType','char','ValueType','any');

            for i = 1:numel(app.tab_namen)
                tab = uitab(app.tabgroup, 'Title', app.tab_titel{i}, ...
                    'BackgroundColor', app.C_BG);
                g = uigridlayout(tab, [1 1], 'Padding', [0 0 0 0], ...
                    'BackgroundColor', app.C_BG);
                pfad = fullfile(app.html_dir, [app.tab_namen{i} '.html']);
                if isfile(pfad)
                    quelle = pfad;                                   % echte Tab-HTML
                else
                    quelle = app.platzhalter_html(app.tab_titel{i}); % Rueckfall
                end
                h = uihtml(g, ...
                    'HTMLSource', quelle, ...
                    'Data', struct(), ...
                    'HTMLEventReceivedFcn', @(s,e) app.html_event(app.tab_namen{i}, e));
                app.html_map(app.tab_namen{i}) = h;
            end
        end
    end

    %% Private: Ablauf
    methods (Access = private)

        function ordner_waehlen(app)
            % Ordner waehlen und alle .mf4-Testdaten ins Dropdown fuellen.
            start = app.ordner; if isempty(start), start = pwd; end
            d = uigetdir(start, 'Ordner mit Testdaten wählen');
            if isequal(d, 0), return; end
            app.ordner = d;

            dateien = dir(fullfile(d, '*.mf4'));
            if isempty(dateien)
                app.dd_datei.Items     = {'— keine .mf4 im Ordner —'};
                app.dd_datei.ItemsData = {''};
                return;
            end
            namen = {dateien.name};
            app.dd_datei.Items     = namen;
            app.dd_datei.ItemsData = fullfile(d, namen);
            app.dd_datei.Value     = app.dd_datei.ItemsData{1};
        end

        function lade_gewaehlte_datei(app)
            pfad = app.dd_datei.Value;
            if isempty(pfad)
                uialert(app.fig, 'Bitte erst einen Ordner wählen und eine Datei auswählen.', ...
                    'Keine Datei');
                return;
            end

            dlg = uiprogressdlg(app.fig, 'Title', 'Lade Logdatei', ...
                'Indeterminate', 'off', 'Cancelable', 'off');
            cb  = @(anteil, text) app.setze_fortschritt(dlg, anteil, text);
            try
                app.store = load_mf4(pfad, cb);
            catch err
                close(dlg);
                uialert(app.fig, err.message, 'Fehler beim Laden');
                return;
            end
            close(dlg);

            app.x = berechne_x_achse(app.store, app.x_modus, app.params);
            app.alle_tabs_aktualisieren();
        end

        function setze_fortschritt(~, dlg, anteil, text)
            if isvalid(dlg)
                dlg.Value   = max(0, min(1, anteil));
                dlg.Message = text;
            end
        end

        function x_modus_geaendert(app, modus)
            app.x_modus = modus;
            if isempty(fieldnames(app.store)), return; end
            app.x = berechne_x_achse(app.store, app.x_modus, app.params);
            app.alle_tabs_aktualisieren();
        end

        function alle_tabs_aktualisieren(app)
            for i = 1:numel(app.tab_namen)
                app.tab_aktualisieren(app.tab_namen{i});
            end
        end

        function tab_aktualisieren(app, name)
            % Fahrerprofil-Tab arbeitet auf der Profildatei und laeuft auch
            % ohne geladenen Run; alle anderen brauchen den Store.
            if isempty(fieldnames(app.store)) && ~strcmp(name, 'fahrerprofile')
                return;
            end
            pl = app.baue_payload(name);
            h  = app.html_map(name);   % erst Handle holen (containers.Map),
            h.Data = pl;               % dann Dateivertrag setzen
        end

        function pl = baue_payload(app, name)
            fh = app.payload_map(name);         % eigene Function je Tab
            pl = fh(app.store, app.x, app.params, app.runden);
        end

        function html_event(app, tab_name, evt)
        %HTML_EVENT  Dispatcher fuer Events aus den HTML-Tabs.
            switch evt.HTMLEventName
                case 'runde_markiert'
                    % TODO evt.HTMLEventData -> app.runden ergaenzen + Tabs neu.
                case 'runde_gewaehlt'
                    % TODO gewaehlte Runde merken und Tabs darauf einschraenken.
                case 'fahrer_anlegen'
                    d = evt.HTMLEventData;
                    if isfield(d, 'name') && isfield(d, 'kennzahlen')
                        fahrerprofile_speichern(app.params.profil_datei, d.name, d.kennzahlen);
                        app.tab_aktualisieren('fahrerprofile');
                    end
                case 'profil_datei_waehlen'
                    [f, p] = uigetfile({'*.mat','Fahrerprofil-Datei'}, 'Profildatei wählen');
                    if ~isequal(f, 0)
                        app.params.profil_datei = fullfile(p, f);
                        app.tab_aktualisieren('fahrerprofile');
                    end
                otherwise
                    warning('DatenanalyseApp:Event', ...
                        'Unbehandeltes Event "%s" aus Tab "%s".', ...
                        evt.HTMLEventName, tab_name);
            end
        end
    end

    %% Private: Hilfen
    methods (Access = private, Static)
        function html = platzhalter_html(titel)
            % Minimaler dunkler Platzhalter ohne JS. Spaeter durch die echte
            % HTML-Datei des Tabs ersetzen (HTMLSource = Dateipfad).
            html = [ ...
                '<!doctype html><html><head><meta charset="utf-8">' ...
                '<style>html,body{margin:0;height:100%;display:flex;' ...
                'align-items:center;justify-content:center;background:#1e1e1e;' ...
                'color:#8a8a8a;font-family:sans-serif}</style></head>' ...
                '<body><div>', char(titel), ' — wartet auf HTML-Datei</div>' ...
                '</body></html>'];
        end
    end
end