% =========================================================================
%  akku_gesundheit_scan  –  Historische Akku-Gesundheit ueber viele Logs
% -------------------------------------------------------------------------
%  Zweck         : Durchsucht einen Ordner (rekursiv) nach .mf4-Dateien, laedt
%                  jede EINZELN (speicherschonend), berechnet je Zelle und je
%                  Stack Gesundheits-Kennzahlen und aggregiert sie ueber alle
%                  Logs. Meldet den Fortschritt ueber einen Callback (fuer den
%                  Ladebalken im Tab).
%
%  Kennzahlen je Zelle : Min-Spannung, Abweichung unter Last (unter Pack-Mittel),
%                        Innenwiderstand (−dV/dI), Max-Temperatur, kombinierter
%                        Kritikalitaets-Score (wie payload_akku).
%  Aggregation         : ueber alle Logs der WORST-CASE je Zelle
%                        (min V, max Abweichung/R/Temp).
%  Trend               : je Log ein Punkt (Zeit, min V, max Spread, max R, max T).
%
%  EINHEITEN-ANNAHMEN  : Zellspannung [V], IVT-Strom [A] (positiv = Entladung),
%                        Temperatur [C]. 12 Stacks x 12 Zellen (aus params).
%  Zellnummerierung    : ams_cell_voltageNNN fortlaufend 1..144;
%                        stack = ceil(idx/zellen_pro_stack).
%
%  Abhaengigkeiten     : load_mf4, signal_holen
%  Autor               : <dein Name>
%  Datum               : 2026-07-18
% =========================================================================

