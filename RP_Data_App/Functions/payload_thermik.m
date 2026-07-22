% =========================================================================
%  payload_thermik  –  Dateivertrag fuer den Thermik-&-Leistungs-Tab
% -------------------------------------------------------------------------
%  Zweck         : Fahrzeugweite Temperaturueberwachung UND Leistung/Verluste.
%                  Findet automatisch ALLE echten Temperatursensoren im Run
%                  (Zellen, Motoren, Inverter/IGBT, LV-Batterie, Elektronik, …),
%                  gruppiert sie, bewertet sie mit komponenten-spezifischen
%                  Grenzwerten und zeigt zusaetzlich thermische Derating-/
%                  Warn-Flags. Leistung: elektrisch (U*I) und mechanisch
%                  (Moment*Rotordrehzahl je Ecke) -> Verluste + Wirkungsgrad.
%
%  Einheiten     : UNIT-BEWUSST. ams_overall_voltage [mV], IVT_Result_I [mA],
%                  speed [kph], tqv_rot_spd [rpm], Temperaturen [C], Moment [Nm].
%                  res_si() rechnet anhand der Signal-Einheit auf SI um.
%
%  Auto-Discovery: Kanaele mit 'temp' im Namen, OHNE Flags (_b_can/_e_/error/
%                  warning/occured/derating/overtemp/undertemp/critical) und
%                  OHNE Summen (avg/max/min). Tote Sensoren (max<=0) fallen raus.
%
%  Abhaengigkeiten: payload_envelope, signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-21
% =========================================================================

