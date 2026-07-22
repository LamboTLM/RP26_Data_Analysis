% =========================================================================
%  payload_hardware_software  –  Dateivertrag fuer den Hardware/Software-Tab
% -------------------------------------------------------------------------
%  Zweck         : Umgebaut auf einen gemeinsamen Cursor-Kontext:
%                  - Fahrt-Kontext (Speed, Gas, Bremse, Lenkung) via Envelope
%                  - Bool-Katalog aller Flags mit kompakten Transitions
%                    (start_wert + Umschaltpunkte), gruppierbar/durchsuchbar
%                  - Vorauswahl: SDC-Kette + alle getoggelten Signale
%                  - Fehler-Feed als Zeitlog: Sekunde ab Start, Uhrzeit
%                    (falls params.log_start gesetzt) und Distanz
%                  - SDC-Oeffnungen (ungeplant markiert), Rails (eFuse)
%
%  Kompaktheit   : Bools werden als Transitions gesendet (nicht als volle
%                  Sample-Arrays), damit auch hunderte Flags problemlos passen.
%                  Variabel lange Listen sind CELL-Arrays (jsonencode-array-sicher).
%
%  Abhaengigkeiten: payload_envelope, signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function pl = payload_hardware_software(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_HARDWARE_SOFTWARE  pl = PAYLOAD_HARDWARE_SOFTWARE(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand / gefuellt.
%     2026-07-15  Umbau: Fahrt-Kontext, Bool-Explorer (Transitions), Zeitlog.

    %% Konfiguration
    V_SDC_FAHRT = 3;   % m/s, ab hier gilt SDC-Oeffnen als "waehrend der Fahrt"

    %% Fahrt-Kontext -> Envelope
    kontext = { 'speed_can','apps1_can','pbrake_front_can','pbrake_rear_can', ...
                'steering_wheel_angle_can' };
    pl = payload_envelope(store, 'hardware_software', x, kontext);

    %% Distanz(t) einmal aus der Geschwindigkeit (fuer den Feed, x-Modus-unabhaengig)
    [t_d, d_d] = distanz_kumuliert(store, params);

    %% Bool-Katalog + Fehler-Feed (ein Durchlauf ueber alle Booleans)
    is_b = [store.is_bool];
    bool_namen = sort(unique({store(is_b).name}));

    bools = {}; feed = {}; getoggelt_namen = {};
    for i = 1:numel(bool_namen)
        nm  = bool_namen{i};
        sig = signal_holen(store, nm);
        toggled = strcmp(sig.status, 'gueltig');

        if toggled
            y = res_bool(sig, x);
            [start_wert, trans] = transitions_von(y, pl.x);
            getoggelt_namen{end+1} = nm; %#ok<AGROW>
        else
            start_wert = erste_endliche(sig.value);
            trans = {};
        end
        bools{end+1} = struct('name', nm, 'subsystem', sig.subsystem, ...
            'status', sig.status, 'toggled', toggled, ...
            'start_wert', start_wert, 'transitions', {trans}); %#ok<AGROW>

        % Fehler-/Warn-Feed
        if (contains(nm,'_e_') || contains(nm,'_w_')) && ist_true(sig)
            te = erste_true_zeit(sig);
            feed{end+1} = struct('name', nm, ...
                'schwere', wenn(contains(nm,'_e_'),'fehler','warnung'), ...
                't_s',     te, ...
                'uhrzeit', uhrzeit_str(params, te), ...
                'distanz', distanz_bei(t_d, d_d, te), ...
                'x',       x_pos(x, te)); %#ok<AGROW>
        end
    end
    pl.panels.bools = bools;
    pl.panels.fehler_feed = struct('eintraege', {sortiere_nach_feld(feed, 't_s')});

    %% Vorauswahl: SDC-Kette (falls vorhanden) + getoggelte Signale
    sdc_kette = { 'SDC_AS_closed_b_can','sdc_res_b_can','SDC_Latch_Ready_b_can', ...
                  'DASH_SDC_Killswitch_can','bots_b_can','inertia_b_can' };
    vorauswahl = unique([ vorhandene(store, sdc_kette), getoggelt_namen ], 'stable');
    pl.panels.vorauswahl = vorauswahl;

    %% Thematische Presets (nur vorhandene Bool-Signale)
    pl.panels.presets = presets_bauen(bool_namen);

    %% Gespeicherte Signal-Configs (aus Datei)
    pl.panels.configs = signalconfigs_laden(feld(params, 'signalconfig_datei', ''));

    %% SDC-Oeffnungen (ungeplant markiert)
    pl.panels.sdc = sdc_analyse(store, x, t_d, d_d, params, V_SDC_FAHRT);

    %% Rails: eFuse-Stroeme + Trips
    [stroeme, trips] = rails_analyse(store, x, t_d, d_d, params);
    pl.panels.rails = struct('stroeme', {stroeme}, 'trips', {trips});
end

% =========================================================================
%  Functions
% =========================================================================

function y = res_bool(sig, x)
    [tu, iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), 'previous', NaN);
end
function y = res_analog(sig, x)
    [tu, iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), 'linear', NaN);