function gesundheit = akku_gesundheit_scan(ordner, params, fortschritt_cb)
%AKKU_GESUNDHEIT_SCAN  gesundheit = AKKU_GESUNDHEIT_SCAN(ordner, params, cb)
%   cb(prozent, text) wird waehrend des Ladens/Auswertens aufgerufen (0..100).
%   Changelog:
%     2026-07-18  Erststand.

    if nargin < 3 || isempty(fortschritt_cb), fortschritt_cb = @(varargin) []; end
    melde = @(p,t) safe_cb(fortschritt_cb, p, t);

    %% Konfiguration
    N_STACK   = pfeld(params, 'akku.stacks', 12);
    N_PROZ    = pfeld(params, 'akku.zellen_pro_stack', 12);
    UV_WARN   = pfeld(params, 'akku.uv_warn_v', 3.2);   % V
    I_MIN_FIT = pfeld(params, 'akku.i_min_fit_a', 5);   % A
    KRIT_Q    = 0.90;                                   % oberstes Quantil = kritisch
    T_GRID    = 2000;                                   % Zeit-Stuetzstellen je Log
    N_ZELLEN  = N_STACK * N_PROZ;

    %% Dateien finden
    melde(0, 'Suche .mf4-Dateien …');
    dateien = mf4_finden(ordner);
    N = numel(dateien);
    gesundheit = grundstruct(ordner, N_STACK, N_PROZ);
    if N == 0
        gesundheit.hinweis = 'Keine .mf4-Dateien im gewaehlten Ordner gefunden.';
        melde(100, 'Keine Dateien gefunden.');
        return;
    end

    %% Akkumulatoren je Zelle (Worst-Case ueber alle Logs)
    v_min   = inf(1, N_ZELLEN);
    abweich = -inf(1, N_ZELLEN);
    r_innen = -inf(1, N_ZELLEN);
    temp_mx = -inf(1, N_ZELLEN);
    gesehen = false(1, N_ZELLEN);

    logs  = {};
    trend_zeit = []; trend_vmin = []; trend_spread = []; trend_rmax = []; trend_tmax = [];

    %% Logs einzeln verarbeiten
    for i = 1:N
        [~, kurz, ext] = fileparts(dateien{i});
        name = [kurz ext];
        melde(100*(i-1)/N, sprintf('Lade %d/%d: %s', i, N, name));

        try
            cb_datei = @(varargin) melde(100*(i-1+frac(varargin))/N, ...
                                         sprintf('Lade %d/%d: %s', i, N, name));
            [store, log_start] = load_mf4(dateien{i}, cb_datei);
        catch
            logs{end+1} = struct('name',name,'zeit','—','ok',false, ...
                'dauer_s',NaN,'energie_wh',NaN,'v_min',NaN,'spread_max',NaN,'temp_max',NaN); %#ok<AGROW>
            continue;
        end

        melde(100*(i-0.5)/N, sprintf('Werte aus %d/%d: %s', i, N, name));
        s = log_auswerten(store, T_GRID, I_MIN_FIT, N_ZELLEN);
        store = []; %#ok<NASGU>  % Speicher freigeben vor naechster Datei

        % Zell-Akkumulatoren aktualisieren (Worst-Case)
        m = isfinite(s.v_min_z);
        v_min(m)   = min(v_min(m),   s.v_min_z(m));
        abweich(m) = max(abweich(m), s.abweich_z(m));
        temp_mx(m) = max(temp_mx(m), s.temp_z(m));
        rok = isfinite(s.r_innen_z);
        r_innen(rok) = max(r_innen(rok), s.r_innen_z(rok));
        gesehen = gesehen | m;

        % Zeit/Trend
        [dn, iso] = zeit_von(log_start, i);
        logs{end+1} = struct('name',name,'zeit',iso,'ok',true, ...
            'dauer_s',s.dauer_s,'energie_wh',s.energie_wh, ...
            'v_min',minf(s.v_min_z),'spread_max',s.spread_max,'temp_max',maxf(s.temp_z)); %#ok<AGROW>
        trend_zeit(end+1)   = dn;              %#ok<AGROW>
        trend_vmin(end+1)   = minf(s.v_min_z); %#ok<AGROW>
        trend_spread(end+1) = s.spread_max;    %#ok<AGROW>
        trend_rmax(end+1)   = maxf(s.r_innen_z);%#ok<AGROW>
        trend_tmax(end+1)   = maxf(s.temp_z);  %#ok<AGROW>
    end

    melde(97, 'Aggregiere Gesundheit …');

    %% Nicht gesehene Zellen -> NaN
    v_min(~gesehen)=NaN; abweich(~gesehen)=NaN; r_innen(~isfinite(r_innen))=NaN; temp_mx(~isfinite(temp_mx))=NaN;

    %% Kritikalitaets-Score je Zelle (wie payload_akku)
    rn = norm01(r_innen); dn = norm01(abweich); vn = norm01(v_min);
    score = 0.5*rn + 0.3*dn + 0.2*(1 - vn);
    schwelle = quantil(score, KRIT_Q);
    kritisch = (score >= schwelle) | (v_min < UV_WARN);

    %% Zell-Liste + Grid-Matrizen (Stack x Position)
    G_score = nan(N_STACK, N_PROZ); G_vmin = G_score; G_r = G_score; G_temp = G_score;
    zellen = {};
    for idx = 1:N_ZELLEN
        st = ceil(idx / N_PROZ); ps = idx - (st-1)*N_PROZ;
        G_score(st,ps) = runde(score(idx),3); G_vmin(st,ps) = runde(v_min(idx),3);
        G_r(st,ps)     = runde(r_innen(idx),5); G_temp(st,ps) = runde(temp_mx(idx),1);
        zellen{end+1} = struct('index',idx,'stack',st,'pos',ps, ...
            'v_min',runde(v_min(idx),3),'abweichung',runde(abweich(idx),3), ...
            'r_innen',runde(r_innen(idx),5),'temp_max',runde(temp_mx(idx),1), ...
            'score',runde(score(idx),3),'kritisch',logical(kritisch(idx))); %#ok<AGROW>
    end

    %% Stack-Zusammenfassung
    stacks = {};
    for st = 1:N_STACK
        ci = (st-1)*N_PROZ + (1:N_PROZ);
        sc = score(ci); vm = v_min(ci);
        [worst_sc, wpos] = max(sc);
        stacks{end+1} = struct('stack',st, ...
            'v_min',runde(minf(vm),3), ...
            'imbalance',runde(spanne(vm),3), ...
            'temp_max',runde(maxf(temp_mx(ci)),1), ...
            'worst_zelle',ci(1)+wpos-1, ...
            'score',runde(maxf(sc),3), ...
            'kritisch', any(kritisch(ci))); %#ok<AGROW>
    end

    %% Worst-Ranking (Top 24 nach Score)
    [~, ord] = sort(score, 'descend');
    worst = {};
    for j = 1:min(24, N_ZELLEN)
        idx = ord(j); if ~isfinite(score(idx)), break; end
        st = ceil(idx / N_PROZ); ps = idx - (st-1)*N_PROZ;
        worst{end+1} = struct('index',idx,'stack',st,'pos',ps, ...
            'score',runde(score(idx),3),'v_min',runde(v_min(idx),3), ...
            'r_innen',runde(r_innen(idx),5),'kritisch',logical(kritisch(idx))); %#ok<AGROW>
    end

    %% Trend nach Zeit sortieren
    [trend_zeit, o] = sort(trend_zeit);
    iso_zeit = arrayfun(@(d) datestr_safe(d), trend_zeit, 'UniformOutput', false);
    trend = struct('zeit', {iso_zeit}, ...
        'v_min',   zeile(trend_vmin(o)), 'spread_max', zeile(trend_spread(o)), ...
        'r_innen_max', zeile(trend_rmax(o)), 'temp_max', zeile(trend_tmax(o)));

    %% Ergebnis zusammenstellen
    gesundheit.n_logs   = sum(cellfun(@(l) l.ok, logs));
    gesundheit.n_dateien= N;
    gesundheit.stand    = datestr(now, 'yyyy-mm-dd HH:MM');
    gesundheit.grid     = struct('score',{matrix_rows(G_score)}, 'v_min',{matrix_rows(G_vmin)}, ...
                                 'r_innen',{matrix_rows(G_r)}, 'temp',{matrix_rows(G_temp)});
    gesundheit.zellen   = zellen;
    gesundheit.stacks   = stacks;
    gesundheit.worst    = worst;
    gesundheit.trend    = trend;
    gesundheit.logs     = logs;
    gesundheit.n_kritisch = sum(kritisch(gesehen));

    melde(100, sprintf('Fertig: %d Logs, %d Zellen.', gesundheit.n_logs, sum(gesehen)));