function pl = payload_thermik(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_THERMIK  pl = PAYLOAD_THERMIK(store, x, params, runden)
%   Changelog:
%     2026-07-18  Erststand (Zellen aggregiert, Getriebe-Schaetzung).
%     2026-07-21  Umbau nach echter MF4: alle Sensoren einzeln + gruppiert,
%                 unit-bewusst (res_si), echte Rotordrehzahl fuer P_mech,
%                 Flags gefiltert + Derating-Panel.

    %% Konfiguration
    T_HM         = 320;    % Spalten der Heatmap (Zeit dezimiert)
    MIN_DAUER_S  = 0.3;    % s, kurze Uebertemp-Ereignisse verwerfen
    MAX_LUECKE_S = 0.2;    % s, kleine Luecken schliessen
    MAX_KANAELE  = 200;

    % Grenzwerte [warn krit] °C je Typ (bei RP26e bestaetigen)
    SW = struct('zelle',[55 60], 'motor',[120 150], 'igbt',[100 130], ...
                'inverter',[90 120], 'elektronik',[70 90], 'kuehl',[55 70], 'default',[80 100]);

    % Fallback-Antriebsparameter (nur falls keine Rotordrehzahl vorhanden)
    r_rad  = param_wert(params, {'reifen.radius','reifen.r_dyn','r_rad'}, 0.2286);   % m
    i_getr = param_wert(params, {'antrieb.uebersetzung','getriebe.uebersetzung','i_getriebe'}, 1.0); % -

    pack = { 'ams_cell_max_temp_can','ams_cell_avg_temp_can','battery_temp_max_can', ...
             'ams_overall_voltage_can','IVT_Result_I_can','speed_can' };
    pl = payload_envelope(store, 'thermik', x, pack);

    dt_s = median(diff(x.t_ref(:)), 'omitnan');
    if ~isfinite(dt_s) || dt_s <= 0, dt_s = 0.01; end

    %% ---- Temperatursensoren automatisch finden --------------------------
    alle = unique({store.name});
    kandidaten = alle(cellfun(@(n) ist_temp_sensor(n), alle));

    kanaele = {};
    for i = 1:min(numel(kandidaten), MAX_KANAELE)
        nm = kandidaten{i};
        s  = signal_holen(store, nm);
        if strcmp(s.status, 'fehlt'), continue; end
        y = res_si(store, x, nm);
        fin = y(isfinite(y));
        if isempty(fin) || max(fin) <= 0, continue; end     % tote/leere Sensoren raus
        typ = typ_von(nm); gw = grenzwert(SW, typ);
        kanaele{end+1} = struct('name',nm,'label',label_von(nm),'gruppe',gruppe_von(nm), ...
            'typ',typ,'warn',gw(1),'krit',gw(2),'y',zeile(y),'t_max',max(fin)); %#ok<AGROW>
    end

    if isempty(kanaele)
        pl.panels.status = 'leer';
        pl.panels.hinweis = 'Keine Temperatursensoren im Run gefunden.';
        pl.panels.leistung = leistung_bauen(store, x, r_rad, i_getr);
        pl.panels.flags = thermo_flags(store, x);
        return;
    end
    pl.panels.status = 'ok';

    %% ---- Nach Gruppe sortieren ------------------------------------------
    grp = cellfun(@(k) k.gruppe, kanaele, 'UniformOutput', false);
    [~, go] = sort(grp);
    kanaele = kanaele(go);
    n = numel(kanaele);

    %% ---- Heatmap (Anteil vom Grenzwert), Kanal-Liste, Serien ------------
    cols = spalten_index(numel(x.werte), T_HM);
    Mn = nan(n, numel(cols));
    labels = cell(1,n); gruppen = cell(1,n); t_max = nan(1,n); kritl = false(1,n);
    warn_any = false(1, numel(x.werte)); krit_any = warn_any;
    kanal_liste = {}; serien = {};
    for c = 1:n
        k = kanaele{c}; yv = k.y;
        labels{c} = k.label; gruppen{c} = k.gruppe; t_max(c) = k.t_max; kritl(c) = k.t_max >= k.krit;
        Mn(c,:) = yv(cols) / max(k.krit, eps);
        warn_any = warn_any | (yv >= k.warn);
        krit_any = krit_any | (yv >= k.krit);
        kanal_liste{end+1} = struct('index',c,'name',k.name,'label',k.label,'gruppe',k.gruppe, ...
            'typ',k.typ,'warn',k.warn,'krit',k.krit,'t_max',runde(k.t_max,1),'kritisch',logical(kritl(c))); %#ok<AGROW>
        serien{end+1} = yv; %#ok<AGROW>
    end
    pl.panels.heatmap = struct('index', zeile(1:n), 'label', {labels}, 'gruppe', {gruppen}, ...
        't', zeile(x.werte(cols)), 'matrix', {matrix_rows(Mn)});
    pl.panels.kanaele = kanal_liste;
    pl.panels.serien  = serien;

    %% ---- Ranking --------------------------------------------------------
    [~, ord] = sort(t_max, 'descend');
    rang = {};
    for j = 1:min(24, n)
        c = ord(j); if ~isfinite(t_max(c)), break; end
        rang{end+1} = kanal_liste{c}; %#ok<AGROW>
    end
    pl.panels.ranking = rang;

    %% ---- Gruppen-Uebersicht ---------------------------------------------
    gnamen = unique(gruppen, 'stable');
    gl = {};
    for g = 1:numel(gnamen)
        sel = strcmp(gruppen, gnamen{g}); ci = find(sel);
        [~, im] = max(t_max(ci)); hot = ci(im);
        gl{end+1} = struct('name',gnamen{g},'anzahl',sum(sel),'max',runde(max(t_max(sel)),1), ...
            'hotspot_label',labels{hot},'hotspot_index',hot,'kritisch',any(kritl(sel))); %#ok<AGROW>
    end
    pl.panels.gruppen = gl;

    %% ---- Uebertemperatur-Bereiche + thermische Flags --------------------
    pl.panels.ereignisse = struct( ...
        'uebertemp_warn', {maske_zu_bereichen(warn_any, pl.x, dt_s, MIN_DAUER_S, MAX_LUECKE_S)}, ...
        'uebertemp_krit', {maske_zu_bereichen(krit_any, pl.x, dt_s, MIN_DAUER_S, MAX_LUECKE_S)} );
    pl.panels.flags = thermo_flags(store, x);

    %% ---- Leistung & Verluste --------------------------------------------
    pl.panels.leistung = leistung_bauen(store, x, r_rad, i_getr);

    %% ---- KPI ------------------------------------------------------------
    [hot_t, hot_c] = max(t_max); L = pl.panels.leistung;
    pl.panels.kpi = struct('max_temp',runde(hot_t,1),'hotspot_label',labels{hot_c}, ...
        'n_krit',sum(kritl),'n_kanaele',n,'n_gruppen',numel(gnamen), ...
        'p_el_max',L.p_el_max,'loss_mean',L.loss_mean,'wirkungsgrad',L.wirkungsgrad);
end

% =========================================================================
%  Functions
% =========================================================================

function tf = ist_temp_sensor(n)
    nl = lower(n);
    if ~contains(nl, 'temp'), tf = false; return; end
    if ~isempty(regexp(nl, '_b_can|_e_|error|warning|occured|derating|overtemp|undertemp|critical', 'once')), tf = false; return; end
    if ~isempty(regexp(nl, '_avg_|_max_|_min_|temp_avg|temp_max|temp_min', 'once')), tf = false; return; end
    tf = true;
end

function typ = typ_von(name)
    nl = lower(name);
    if     contains(nl,'igbt'),   typ = 'igbt';
    elseif contains(nl,'motor'),  typ = 'motor';
    elseif ~isempty(regexp(nl,'ams_cell_temp\d+','once')) || contains(nl,'battery_cell_temp') || (contains(nl,'cell')&&contains(nl,'temp')), typ = 'zelle';
    elseif contains(nl,'bms')||contains(nl,'pcb')||contains(nl,'balancing')||contains(nl,'slave'), typ = 'elektronik';
    elseif contains(nl,'ewp')||contains(nl,'coolant')||contains(nl,'kuehl')||contains(nl,'wasser'), typ = 'kuehl';
    elseif contains(nl,'inverter')||contains(nl,'unitek'), typ = 'inverter';
    else,  typ = 'default';
    end
end

function gw = grenzwert(SW, typ)
    if isfield(SW, typ), gw = SW.(typ); else, gw = SW.default; end
end

function grp = gruppe_von(name)
    nl = lower(name);
    if     ~isempty(regexp(nl,'ams_cell_temp\d+','once')), grp = 'Zellen (AMS)';
    elseif contains(nl,'balancing'),                       grp = 'AMS Balancing';
    elseif contains(nl,'pcb'),                             grp = 'AMS Elektronik';
    elseif contains(nl,'battery_cell_temp'),               grp = 'LV-Batterie Zellen';
    elseif contains(nl,'battery')&&contains(nl,'temp'),    grp = 'LV-Batterie';
    elseif contains(nl,'igbt'),                            grp = 'Inverter (IGBT)';
    elseif contains(nl,'motor'),                           grp = 'Motoren';
    elseif contains(nl,'ewp')&&contains(nl,'inv'),         grp = 'Kuehlung Inverter';
    elseif contains(nl,'ewp')&&contains(nl,'mot'),         grp = 'Kuehlung Motor';
    else,  grp = 'Sonstige';
    end
end

function lab = label_von(name)
    nl = lower(name);
    tok = regexp(nl, 'ams_cell_temp(\d+)', 'tokens', 'once');
    if ~isempty(tok), lab = ['Zelle ' tok{1}]; return; end
    tok = regexp(nl, 'battery_cell_temp_(\d+)', 'tokens', 'once');
    if ~isempty(tok), lab = ['LV-Zelle ' tok{1}]; return; end
    ec = regexp(nl, 'unitek_(fl|fr|rl|rr)_(motor|igbt)_temp', 'tokens', 'once');
    if ~isempty(ec), lab = [upper(ec{1}) ' ' upper(ec{2})]; return; end
    if contains(nl,'ams_pcb'),     lab = 'AMS PCB'; return; end
    if contains(nl,'battery_bms'), lab = 'LV BMS';  return; end
    lab = strrep(name, '_can', '');
end

function L = leistung_bauen(store, x, r_rad, i_getr)
    U = res_si(store, x, 'ams_overall_voltage_can');   % V
    I = res_si(store, x, 'IVT_Result_I_can');          % A
    p_el = U .* I;                                     % W (pos = Entladung)

    ecken = {'fl','fr','rl','rr'};
    p_mech = zeros(size(x.t_ref(:)));
    p_ecke = struct(); hat_rot = false;
    for i = 1:numel(ecken)
        Ti = res_si(store, x, sprintf('unitek_%s_torque_motor_ist_can', ecken{i})); Ti(~isfinite(Ti)) = 0;
        wi = res_si(store, x, sprintf('tqv_rot_spd_%s_can', ecken{i}));   % rpm -> rad/s
        if any(isfinite(wi)), hat_rot = true; else, wi = zeros(size(Ti)); end
        wi(~isfinite(wi)) = 0;
        pc = Ti .* wi;
        p_mech = p_mech + pc;
        p_ecke.(ecken{i}) = zeile(pc / 1000);          % kW
    end
    if ~hat_rot
        v = res_si(store, x, 'speed_can');
        omega = (v ./ max(r_rad,eps)) * i_getr;
        Tsum = zeros(size(x.t_ref(:)));
        for i = 1:numel(ecken)
            Ti = res_si(store, x, sprintf('unitek_%s_torque_motor_ist_can', ecken{i})); Ti(~isfinite(Ti)) = 0;
            Tsum = Tsum + Ti;
        end
        p_mech = Tsum .* omega;
        quelle = sprintf('Fallback v x i=%.2f / r=%.3f m', i_getr, r_rad);
    else
        quelle = 'Moment x Rotordrehzahl (tqv_rot_spd, je Ecke)';
    end
    p_loss = p_el - p_mech;

    gate = (p_el > 500) & isfinite(p_mech);
    eta  = 100 * sum(min(max(p_mech(gate),0), p_el(gate)),'omitnan') / max(sum(p_el(gate),'omitnan'), eps);

    t = x.t_ref(:);
    L = struct('p_el', zeile(p_el/1000), 'p_mech', zeile(p_mech/1000), 'p_loss', zeile(p_loss/1000), ...
        'p_ecke', p_ecke, ...
        'p_el_max', runde(max(p_el,[],'omitnan')/1000,1), 'p_mech_max', runde(max(p_mech,[],'omitnan')/1000,1), ...
        'loss_mean', runde(mean(p_loss(gate),'omitnan')/1000,2), ...
        'e_el_wh', runde(trapz_nan(t,p_el)/3600,0), 'e_mech_wh', runde(trapz_nan(t,p_mech)/3600,0), ...
        'e_loss_wh', runde(trapz_nan(t,p_loss)/3600,0), 'wirkungsgrad', runde(eta,0), ...
        'omega_quelle', quelle);
end

function flags = thermo_flags(store, x)
    flags = {};
    alle = unique({store.name});
    ist = cellfun(@(n) ~isempty(regexp(lower(n), ...
        'derating.*temp|temp.*derating|overtemp|(temp.*(error|warning|critical))', 'once')), alle);
    kand = alle(ist);
    for i = 1:min(numel(kand), 24)
        s = signal_holen(store, kand{i});
        if strcmp(s.status,'fehlt') || isempty(s.value), continue; end
        aktiv = any(s.value > 0.5);
        xe = NaN;
        if aktiv
            te = s.t(find(s.value > 0.5, 1));
            xe = interp1(x.t_ref(:), x.werte(:), te, 'linear', NaN);
        end
        flags{end+1} = struct('label', strrep(kand{i},'_can',''), 'aktiv', logical(aktiv), 'x', xe); %#ok<AGROW>
    end
end

function y = res_si(store, x, name)
    sig = signal_holen(store, name);
    if strcmp(sig.status,'fehlt') || isempty(sig.t), y = nan(size(x.t_ref(:))); return; end
    [tu,iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), 'linear', NaN);
    y = y * si_faktor(sig);
