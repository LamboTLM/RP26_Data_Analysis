% =========================================================================
%  payload_scratchbook  –  Dateivertrag fuer den Scratchbook-Tab
% -------------------------------------------------------------------------
%  Zweck         : Freier Analyse-Arbeitsplatz. Liefert den Signal-Katalog und
%                  rechnet die vom Frontend geschickte Konfiguration:
%                  eigene Math-Kanaele (Formeln) und beliebige Plots
%                  (Zeitreihe / XY-Scatter / Histogramm).
%
%  Datenfluss    : Das Frontend baut eine Config {math, plots} und schickt sie
%                  per Event; die App legt sie in params.scratch_config ab und
%                  ruft diesen Payload erneut. Hier werden Signale resampled,
%                  die Formeln ausgewertet und die Plot-Daten zurueckgegeben.
%
%  Formeln       : Signalnamen sind gueltige Variablen; elementweise Operatoren
%                  nutzen (.*  ./  .^). Beispiel:
%                    kombi_g = sqrt(INS_acc_x_can.^2 + INS_acc_y_can.^2)
%
%  Abhaengigkeiten: signal_holen, scratchconfigs_laden
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function pl = payload_scratchbook(store, x, params, runden) %#ok<INUSD>
%PAYLOAD_SCRATCHBOOK  pl = PAYLOAD_SCRATCHBOOK(store, x, params, runden)
%   Changelog:
%     2026-07-15  Erststand (Stub).
%     2026-07-15  Katalog + Formel-Engine + freie Plots + Configs.

    pl = struct();
    pl.meta = struct('tab', 'scratchbook');

    %% Signal-Katalog (Namen/Subsystem/Status)
    alle = sort(unique({store.name}));
    kat = {};
    for i = 1:numel(alle)
        s = signal_holen(store, alle{i});
        kat{end+1} = struct('name', alle{i}, 'subsystem', s.subsystem, 'status', s.status); %#ok<AGROW>
    end
    pl.panels.katalog = kat;

    %% Gespeicherte Layouts (Namen) + zuletzt geladenes Layout
    datei = feld(params, 'scratchconfig_datei', '');
    pl.panels.configs = config_namen(datei);
    pl.panels.geladene_config = struct('stamp', feld(params,'scratch_stamp',0), ...
                                       'config', feld(params,'scratch_config',[]));

    %% Konfiguration rechnen (falls vorhanden und Run geladen)
    cfg = feld(params, 'scratch_config', []);
    if ~isempty(cfg) && isstruct(cfg) && ~isempty(fieldnames(store))
        [plots, math_status] = rechnen(store, x, cfg);
        pl.panels.plots = plots;
        pl.panels.math_status = math_status;
    else
        pl.panels.plots = {};
        pl.panels.math_status = {};
    end
end

% =========================================================================
%  Functions
% =========================================================================

