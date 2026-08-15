function pl = payload_potis(store, x, params, runden)
% PAYLOAD_POTIS  Backend-Payload fuer den Linearpoti-Analyse-Tab.
% Signatur hat 4 Argumente, damit sie zum uniformen Aufruf in
% alle_tabs_aktualisieren/baue_payload passt (store,x,params,runden).
% runden wird hier aktuell NICHT genutzt (keine Rundenrestriktion im Poti-Tab).
%
% Envelope (wie die anderen Tabs):
%   pl.meta.tab, pl.meta.x_modus, pl.meta.x_einheit
%   pl.x            - gemeinsamer x-Vektor (Zeit oder Distanz, siehe x.modus)
%   pl.signals{}    - {name, unit, status, y}  (auf x resampled)
%   pl.health{}     - {ecke, name, status}
%   pl.panels.kalibrierung, .federweg, .histogramm_federweg,
%             .damperv, .korrelation
%
% ANNAHMEN (bitte pruefen/bestaetigen):
%   1) Zuordnung Ecke->Signal Default FL=sysAnalog_01, FR=sysAnalog_02,
%      RL=sysAnalog_03, RR=sysAnalog_04 - ueberschreibbar via
%      params.poti.zuordnung.FL/FR/RL/RR (Signalname als String)
%   2) Vorzeichen Poti: steigende Spannung/mm = EINFEDERN (Kompression)
%      angenommen. Falls andersrum, in kalibrierung mm2<mm1 tauschen oder
%      hier v_x negieren - Kennzeichnung liegt aktuell beim Frontend-Label
%   3) IMU-Signale fuer die Korrelation: INS_acc_x_can (Nicken/Dive),
%      INS_acc_y_can (Rollen) - Namen ggf. anpassen
%
% params.poti.kalibrierung.<Ecke> = struct('v1',..,'mm1',..,'v2',..,'mm2',..)
%   2-Punkt-linear V->mm. Fehlt eine Ecke oder ist v1==0,mm1==0,v2==1,mm2==1
%   (Default), gilt die Ecke als UNKALIBRIERT und laeuft in Rohspannung (V).
%
% params.poti.ay_schwelle (Default 5 m/s^2), params.poti.ax_schwelle (Default 3 m/s^2)
%   Schwellen fuer die Roll-/Nick-Korrelation (nur Segmente ueber der Schwelle).

if nargin < 3 || isempty(params)
    params = struct();
end
if nargin < 4
    runden = struct('name', {}, 't_start', {}, 't_ende', {}, 'fahrer', {}); %#ok<NASGU>
end

% ---------------------------------------------------------------
% Ecke -> Signalname
% ---------------------------------------------------------------
zuordnung = struct('FL','sysAnalog_01','FR','sysAnalog_02', ...
                    'RL','sysAnalog_03','RR','sysAnalog_04');
if isfield(params,'poti') && isfield(params.poti,'zuordnung')
    zuordnung = merge_struct(zuordnung, params.poti.zuordnung);
end
ecken = {'FL','FR','RL','RR'};

kal_default = struct('v1',0,'mm1',0,'v2',1,'mm2',1);
kal_in = struct();
if isfield(params,'poti') && isfield(params.poti,'kalibrierung')
    kal_in = params.poti.kalibrierung;
end

ay_schwelle = 5;
ax_schwelle = 3;
if isfield(params,'poti')
    if isfield(params.poti,'ay_schwelle'), ay_schwelle = params.poti.ay_schwelle; end
    if isfield(params.poti,'ax_schwelle'), ax_schwelle = params.poti.ax_schwelle; end
end

x_werte = x.werte(:);

signals    = {};
health     = {};
federweg   = {};
hist_fw    = {};
damperv    = {};
kal_out    = struct();
serie_x    = struct();   % kalibrierte Serie auf x, pro Ecke - fuer Korrelation