end

% =========================================================================
%  Functions
% =========================================================================

function g = grundstruct(ordner, n_stack, n_proz)
    g = struct('ordner',ordner,'n_stacks',n_stack,'n_zellen_pro_stack',n_proz, ...
        'n_logs',0,'n_dateien',0,'n_kritisch',0,'stand',datestr(now,'yyyy-mm-dd HH:MM'), ...
        'hinweis','','grid',struct(),'zellen',{{}},'stacks',{{}},'worst',{{}}, ...
        'trend',struct(),'logs',{{}});
end

function dateien = mf4_finden(ordner)
% Rekursiv alle .mf4 (case-insensitive) unter ORDNER.
    dateien = {};
    if isempty(ordner) || ~isfolder(ordner), return; end
    d = dir(fullfile(ordner, '**', '*.mf4'));
    d = d(~[d.isdir]);
    for i = 1:numel(d), dateien{end+1} = fullfile(d(i).folder, d(i).name); end %#ok<AGROW>
    dateien = unique(dateien);
end

function s = log_auswerten(store, t_grid, i_min_fit, n_zellen)
% Reduzierte Zell-Statistik EINES Logs (kein x noetig, eigene Zeitachse).
    s = struct('v_min_z',nan(1,n_zellen),'abweich_z',nan(1,n_zellen), ...
               'r_innen_z',nan(1,n_zellen),'temp_z',nan(1,n_zellen), ...
               'spread_max',NaN,'dauer_s',NaN,'energie_wh',NaN);

    % Referenz-Zeitgitter aus Strom oder Pack-Spannung
    [tI, I] = get_native(store, 'IVT_Result_I_can');
    [tV, Vp] = get_native(store, 'ams_overall_voltage_can');
    tspan = union_span(tI, tV);
    if isempty(tspan), return; end
    s.dauer_s = tspan(2) - tspan(1);
    tg = linspace(tspan(1), tspan(2), t_grid).';
    Ig = auf_gitter(tI, I, tg);

    % Energie-Durchsatz [Wh]
    Vpg = auf_gitter(tV, Vp, tg);
    if any(isfinite(Vpg)) && any(isfinite(Ig))
        p = Vpg .* Ig; p(~isfinite(p)) = 0;
        s.energie_wh = trapz(tg, abs(p)) / 3600;
    end

    % Zellspannungen -> Matrix (Zelle x Zeit)
    [znamen, zidx] = zellsignale(store, 'ams_cell_voltage');
    if ~isempty(znamen)
        M = nan(numel(znamen), numel(tg));
        for c = 1:numel(znamen)
            [tc, vc] = get_native(store, znamen{c});
            M(c,:) = auf_gitter(tc, vc, tg).';
        end
        meanrow = mean(M, 1, 'omitnan');
        s.spread_max = max(max(M,[],1,'omitnan') - min(M,[],1,'omitnan'), [], 'omitnan');
        for c = 1:numel(znamen)
            idx = zidx(c); if idx < 1 || idx > n_zellen, continue; end
            Vc = M(c,:);
            s.v_min_z(idx)   = min(Vc, [], 'omitnan');
            s.abweich_z(idx) = mean(max(0, meanrow - Vc), 'omitnan');
            s.r_innen_z(idx) = innenwiderstand(Vc, Ig, i_min_fit);
        end
    end

    % Temperaturen -> je Zelle (Sensoren gleichmaessig auf Stacks verteilt)
    [tnamen, ~] = zellsignale(store, 'ams_cell_temp');
    if ~isempty(tnamen)
        tmax = nan(1, numel(tnamen));
        for c = 1:numel(tnamen)
            [~, vt] = get_native(store, tnamen{c});
            if ~isempty(vt), tmax(c) = max(vt, [], 'omitnan'); end
        end
        % Sensoren -> Zellen: proportional strecken (grobe erste Naeherung)
        for idx = 1:n_zellen
            si = max(1, ceil(idx / n_zellen * numel(tnamen)));
            s.temp_z(idx) = tmax(si);
        end
    end