function [plots, math_status] = rechnen(store, x, cfg)
    plots = {}; math_status = {};
    verf = unique({store.name});

    math  = to_list(feld(cfg,'math',{}));
    pdefs = to_list(feld(cfg,'plots',{}));

    %% Referenzierte Signale sammeln (aus Formeln + Plot-Kanaelen)
    ref = {};
    for i = 1:numel(math)
        toks = regexp(char(feld(math{i},'ausdruck','')), '[A-Za-z]\w*', 'match');
        ref = [ref, intersect(toks, verf)]; %#ok<AGROW>
    end
    for i = 1:numel(pdefs)
        kan = to_cellstr(feld(pdefs{i},'kanaele',{}));
        ref = [ref, intersect(kan, verf)]; %#ok<AGROW>
        xk = char(feld(pdefs{i},'x_kanal',''));
        if ~isempty(xk) && ismember(xk, verf), ref{end+1} = xk; end %#ok<AGROW>
    end
    ref = unique(ref);

    %% Signale auf x resampeln -> vars
    vars = struct();
    for i = 1:numel(ref), vars.(ref{i}) = res(store, x, ref{i}); end

    %% Math-Kanaele auswerten (in Reihenfolge; koennen aufeinander aufbauen)
    for i = 1:numel(math)
        nm = char(feld(math{i},'name',''));
        au = char(feld(math{i},'ausdruck',''));
        if isempty(nm), continue; end
        [y, ok, fehler] = eval_ausdruck(au, vars, numel(x.werte));
        if isvarname(nm), vars.(nm) = y; end
        math_status{end+1} = struct('name', nm, 'ok', ok, 'fehler', fehler); %#ok<AGROW>
    end

    %% Plots bauen
    for i = 1:numel(pdefs)
        p   = pdefs{i};
        typ = char(feld(p,'typ','zeit'));
        tit = char(feld(p,'titel',''));
        kan = to_cellstr(feld(p,'kanaele',{}));
        switch typ
            case 'xy'
                xk = char(feld(p,'x_kanal',''));
                xv = resolve(vars, xk);
                serien = serien_bauen(vars, kan);
                plots{end+1} = struct('typ','xy','titel',tit,'x_name',xk, ...
                    'x', zeile(xv), 'serien', {serien}); %#ok<AGROW>
            case 'hist'
                nm = ''; if ~isempty(kan), nm = kan{1}; end
                y = resolve(vars, nm);
                y = y(isfinite(y));
                if numel(y) > 8000, y = y(round(linspace(1,numel(y),8000))); end
                plots{end+1} = struct('typ','hist','titel',tit,'name',nm,'werte',zeile(y)); %#ok<AGROW>
            otherwise % 'zeit'
                serien = serien_bauen(vars, kan);
                plots{end+1} = struct('typ','zeit','titel',tit, ...
                    'x', zeile(x.werte), 'serien', {serien}); %#ok<AGROW>
        end
    end
end

function serien = serien_bauen(vars, kanaele)
    serien = {};
    for i = 1:numel(kanaele)
        serien{end+1} = struct('name', kanaele{i}, ...
            'y', zeile(resolve(vars, kanaele{i}))); %#ok<AGROW>
    end
end

function y = resolve(vars, name)
% Kanal aufloesen: Signal oder Math-Kanal (beide liegen in vars).
    if ~isempty(name) && isvarname(name) && isfield(vars, name)
        y = vars.(name);
    else
        % NaN in passender Laenge (aus irgendeinem vars-Feld ableiten)
        f = fieldnames(vars);
        n = 1; if ~isempty(f), n = numel(vars.(f{1})); end
        y = nan(1, n);
    end
end

function [y, ok, fehler] = eval_ausdruck(ausdruck, vars, n)
% Formel mit den Signalen als Variablen auswerten.
    ok = true; fehler = '';
    try
        f = fieldnames(vars);
        for i = 1:numel(f)
            eval([f{i} ' = vars.' f{i} ';']); %#ok<EVLDIR>
        end
        y = eval(ausdruck); %#ok<EVLDIR>
        y = y(:).';
        if isscalar(y), y = repmat(y, 1, n); end
        if numel(y) ~= n, y = nan(1, n); ok = false; fehler = 'Laenge passt nicht zur x-Achse'; end
    catch err
        y = nan(1, n); ok = false; fehler = err.message;
    end
end

function y = res(store, x, name)
    sig = signal_holen(store, name);
    if strcmp(sig.status,'fehlt') || isempty(sig.t), y = nan(1, numel(x.werte)); return; end
    [tu,iu] = unique(sig.t(:));
    methode = 'linear'; if sig.is_bool, methode = 'previous'; end
    y = interp1(tu, sig.value(iu), x.t_ref(:), methode, NaN).';
end

function namen = config_namen(pfad)
    cfgs = scratchconfigs_laden(pfad);
    namen = {};
    for i = 1:numel(cfgs), namen{end+1} = struct('name', cfgs(i).name); end %#ok<AGROW>
end

function c = to_list(v)
% JSON-Liste (struct-Array / struct / [] ) -> Cell-Array von Structs.
    if isempty(v), c = {}; return; end
    if iscell(v), c = v; return; end
    if isstruct(v), c = num2cell(v); return; end
    c = {v};
end

function c = to_cellstr(v)
    if isempty(v), c = {}; return; end
    if ischar(v), c = {v}; return; end
    if iscell(v), c = cellfun(@char, v, 'UniformOutput', false); return; end
    if isstring(v), c = cellstr(v); return; end
    c = {};
end

function v = feld(s, name, default)
    if isstruct(s) && isfield(s, name), v = s.(name); else, v = default; end
end
function z = zeile(v), z = v(:).'; end