end

function [start_wert, trans] = transitions_von(y, xw)
% Kompakte Darstellung eines Bool-Verlaufs: Startwert + Umschaltpunkte.
    trans = {};
    gilt = ~isnan(y);
    if ~any(gilt), start_wert = NaN; return; end
    i0 = find(gilt, 1);
    start_wert = y(i0);
    prev = start_wert;
    for i = i0+1:numel(y)
        if ~isnan(y(i)) && y(i) ~= prev
            trans{end+1} = struct('x', xw(i), 'wert', y(i)); %#ok<AGROW>
            prev = y(i);
        end
    end
end

function [t_d, d_d] = distanz_kumuliert(store, params)
% Kumulierte Strecke aus der Geschwindigkeit (m ueber der Zeit).
    t_d = []; d_d = [];
    v = signal_holen(store, 'speed_can');
    if ~strcmp(v.status, 'gueltig'), return; end
    [tu, iu] = unique(v.t(:));
    vv = max(v.value(iu) * params.log.geschw_in_ms, 0);   % m/s
    t_d = tu; d_d = cumtrapz(tu, vv);
end
function d = distanz_bei(t_d, d_d, t)
    if isempty(t_d) || isempty(t) || isnan(t), d = NaN; return; end
    d = interp1(t_d, d_d, t, 'linear', NaN);
end

function xw = x_pos(x, t)
    if isempty(t) || isnan(t), xw = NaN; return; end
    xw = interp1(x.t_ref(:), x.werte(:), t, 'linear', NaN);
end

function s = uhrzeit_str(params, t_s)
% Absolute Uhrzeit, falls params.log_start (datetime) gesetzt ist.
    s = '';
    if isfield(params, 'log_start') && ~isempty(params.log_start)
        try
            if ~isnat(params.log_start)
                s = char(string(params.log_start + seconds(t_s), 'HH:mm:ss.SSS'));
            end
        catch %#ok<CTCH>
        end
    end
end

function w = erste_endliche(v)
    v = v(isfinite(v)); if isempty(v), w = NaN; else, w = v(1); end
end
function tf = ist_true(sig)
    tf = ~isempty(sig.value) && any(sig.value > 0.5);
end
function t = erste_true_zeit(sig)
    idx = find(sig.value > 0.5, 1);
    if isempty(idx), t = NaN; else, t = sig.t(idx); end
end
function out = wenn(bed, a, b)
    if bed, out = a; else, out = b; end
end
function namen = vorhandene(store, kandidaten)
% Teilmenge der Kandidaten, die im Store existieren.
    namen = {};
    for i = 1:numel(kandidaten)
        s = signal_holen(store, kandidaten{i});
        if ~strcmp(s.status, 'fehlt'), namen{end+1} = kandidaten{i}; end %#ok<AGROW>
    end
end
function c = sortiere_nach_feld(feed, feld)
    if isempty(feed), c = feed; return; end
    xs = cellfun(@(e) e.(feld), feed);
    [~, ord] = sort(xs);
    c = feed(ord);
end