end

function [namen, idx] = zellsignale(store, prefix)
    alle = unique({store.name});
    treffer = alle(startsWith(alle, prefix));
    namen = {}; nr = [];
    for i = 1:numel(treffer)
        sg = signal_holen(store, treffer{i});
        if ~strcmp(sg.status, 'gueltig'), continue; end
        z = regexp(treffer{i}, '\d+', 'match', 'once');
        namen{end+1} = treffer{i}; nr(end+1) = str2double(z); %#ok<AGROW>
    end
    [nr, o] = sort(nr); namen = namen(o); idx = nr;
end

function [t, v] = get_native(store, name)
    sg = signal_holen(store, name);
    if strcmp(sg.status,'fehlt') || numel(sg.t) < 2, t = []; v = []; return; end
    [t, iu] = unique(sg.t(:)); v = sg.value(iu);
end

function y = auf_gitter(t, v, tg)
    if numel(t) < 2, y = nan(size(tg)); return; end
    y = interp1(t, v, tg, 'linear', NaN);
end

function sp = union_span(varargin)
    lo = inf; hi = -inf;
    for k = 1:nargin
        t = varargin{k};
        if ~isempty(t), lo = min(lo, t(1)); hi = max(hi, t(end)); end
    end
    if lo < hi, sp = [lo hi]; else, sp = []; end
end

function r = innenwiderstand(V, I, i_min)
    V = V(:); I = I(:);
    ok = isfinite(V) & isfinite(I); V = V(ok); I = I(ok);
    if numel(I) < 20 || (max(I)-min(I)) < i_min, r = NaN; return; end
    Im = mean(I); Vm = mean(V); nenner = sum((I-Im).^2);
    if nenner == 0, r = NaN; return; end
    r = max(0, -sum((I-Im).*(V-Vm)) / nenner);
end

function y = norm01(v)
    v = v(:).'; lo = min(v,[],'omitnan'); hi = max(v,[],'omitnan');
    if ~isfinite(lo) || hi==lo, y = zeros(size(v)); else, y = (v-lo)/(hi-lo); end
    y(isnan(y)) = 0;
end

function q = quantil(v, p)
    v = v(isfinite(v)); if isempty(v), q = Inf; return; end
    sv = sort(v); q = sv(max(1,min(numel(sv),ceil(p*numel(sv)))));
end

function C = matrix_rows(Mx)
% Matrix -> Cell-Array von Zeilen (array-sicheres JSON).
    C = cell(1, size(Mx,1));
    for r = 1:size(Mx,1), C{r} = zeile(Mx(r,:)); end
end

function [dn, iso] = zeit_von(log_start, fallback_i)
    try
        if isdatetime(log_start)
            dn = datenum(log_start); iso = datestr(log_start, 'yyyy-mm-dd HH:MM');
        elseif isnumeric(log_start) && isscalar(log_start) && isfinite(log_start)
            dn = log_start; iso = datestr(log_start, 'yyyy-mm-dd HH:MM');
        else
            dn = fallback_i; iso = sprintf('Log %d', fallback_i);
        end
    catch
        dn = fallback_i; iso = sprintf('Log %d', fallback_i);
    end
end

function s = datestr_safe(dn)
    if dn > 700000, s = datestr(dn, 'yyyy-mm-dd HH:MM'); else, s = sprintf('Log %d', round(dn)); end
end

function safe_cb(cb, p, t)
    try, cb(max(0,min(100,p)), t); catch, end
end

function f = frac(args)
    f = 0;
    for k = 1:numel(args)
        if isnumeric(args{k}) && isscalar(args{k}) && isfinite(args{k})
            f = max(0, min(1, double(args{k}))); return;
        end
    end
end

function y = minf(v), y = min(v(isfinite(v))); if isempty(y), y = NaN; end, end
function y = maxf(v), y = max(v(isfinite(v))); if isempty(y), y = NaN; end, end
function y = spanne(v), v = v(isfinite(v)); if isempty(v), y = NaN; else, y = max(v)-min(v); end, end
function y = runde(v, n), if isempty(v)||~isfinite(v), y = NaN; else, y = round(v,n); end, end
function z = zeile(v), z = v(:).'; end

function val = pfeld(params, pfad, default)
    val = default; if ~isstruct(params), return; end
    teile = strsplit(pfad, '.'); cur = params;
    for j = 1:numel(teile)
        if isstruct(cur) && isfield(cur, teile{j}), cur = cur.(teile{j}); else, return; end
    end
    if isnumeric(cur) && isscalar(cur) && isfinite(cur), val = cur; end
end
