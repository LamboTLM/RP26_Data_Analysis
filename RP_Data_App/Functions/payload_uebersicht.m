% =========================================================================
%  payload_uebersicht  –  Dateivertrag fuer den Uebersichts-Tab
% -------------------------------------------------------------------------
%  Zweck         : Landeseite. Liefert das Spine-Signal (Geschwindigkeit) zum
%                  manuellen Runden-Markieren, die Kennzahlen je Run, die feine
%                  Datenhealth-Matrix pro Schluesselsignal, die bereits
%                  markierten Runden (auf die aktuelle x-Achse umgerechnet) und
%                  eine kurze Triage (Fehleranzahl, ungeplantes SDC-Oeffnen).
%
%  Abhaengigkeiten: payload_envelope, signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function pl = payload_uebersicht(store, x, params, runden)
%PAYLOAD_UEBERSICHT  pl = PAYLOAD_UEBERSICHT(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand (Kennzahlen real, Triage Stub).
%     2026-07-15  Umbau: Spine + Runden-Markierung, Health-Matrix, Triage real.

    if nargin < 4, runden = struct('name',{},'t_start',{},'t_ende',{},'fahrer',{}); end

    %% Schluesselsignale fuer die Datenhealth-Matrix (fein, pro Signal)
    schluessel = { ...
        'speed_can','INS_acc_x_can','INS_acc_y_can','INS_ang_vel_z_can','steering_wheel_angle_can', ...
        'pbrake_front_can','pbrake_rear_can', ...
        'unitek_fl_torque_motor_ist_can','tqTarget_can', ...
        'ams_overall_voltage_can','IVT_Result_I_can','ams_cell_min_voltage_can','ams_cell_max_temp_can', ...
        'rocker_fl_can','rocker_fr_can','rocker_rl_can','rocker_rr_can', ...
        'VCU_Statemachine_can','apps1_can','driver_id_can','tqv_status_tqv_enabled_b_can' };
    pl = payload_envelope(store, 'uebersicht', x, schluessel);

    %% Spine-Signal (Geschwindigkeit) fuers Markieren
    spine = signal_holen(store, 'speed_can');
    if strcmp(spine.status, 'gueltig')
        pl.panels.spine = struct('name','speed_can','y', zeile(res(store,x,'speed_can')));
    else
        pl.panels.spine = struct('name','', 'y', []);
    end

    %% Datenhealth-Matrix (mit Subsystem zum Gruppieren)
    matrix = {};
    for i = 1:numel(schluessel)
        sig = signal_holen(store, schluessel{i});
        matrix{end+1} = struct('name', schluessel{i}, ...
            'subsystem', sig.subsystem, 'status', sig.status); %#ok<AGROW>
    end
    pl.panels.health_matrix = matrix;

    %% Kennzahlen je Run
    k = struct();
    k.dauer_s          = kennzahl_max_zeit(store);
    k.strecke_m        = strecke_gesamt(store, x, params);
    k.runden_anzahl    = numel(runden);
    k.fahrer           = kennzahl_fahrer(store);
    k.speed_max        = kennzahl_max(store, 'speed_can');
    k.ax_max           = kennzahl_max_abs(store, 'INS_acc_x_can');
    k.ay_max           = kennzahl_max_abs(store, 'INS_acc_y_can');
    k.zellspannung_min = kennzahl_min(store, 'ams_cell_min_voltage_can');
    k.temp_max         = kennzahl_max(store, 'ams_cell_max_temp_can');
    ae                 = akku_energie(store);
    k.energie_wh       = ae.wh;
    k.leistung_max_kw  = ae.pmax_kw;
    pl.panels.kennzahlen = k;

    %% Bereits markierte Runden -> auf aktuelle x-Achse umrechnen
    r = {};
    for i = 1:numel(runden)
        r{end+1} = struct('name', runden(i).name, ...
            'x_start', x_pos(x, runden(i).t_start), ...
            'x_ende',  x_pos(x, runden(i).t_ende), ...
            'fahrer',  hol_feld(runden(i), 'fahrer', '')); %#ok<AGROW>
    end
    pl.panels.runden = r;

    %% Triage: auffaellige Ereignisse
    pl.panels.triage = triage_bauen(store);
end

% =========================================================================
%  Functions
% =========================================================================

function y = res(store, x, name)
    sig = signal_holen(store, name);
    if strcmp(sig.status,'fehlt') || isempty(sig.t), y = nan(size(x.t_ref(:))); return; end
    [tu,iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), 'linear', NaN);