% ---------------------------------------------------------------
% Pro Ecke: laden, kalibrieren, resamplen, Kennwerte
% ---------------------------------------------------------------
for i = 1:numel(ecken)
    ecke    = ecken{i};
    signame = zuordnung.(ecke);
    [t_raw, v_raw, status] = lade_signal(store, signame);

    health{end+1} = struct('ecke', ecke, 'name', signame, 'status', status); %#ok<AGROW>

    if isempty(t_raw)
        serie_x.(ecke) = nan(size(x_werte));
        continue
    end

    % Kalibrierung dieser Ecke bestimmen
    if isfield(kal_in, ecke)
        k = merge_struct(kal_default, kal_in.(ecke));
    else
        k = kal_default;
    end
    ist_kalibriert = abs(k.v2 - k.v1) > 1e-9 && ~isequal(k, kal_default);
    if ist_kalibriert
        steigung = (k.mm2 - k.mm1) / (k.v2 - k.v1);
        werte_native = k.mm1 + (v_raw - k.v1) .* steigung;
        einheit = 'mm';
    else
        werte_native = v_raw;
        einheit = 'V';
    end
    kal_out.(ecke) = struct('v1',k.v1,'mm1',k.mm1,'v2',k.v2,'mm2',k.mm2, ...
                             'kalibriert', ist_kalibriert, 'einheit', einheit);

    % Auf gemeinsames x resamplen (fuer Anzeige/Korrelation)
    v_x  = interp1(t_raw, v_raw,      x_werte, 'linear', NaN);
    kalx = interp1(t_raw, werte_native, x_werte, 'linear', NaN);
    serie_x.(ecke) = kalx;

    signals{end+1} = struct('name',[ecke '_raw'],'unit','V','status',status,'y',v_x); %#ok<AGROW>
    if ist_kalibriert
        signals{end+1} = struct('name',[ecke '_mm'],'unit','mm','status',status,'y',kalx); %#ok<AGROW>
    end

    % --- Federweg-Nutzung (auf der nativen, nicht-resampleten Serie) ---
    gueltig = werte_native(~isnan(werte_native));
    if ~isempty(gueltig)
        federweg{end+1} = struct('ecke',ecke,'einheit',einheit, ...
            'min',min(gueltig),'max',max(gueltig), ...
            'range',max(gueltig)-min(gueltig), ...
            'mean',mean(gueltig), ...
            'p1',prctile(gueltig,1),'p99',prctile(gueltig,99)); %#ok<AGROW>

        [counts, kanten] = histcounts(gueltig, 40);
        hist_fw{end+1} = struct('ecke',ecke,'einheit',einheit, ...
            'kanten',kanten,'counts',counts); %#ok<AGROW>
    end

    % --- Daempfergeschwindigkeit aus nativer dt (unabh. von x-Modus) ---
    if numel(t_raw) > 5
        dt = diff(t_raw);
        gueltig_dt = dt > 0;
        v_geschw = diff(werte_native) ./ dt;      % Einheit/s (mm/s oder V/s)
        v_geschw = v_geschw(gueltig_dt);
        v_geschw = v_geschw(~isnan(v_geschw) & isfinite(v_geschw));
        if ~isempty(v_geschw)
            [counts_v, kanten_v] = histcounts(v_geschw, 40);
            bump_max     = max(v_geschw);             % Annahme: + = Einfedern
            rebound_max  = min(v_geschw);
            damperv{end+1} = struct('ecke',ecke,'einheit',[einheit '/s'], ...
                'kanten',kanten_v,'counts',counts_v, ...
                'bump_max',bump_max,'rebound_max',rebound_max, ...
                'rms',sqrt(mean(v_geschw.^2))); %#ok<AGROW>
        end
    end
end

% ---------------------------------------------------------------
% Roll-/Nick-Korrelation gegen IMU
% ---------------------------------------------------------------
[t_ax, v_ax, ~] = lade_signal(store, 'INS_acc_x_can');
[t_ay, v_ay, ~] = lade_signal(store, 'INS_acc_y_can');

korrelation = struct('roll', struct('r',NaN,'n',0,'x',[],'y',[],'steigung',NaN,'achsenabschnitt',NaN), ...
                      'dive', struct('r',NaN,'n',0,'x',[],'y',[],'steigung',NaN,'achsenabschnitt',NaN));

if all(isfield(serie_x,{'FL','FR'})) && ~isempty(t_ay)
    ay_x   = interp1(t_ay, v_ay, x_werte, 'linear', NaN);
    diff_v = serie_x.FL - serie_x.FR;
    korrelation.roll = korrel_panel(ay_x, diff_v, ay_schwelle);
end
if all(isfield(serie_x,{'FL','FR'})) && ~isempty(t_ax)
    ax_x   = interp1(t_ax, v_ax, x_werte, 'linear', NaN);
    summe_v = serie_x.FL + serie_x.FR;
    korrelation.dive = korrel_panel(ax_x, summe_v, ax_schwelle);
end

% ---------------------------------------------------------------
% Envelope zusammenbauen
% ---------------------------------------------------------------
pl.meta.tab       = 'potis';
pl.meta.x_modus   = x.modus;
pl.meta.x_einheit = x.einheit;
pl.x              = x_werte;
pl.signals        = signals;
pl.health         = health;

pl.panels.kalibrierung          = kal_out;
pl.panels.federweg              = federweg;
pl.panels.histogramm_federweg   = hist_fw;
pl.panels.damperv               = damperv;
pl.panels.korrelation           = korrelation;

end

% ===================================================================
function [t,v,status] = lade_signal(store, name)
% Nutzt denselben Signal-Zugriff wie payload_fahrer.m (signal_holen),
% statt den store selbst zu interpretieren - das war der Bug: die
% alte containers.Map/struct-Feld-Logik traf die tatsaechliche
% store-Struktur nicht, weshalb jedes Signal als 'fehlt' galt.
t = []; v = []; status = 'fehlt';
sig = signal_holen(store, name);
if isempty(sig) || ~isstruct(sig) || strcmp(sig.status, 'fehlt') || isempty(sig.t)
    return
end
t = sig.t(:);
v = sig.value(:);
status = sig.status;
end

% ===================================================================
function s = merge_struct(default_s, override_s)
s = default_s;
if isstruct(override_s)
    f = fieldnames(override_s);
    for i = 1:numel(f)
        s.(f{i}) = override_s.(f{i});
    end
end
end

% ===================================================================
function p = korrel_panel(bezug, wert, schwelle)
% Pearson-r + einfache lineare Regression, nur ueber |bezug|>schwelle,
% Streudiagramm auf max. ~1500 Punkte dezimiert.
maske = ~isnan(bezug) & ~isnan(wert) & abs(bezug) > schwelle;
bx = bezug(maske);
by = wert(maske);
n  = numel(bx);
if n < 10
    p = struct('r',NaN,'n',n,'x',[],'y',[],'steigung',NaN,'achsenabschnitt',NaN);
    return
end
r_mat = corrcoef(bx, by);
r = r_mat(1,2);
koeff = polyfit(bx, by, 1);

if n > 1500
    idx = round(linspace(1, n, 1500));
else
    idx = 1:n;
end

p = struct('r',r,'n',n,'x',bx(idx),'y',by(idx), ...
           'steigung',koeff(1),'achsenabschnitt',koeff(2));
end
