% =========================================================================
%  payload_parameter  –  Dateivertrag fuer den Fahrzeug-Parameter-Tab
% -------------------------------------------------------------------------
%  Zweck         : Reicht den zentralen Parametersatz gruppiert und beschriftet
%                  ans Frontend (Label, Wert, Einheit, Pfad je Parameter). Das
%                  Frontend zeigt editierbare Felder; geaenderte Werte kommen
%                  ueber ein Event zurueck (Pfad + Wert).
%
%  Besonderheit  : Nutzt KEINE Envelope/x-Achse und laeuft ohne geladenen Run.
%                  Alle Listen sind CELL-Arrays (jsonencode-array-sicher).
%
%  Abhaengigkeiten: fahrzeug_parameter
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function pl = payload_parameter(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_PARAMETER  pl = PAYLOAD_PARAMETER(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand.
%     2026-07-15  Gruppiert + beschriftet, ohne Envelope, editierbar.

    if nargin < 3 || isempty(params) || ~isstruct(params)
        params = fahrzeug_parameter();
    end

    %% Layout-Definition: Gruppe -> {pfad, label, einheit}
    def = {
        'Fahrzeug & Massen', {
            'fahrzeug.masse_gesamt_kg',       'Gesamtmasse (inkl. Fahrer)', 'kg'
            'fahrzeug.radstand_mm',           'Radstand',                   'mm'
            'fahrzeug.spur_vorn_mm',          'Spur vorn',                  'mm'
            'fahrzeug.spur_hinten_mm',        'Spur hinten',                'mm'
            'fahrzeug.schwerpunkt_hoehe_mm',  'Schwerpunkthöhe',            'mm'
            'fahrzeug.gewichtsanteil_vorn',   'Gewichtsanteil vorn',        '0..1'
        }
        'Reifen & Lenkung', {
            'reifen.radius_dyn_mm',           'Dyn. Reifenradius',          'mm'
            'lenkung.uebersetzung',           'Lenkübersetzung (Rad→Reifen)','–'
        }
        'Antrieb', {
            'antrieb.uebersetzung',           'Getriebeübersetzung (Motor→Rad)','–'
            'antrieb.raeder_angetrieben',     'Angetriebene Räder',         '–'
            'antrieb.moment_max_motor_nm',    'Max. Moment je Motor',       'Nm'
        }
        'Bremse', {
            'bremse.moment_pro_bar_vorn_nm',  'Bremsmoment/Druck vorn',     'Nm/bar'
            'bremse.moment_pro_bar_hinten_nm','Bremsmoment/Druck hinten',   'Nm/bar'
        }
        'Fahrwerk', {
            'fahrwerk.motion_ratio_vorn',     'Motion Ratio vorn',          '–'
            'fahrwerk.motion_ratio_hinten',   'Motion Ratio hinten',        '–'
            'fahrwerk.federrate_vorn_n_mm',   'Federrate vorn',             'N/mm'
            'fahrwerk.federrate_hinten_n_mm', 'Federrate hinten',           'N/mm'
        }
        'Akku (HV)', {
            'akku.kapazitaet_kwh',            'Nennkapazität',              'kWh'
            'akku.zellen_reihe',              'Zellen in Reihe',            '–'
            'akku.zellen_parallel',           'Zellen parallel',            '–'
            'akku.nennspannung_v',            'Nennspannung',               'V'
        }
        'Log-Annahmen', {
            'log.geschw_in_ms',               'Faktor speed_can → m/s',     '–'
        }
    };

    %% Aufbau der Gruppen (Cell-Arrays -> array-sicher)
    gruppen = {};
    for g = 1:size(def, 1)
        felder = {};
        eintraege = def{g, 2};
        for r = 1:size(eintraege, 1)
            pfad = eintraege{r, 1};
            felder{end+1} = struct( ...                         %#ok<AGROW>
                'pfad',    pfad, ...
                'label',   eintraege{r, 2}, ...
                'einheit', eintraege{r, 3}, ...
                'wert',    feld_wert(params, pfad));
        end
        gruppen{end+1} = struct('label', def{g, 1}, 'felder', {felder}); %#ok<AGROW>
    end

    %% Ausgabe
    pl = struct();
    pl.meta = struct('tab', 'parameter');
    pl.panels = struct('gruppen', {gruppen}, ...
        'configs', {configs_namen(feld(params, 'parameterconfig_datei', ''))});
end

% =========================================================================
%  Functions
% =========================================================================

function w = feld_wert(s, pfad)
% Liest einen verschachtelten Wert ueber einen Punkt-Pfad (z.B. 'akku.zellen_reihe').
    teile = strsplit(pfad, '.');
    w = s;
    for i = 1:numel(teile)
        if isstruct(w) && isfield(w, teile{i})
            w = w.(teile{i});
        else
            w = NaN; return;
        end
    end
    if ~isnumeric(w) || ~isscalar(w), w = NaN; end
end

function namen = configs_namen(pfad)
% Namen der gespeicherten Parameter-Configs (fuer das Dropdown).
    cfgs = parameterconfigs_laden(pfad);
    namen = {};
    for i = 1:numel(cfgs), namen{end+1} = struct('name', cfgs(i).name); end %#ok<AGROW>
end

function v = feld(s, name, default)
    if isstruct(s) && isfield(s, name), v = s.(name); else, v = default; end
end