end

function xw = x_pos(x, t)
    if isempty(t) || isnan(t), xw = NaN; return; end
    xw = interp1(x.t_ref(:), x.werte(:), t, 'linear', NaN);
end

function v = kennzahl_max_zeit(store)
    v = 0;
    for i = 1:numel(store)
        if ~isempty(store(i).t), v = max(v, store(i).t(end)); end
    end
end

function s = strecke_gesamt(store, x, params)
% Gesamtstrecke: im Distanzmodus direkt aus x, sonst aus Geschwindigkeitsintegral.
    if strcmp(x.modus, 'distanz') && ~isempty(x.werte)
        s = x.werte(end); return;
    end
    v = signal_holen(store, 'speed_can');
    if ~strcmp(v.status, 'gueltig'), s = NaN; return; end
    [tu, iu] = unique(v.t(:));
    vv = max(v.value(iu) * params.log.geschw_in_ms, 0);
    d  = cumtrapz(tu, vv);
    s  = d(end);
end

function name = kennzahl_fahrer(store)
    sig = signal_holen(store, 'driver_id_can');
    if strcmp(sig.status,'fehlt') || isempty(sig.value), name = 'unbekannt';
    else, ids = sig.value(isfinite(sig.value)); name = sprintf('ID %g', mode(ids)); end
end
function v = kennzahl_max(store, name), v = wert(store, name, @max); end
function v = kennzahl_min(store, name), v = wert(store, name, @min); end
function v = kennzahl_max_abs(store, name)
    sig = signal_holen(store, name);
    if tauglich(sig), v = max(abs(sig.value(isfinite(sig.value)))); else, v = NaN; end
end
function v = wert(store, name, fn)
    sig = signal_holen(store, name);
    if tauglich(sig), v = fn(sig.value(isfinite(sig.value))); else, v = NaN; end
end
function tf = tauglich(sig), tf = strcmp(sig.status,'gueltig') && any(isfinite(sig.value)); end

function t = triage_bauen(store)
% Zaehlt Fehler-Flags, die true wurden, und prueft ungeplantes SDC-Oeffnen.
    is_b = [store.is_bool];
    namen = unique({store(is_b).name});
    anzahl_fehler = 0;
    for i = 1:numel(namen)
        if contains(namen{i}, '_e_')
            s = signal_holen(store, namen{i});
            if ~isempty(s.value) && any(s.value > 0.5), anzahl_fehler = anzahl_fehler + 1; end
        end
    end
    % Ungeplantes SDC-Oeffnen (grobe Pruefung)
    sdc_ungeplant = false;
    for kand = {'SDC_AS_closed_b_can','sdc_res_b_can','SDC_Latch_Ready_b_can'}
        s = signal_holen(store, kand{1});
        if strcmp(s.status,'gueltig')
            v = signal_holen(store, 'speed_can');
            auf = find(diff(s.value > 0.5) < 0) + 1;
            for k = 1:numel(auf)
                if strcmp(v.status,'gueltig')
                    vv = interp1(v.t(:), v.value(:), s.t(auf(k)), 'linear', NaN);
                    if isfinite(vv) && vv > 3, sdc_ungeplant = true; end
                end
            end
            break;
        end
    end
    t = struct('anzahl_fehler', anzahl_fehler, 'sdc_ungeplant', sdc_ungeplant);
end

function ae = akku_energie(store)
% Energiedurchsatz [Wh] und Spitzenleistung [kW] aus Pack-Spannung x Strom.
    ae = struct('wh', NaN, 'pmax_kw', NaN);
    V = signal_holen(store, 'ams_overall_voltage_can');
    I = signal_holen(store, 'IVT_Result_I_can');
    if ~strcmp(V.status,'gueltig') || ~strcmp(I.status,'gueltig'), return; end
    [tI, iu] = unique(I.t(:)); Ii = I.value(iu);
    [tV, iv] = unique(V.t(:)); Vv = V.value(iv);
    Vg = interp1(tV, Vv, tI, 'linear', NaN);
    p  = Vg .* Ii;                      % W (positiv = Entladung bei I>0)
    if any(isfinite(p))
        pg = p; pg(~isfinite(pg)) = 0;
        ae.wh      = trapz(tI, pg) / 3600;
        ae.pmax_kw = max(abs(p(isfinite(p)))) / 1000;
    end
end

function v = hol_feld(s, name, default)
    if isfield(s, name) && ~isempty(s.(name)), v = s.(name); else, v = default; end
end

function z = zeile(v), z = v(:).'; end
