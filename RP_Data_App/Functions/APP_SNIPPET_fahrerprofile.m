% =========================================================================
%  APP-SNIPPET  –  Fahrerprofile: Pfad setzen & neue Datei anlegen koennen
% -------------------------------------------------------------------------
%  Behebt "kann nicht speichern": es gab keinen gueltigen Pfad fuer eine NEUE
%  Profildatei (uigetfile oeffnet nur existierende Dateien) und der Default
%  war auskommentiert. NICHT als Datei ausfuehren – Bloecke uebernehmen.
% =========================================================================


% -------------------------------------------------------------------------
% 1) STARTUP: sinnvollen Default-Pfad setzen (nach fahrzeug_parameter()!)
% -------------------------------------------------------------------------
%   Wichtig: NACH  app.params = fahrzeug_parameter();  setzen, sonst wieder weg.
if ~isfield(app.params,'profil_datei') || isempty(app.params.profil_datei)
    app.params.profil_datei = fullfile(pwd, 'Functions', 'fahrerprofile.mat');
end
% (Absoluter Pfad -> das fruehere Lade-Problem im HTML entfaellt.
%  fahrerprofile_speichern legt Datei/Ordner bei Bedarf selbst an.)


% -------------------------------------------------------------------------
% 2) EVENT-HANDLER: 'profil_datei_waehlen' auf uiputfile umstellen
%    (erlaubt Auswaehlen UND Neuanlegen einer .mat)
% -------------------------------------------------------------------------
function Fahrerprofile_HTMLEventReceived(app, event)
    switch event.HTMLEventName
        case 'fahrer_anlegen'
            d = event.HTMLEventData;
            if isfield(d, 'name') && isfield(d, 'kennzahlen')
                try
                    fahrerprofile_speichern(app.params.profil_datei, d.name, d.kennzahlen);
                catch err
                    uialert(app.UIFigure, err.message, 'Fahrerprofile');
                end
            end

        case 'profil_datei_waehlen'
            start = app.params.profil_datei;
            if isempty(start), start = fullfile(pwd, 'fahrerprofile.mat'); end
            [f, p] = uiputfile({'*.mat','Fahrerprofil-Datei'}, 'Profildatei waehlen oder anlegen', start);
            figure(app.UIFigure);            % Fokus zurueck auf die App
            if ~isequal(f, 0)
                app.params.profil_datei = fullfile(p, f);
            end

        otherwise
            warning('DatenanalyseApp:Event', 'Unbehandeltes Event "%s".', event.HTMLEventName);
            return;
    end

    % Tab neu versorgen (Index 4 = Fahrerprofile)
    fh = app.payload_map(app.tab_namen{4});
    app.HTML_Handles(4).Data = fh(app.store, app.x, app.params, app.runden);
end


% -------------------------------------------------------------------------
% 3) DATEIEN AUF DEN PFAD LEGEN (Ordner "Functions")
% -------------------------------------------------------------------------
%   payload_fahrerprofile.m   (gehaertet)
%   fahrerprofile_laden.m     (robust)
%   fahrerprofile_speichern.m (robust)
%   -> ersetzen die bisherigen Versionen. Alte .mat mit abweichendem Format
%      werden von fahrerprofile_laden toleriert/normalisiert.