function sdc = sdc_analyse(store, x, t_d, d_d, params, v_fahrt)
% SDC-Oeffnungen (geschlossen 1 -> offen 0), ungeplant wenn speed > v_fahrt.
    kandidaten = {'SDC_AS_closed_b_can','sdc_res_b_can','SDC_Latch_Ready_b_can'};
    oeffnungen = {}; sdc_sig = [];
    for i = 1:numel(kandidaten)
        s = signal_holen(store, kandidaten{i});
        if strcmp(s.status, 'gueltig'), sdc_sig = s; break; end
    end
    if isempty(sdc_sig)
        sdc = struct('oeffnungen', {oeffnungen}, 'hat_signal', false); return;
    end
    v = signal_holen(store, 'speed_can');
    zu  = sdc_sig.value > 0.5;
    auf = find(diff(zu) < 0) + 1;
    for k = 1:numel(auf)
        t_open = sdc_sig.t(auf(k));
        ungeplant = false;
        if strcmp(v.status, 'gueltig')
            vv = interp1(v.t(:), v.value(:), t_open, 'linear', NaN) * params.log.geschw_in_ms;
            ungeplant = isfinite(vv) && vv > v_fahrt;
        end
        oeffnungen{end+1} = struct('t_s', t_open, 'x', x_pos(x, t_open), ...
            'distanz', distanz_bei(t_d, d_d, t_open), ...
            'uhrzeit', uhrzeit_str(params, t_open), 'ungeplant', ungeplant); %#ok<AGROW>
    end
    sdc = struct('oeffnungen', {oeffnungen}, 'hat_signal', true);
end

function [stroeme, trips] = rails_analyse(store, x, t_d, d_d, params)
    stroeme = {}; trips = {};
    alle = unique({store.name});
    for i = 1:numel(alle)
        nm = alle{i};
        if endsWith(nm, 'IMON_can')
            s = signal_holen(store, nm);
            if strcmp(s.status, 'gueltig')
                stroeme{end+1} = struct('name', nm, 'y', zeile(res_analog(s, x))); %#ok<AGROW>
            end
        elseif contains(nm, 'eFuse') && contains(nm, '_e_b')
            s = signal_holen(store, nm);
            if ist_true(s)
                te = erste_true_zeit(s);
                trips{end+1} = struct('name', nm, 't_s', te, ...
                    'x', x_pos(x, te), 'distanz', distanz_bei(t_d, d_d, te), ...
                    'uhrzeit', uhrzeit_str(params, te)); %#ok<AGROW>
            end
        end
    end
end

function presets = presets_bauen(namen)
% Thematische Presets: je Thema ein Praedikat; nur vorhandene Signale werden
% aufgenommen, leere Presets fallen weg.
    def = {
        'SDC & Shutdown',    @(n) contains(n,'SDC') || any(strcmp(n,{'bots_b_can','inertia_b_can','sdc_res_b_can'})) || startsWith(n,'sc_') || contains(n,'interlock')
        'Autonomes System',  @(n) startsWith(n,'AS') || contains(n,'DVSC') || contains(n,'DV_') || contains(n,'AMI') || contains(n,'DL_AS') || startsWith(n,'EBS') || startsWith(n,'ACE_') || startsWith(n,'assi')
        'Inverter-Faults',   @(n) startsWith(n,'unitek_') && contains(n,'_b_can')
        'AMS / Akku',        @(n) (startsWith(n,'ams_') && (contains(n,'warning')||contains(n,'error')||contains(n,'occured'))) || startsWith(n,'imd_') || startsWith(n,'ts_') || contains(n,'precharge') || startsWith(n,'air_') || startsWith(n,'tsal') || startsWith(n,'battery_')
        'eFuse-Trips',       @(n) contains(n,'eFuse') && contains(n,'_e_b')
        'Fahrer-Buttons',    @(n) any(strcmp(n,{'start_btn_b_can','r2ds_enable_can','drs_toggle_b_can','bots_b_can','sw_bspd_b_can','Reset_btn_vcu_b_can','ASR_start_btn_b_can'}))
        'Antriebs-Strategie',@(n) startsWith(n,'drive_') && contains(n,'_b')
    };
    presets = {};
    for i = 1:size(def,1)
        sig = namen(cellfun(def{i,2}, namen));
        if ~isempty(sig)
            presets{end+1} = struct('name', def{i,1}, 'signale', {sig(:).'}); %#ok<AGROW>
        end
    end
end

function v = feld(s, name, default)
    if isstruct(s) && isfield(s, name), v = s.(name); else, v = default; end
end

function z = zeile(v)
    z = v(:).';
end