end

function f = si_faktor(sig)
    f = 1; u = einheit(sig);
    switch u
        case {'mv','ma'},            f = 1e-3;
        case {'uv','µv','ua','µa'},  f = 1e-6;
        case {'kv','ka'},            f = 1e3;
        case {'kph','km/h'},         f = 1/3.6;
        case 'mph',                  f = 0.44704;
        case 'rpm',                  f = pi/30;      % -> rad/s
    end
end

function u = einheit(sig)
    u = '';
    if isfield(sig,'unit') && ~isempty(sig.unit), u = lower(strtrim(char(sig.unit))); end
end

function e = trapz_nan(t, p), p(~isfinite(p)) = 0; if numel(t)<2, e = NaN; else, e = trapz(t,p); end, end

function cols = spalten_index(nx, ziel)
    if nx <= ziel, cols = 1:nx; else, cols = round(linspace(1, nx, ziel)); end
end

function C = matrix_rows(Mx)
    C = cell(1, size(Mx,1));
    for r = 1:size(Mx,1), C{r} = zeile(Mx(r,:)); end
end

function b = maske_zu_bereichen(mask, xv, dt_s, min_dauer_s, max_luecke_s)
    b = {};
    mask = mask(:); mask(isnan(mask)) = 0; mask = logical(mask);
    if ~any(mask), return; end
    n_gap = max(0, round(max_luecke_s / max(dt_s, eps)));
    n_min = max(1, round(min_dauer_s / max(dt_s, eps)));
    if n_gap > 0
        aus = find(diff([1; mask; 1]) == -1); ein = find(diff([1; mask; 1]) == 1) - 1;
        for k = 1:numel(aus)
            i0 = aus(k); i1 = ein(k);
            if i0 > 1 && i1 <= numel(mask) && (i1-i0+1) <= n_gap, mask(i0:i1) = true; end
        end
    end
    d = diff([0; mask; 0]); starts = find(d==1); enden = find(d==-1)-1;
    for k = 1:numel(starts)
        if (enden(k)-starts(k)+1) >= n_min, b{end+1} = [xv(starts(k)), xv(enden(k))]; end %#ok<AGROW>
    end
end

function val = param_wert(params, pfade, default)
    val = default; if ~isstruct(params), return; end
    for k = 1:numel(pfade)
        teile = strsplit(pfade{k}, '.'); cur = params; ok = true;
        for j = 1:numel(teile)
            if isstruct(cur) && isfield(cur, teile{j}), cur = cur.(teile{j}); else, ok = false; break; end
        end
        if ok && isnumeric(cur) && isscalar(cur) && isfinite(cur), val = cur; return; end
    end
end

function y = runde(v, n), if isempty(v)||~isfinite(v), y = NaN; else, y = round(v,n); end, end
function z = zeile(v), z = v(:).'; end
