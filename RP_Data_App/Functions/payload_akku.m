% =========================================================================
%  payload_akku  –  Dateivertrag fuer den Akku-Tab (nur HV-Traktionsakku)
% -------------------------------------------------------------------------
%  Zweck         : Pack-Uebersicht, SOC (IVT-Integral + BMS), Zellgesundheit
%                  (Innenwiderstand, Abweichung unter Last, Minimalspannung ->
%                  Kritikalitaets-Score je Zelle), Zell-Heatmap (dezimiert),
%                  Spread-Band, Spannungsabfall (R_i + Verlustleistung),
%                  Temperatur-Spread mit Hotspot und akku-bedingtes Derating.
%
%  EINHEITEN-ANNAHMEN: Zellspannungen [V], IVT-Strom [A] (positiv = Entladung),
%                      Temperaturen [C]. Anpassbar ueber die Konstanten unten.
%
%  Abhaengigkeiten: payload_envelope, signal_holen
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function pl = payload_akku(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_AKKU  pl = PAYLOAD_AKKU(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand (Stub).
%     2026-07-15  Zellgesundheit + Heatmap + Score + Sag/Temp/SOC.
%     2026-07-18  Kontext-Signale (speed_can, apps1_can) fuer waehlbaren Plot.

    %% Konfiguration
    T_HM      = 320;    % Spalten der Heatmap (Zeit dezimiert)
    UV_WARN   = 3.2;    % V, darunter gilt die Minimalspannung als kritisch
    I_MIN_FIT = 5;      % A, Mindest-Stromspanne fuer die R-Schaetzung
    KRIT_QUANT= 0.90;   % oberstes Quantil des Scores gilt als kritisch

    %% Pack-Uebersicht -> Envelope
    %  Zusaetzliche Kontext-Signale (speed/apps) fuers waehlbare Kontext-Panel;
    %  bei Bedarf hier weitere aufnehmen -> erscheinen automatisch im Dropdown.
    pack = { 'ams_overall_voltage_can','IVT_Result_I_can','IVT_Result_As_can', ...
             'ams_cell_min_voltage_can','ams_cell_max_voltage_can', ...
             'ams_cell_min_temp_can','ams_cell_max_temp_can','ams_cell_avg_temp_can', ...
             'ams_capacity_fl_can', ...
             'speed_can','apps1_can' };
    pl = payload_envelope(store, 'akku', x, pack);

    %% Strom auf x (fuer R-Schaetzung, Sag, SOC)
    I = res(store, x, 'IVT_Result_I_can');

    %% Zellspannungs-Matrix (Zelle x x)
    [znamen, zidx] = zellsignale(store, 'ams_cell_voltage');
    n = numel(znamen);
    M = nan(max(n,0), numel(x.werte));
    for c = 1:n, M(c,:) = res(store, x, znamen{c}).'; end

    if n == 0
        pl.panels.zellen = struct('anzahl', 0, 'spread', struct(), ...
            'heatmap', struct(), 'kritische', {{}});
    else
        mean_row = mean(M, 1, 'omitnan');   % Pack-Mittel je Zeitpunkt

        %% Kennzahlen je Zelle
        r_innen = nan(1,n); v_min = nan(1,n); abweich = nan(1,n);
        for c = 1:n
            Vc = M(c,:);
            v_min(c)  = min(Vc, [], 'omitnan');
            abweich(c)= mean(max(0, mean_row - Vc), 'omitnan');   % unter dem Mittel
            r_innen(c)= innenwiderstand(Vc, I, I_MIN_FIT);        % Ohm
        end

        %% Kritikalitaets-Score (0..1 normiert kombiniert)
        rn = norm01(r_innen); dn = norm01(abweich); vn = norm01(v_min);
        score = 0.5*rn + 0.3*dn + 0.2*(1 - vn);
        schwelle = quantil(score, KRIT_QUANT);
        kritisch = (score >= schwelle) | (v_min < UV_WARN);

        %% Kritische-Zellen-Liste, nach Score sortiert
        [~, ord] = sort(score, 'descend');
        krit = {};
        for j = 1:n
            c = ord(j);
            krit{end+1} = struct('index', zidx(c), 'score', runde(score(c),3), ...
                'r_innen', runde(r_innen(c),4), 'v_min', runde(v_min(c),3), ...
                'abweichung', runde(abweich(c),3), 'kritisch', logical(kritisch(c))); %#ok<AGROW>
        end

        %% Heatmap (Zeit dezimiert)
        cols = spalten_index(numel(x.werte), T_HM);
        Mh = M(:, cols);
        heat = struct('t', zeile(x.werte(cols)), 'index', zeile(zidx), ...
            'mean', zeile(mean_row(cols)), 'matrix', {matrix_zellen(Mh)});

        %% Spread-Band
        spread = struct('min', zeile(min(M,[],1,'omitnan')), ...
                        'mean', zeile(mean_row), ...
                        'max', zeile(max(M,[],1,'omitnan')));

        pl.panels.zellen = struct('anzahl', n, 'spread', spread, ...
            'heatmap', heat, 'kritische', {krit});
    end

    %% SOC: IVT-Integral (primaer) + BMS
    pl.panels.soc = soc_bauen(store, x, I, params);

    %% Spannungsabfall: Pack-Innenwiderstand + Verlustleistung
    Vpack = res(store, x, 'ams_overall_voltage_can');
    r_pack = innenwiderstand(Vpack.', I, I_MIN_FIT);
    verlust = (I.^2) * max(r_pack, 0);                 % W (ohmsch)
    pl.panels.spannungsabfall = struct('r_i_pack', runde(r_pack,4), ...
        'verlustleistung', zeile(verlust));

    %% Temperatur-Spread + Hotspot
    pl.panels.temp = temp_bauen(store, x);

    %% Akku-bedingtes Derating
    pl.panels.derating = struct('marker', {derating_marker(store, x)});
end

%  Functions

function y = res(store, x, name)
    sig = signal_holen(store, name);
    if strcmp(sig.status,'fehlt') || isempty(sig.t), y = nan(size(x.t_ref(:))); return; end
    [tu,iu] = unique(sig.t(:));
    y = interp1(tu, sig.value(iu), x.t_ref(:), 'linear', NaN);
end

function [namen, idx] = zellsignale(store, prefix)
% Alle gueltigen Zell-Signale mit gegebenem Praefix, nach Nummer sortiert.
    alle = unique({store.name});
    treffer = alle(startsWith(alle, prefix));
    namen = {}; nr = [];
    for i = 1:numel(treffer)
        s = signal_holen(store, treffer{i});
        if ~strcmp(s.status, 'gueltig'), continue; end
        z = regexp(treffer{i}, '\d+', 'match', 'once');
        namen{end+1} = treffer{i}; nr(end+1) = str2double(z); %#ok<AGROW>
    end
    [nr, o] = sort(nr); namen = namen(o); idx = nr;
end

function r = innenwiderstand(V, I, i_min)
% R ~ -Steigung von V ueber I (Least Squares). NaN bei zu kleiner Stromspanne.
    V = V(:); I = I(:);
    ok = isfinite(V) & isfinite(I);
    V = V(ok); I = I(ok);
    if numel(I) < 20 || (max(I)-min(I)) < i_min, r = NaN; return; end
    Im = mean(I); Vm = mean(V);
    nenner = sum((I-Im).^2);
    if nenner == 0, r = NaN; return; end
    steig = sum((I-Im).*(V-Vm)) / nenner;
    r = max(0, -steig);
end

function y = norm01(v)
% Min-Max-Normierung ueber die Zellen (NaN -> 0).
    v = v(:).';
    lo = min(v,[],'omitnan'); hi = max(v,[],'omitnan');
    if ~isfinite(lo) || hi==lo, y = zeros(size(v)); else, y = (v-lo)/(hi-lo); end
    y(isnan(y)) = 0;
end

function q = quantil(v, p)
    v = v(isfinite(v)); if isempty(v), q = Inf; return; end
    s = sort(v); q = s(max(1,min(numel(s),ceil(p*numel(s)))));
end

function cols = spalten_index(nx, ziel)
    if nx <= ziel, cols = 1:nx; else, cols = round(linspace(1, nx, ziel)); end
end

function C = matrix_zellen(Mh)
% Matrix (Zellen x Spalten) als Cell-Array von Zeilen (array-sicheres JSON).
    C = cell(1, size(Mh,1));
    for r = 1:size(Mh,1), C{r} = zeile(Mh(r,:)); end
end

function soc = soc_bauen(store, x, I, params)
    bms = res(store, x, 'ams_capacity_fl_can');           % %
    kap_ah = params.akku.kapazitaet_kwh*1000 / max(params.akku.nennspannung_v, eps);
    soc0 = 100; b0 = bms(find(isfinite(bms),1)); if ~isempty(b0), soc0 = b0; end
    Ig = I; Ig(isnan(Ig)) = 0;
    verbraucht_ah = cumtrapz(x.t_ref(:), Ig) / 3600;      % Ah (positiv = entladen)
    ivt = soc0 - 100 * verbraucht_ah / max(kap_ah, eps);
    soc = struct('ivt', zeile(ivt), 'bms', zeile(bms));
end

function temp = temp_bauen(store, x)
    [tn, tidx] = zellsignale(store, 'ams_cell_temp');
    n = numel(tn);
    if n == 0
        temp = struct('anzahl',0,'spread',struct(),'hotspot_index',NaN,'max_temp',NaN); return;
    end
    Mt = nan(n, numel(x.werte));
    for c = 1:n, Mt(c,:) = res(store, x, tn{c}).'; end
    zmax = max(Mt, [], 2, 'omitnan');
    [maxt, hc] = max(zmax);
    spread = struct('min', zeile(min(Mt,[],1,'omitnan')), ...
                    'mean', zeile(mean(Mt,1,'omitnan')), ...
                    'max', zeile(max(Mt,[],1,'omitnan')));
    temp = struct('anzahl', n, 'spread', spread, ...
        'hotspot_index', tidx(hc), 'max_temp', runde(maxt,1));
end

function marker = derating_marker(store, x)
    marker = {};
    alle = unique({store.name});
    kand = alle(startsWith(alle, 'drive_deratingAccu'));
    for i = 1:numel(kand)
        s = signal_holen(store, kand{i});
        if ~isempty(s.value) && any(s.value > 0.5)
            te = s.t(find(s.value > 0.5, 1));
            marker{end+1} = struct('name', kand{i}, ...
                'x', interp1(x.t_ref(:), x.werte(:), te, 'linear', NaN)); %#ok<AGROW>
        end
    end
end

function y = runde(v, n)
    if isempty(v) || ~isfinite(v), y = NaN; else, y = round(v, n); end
end

function z = zeile(v)
z = v(:).';
end
