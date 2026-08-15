function viz = plot_result_dashboard(res, cfg, surrogates)
%% FUNKTION: plot_result_dashboard
% Ergebnis-Dashboard der FSAE-Setup-Optimierung (RP26e). Nachfolger von
% plot_results.m mit Fokus auf INTERPRETIERBARKEIT: welche KPIs haben sich
% WODURCH veraendert und welches Fahrverhalten resultiert.
%
% Figures:
%   Fig 1 - Ergebnis-Ueberblick : richtungsbereinigte KPI-Scorecard + Pareto-Front
%   Fig 2 - Wodurch            : Parameter-Delta (nominal->best) + Attributions-Heatmap
%                                 global (Regression aus LHS) neben lokal (Surrogat-Gradient)
%   Fig 3 - Fahrverhalten      : Modal-Panel (Ride-Freq/Zeta/Flat-Ride) + Balance-Kompass
%   Fig 4 - Zustandsgroessen   : Hub/Roll/Nick + Ableitungen und Einfederung, base vs best
%
% Abhaengigkeiten: nur Base-MATLAB (kein Stats-Toolbox noetig; Regression per Backslash).
%
% Eingaben:
%   res        struct - buendelt die Workspace-Variablen (Feldliste s. Validierung unten)
%   cfg        struct - Farbfelder (bg/fg/grid/c_ax/col_*) + cfg.opt.param_names/param_units
%   surrogates struct - OPTIONAL. surrogates.predict = function_handle:
%                        y = predict(x) mit x [1 x n_vars] VOLLER Parametervektor
%                        (physikalisch), y = [grip_total, rh_var_mean, roll_grad]
%                        (gleiche Reihenfolge wie die 3 GA-Ziele). Fehlt es ->
%                        lokale Attribution wird uebersprungen.
%
% res-Optionalfeld:
%   res.x_base [1 x n_vars] - echtes Baseline-Setup fuer den Parameter-Delta-Plot.
%                             Fehlt es -> Bereichsmitte (nominal_all) als Referenz.
%
% Ausgabe:
%   viz  struct - Handles der Figures + berechnete Attributionsmatrizen
%
% Autor: (dein Name)      Datum: 22.07.2026
%
% Changelog:
%   22.07.2026 v1 - Ersterstellung (4-Figure-Dashboard), globale + lokale Attribution

fprintf('=== plot_result_dashboard: Erstelle Dashboard\n');

%% KONFIGURATION

% --- Eingaben validieren ---
req = {'kpis_base','kpis_best','x_best','nominal_all','lb','ub','active_idx', ...
       'X_valid','Y_mat','x_pareto','f_pareto','modal_base','modal_best', ...
       'derived_base_full','derived_best_full','t_base_full','t_best_full'};
for i = 1:numel(req)
    if ~isfield(res, req{i})
        error('plot_result_dashboard:input', 'res.%s fehlt.', req{i});
    end
end
if nargin < 3 || isempty(surrogates) || ~isfield(surrogates,'predict')
    surrogates = struct('predict', []);
end
has_local = ~isempty(surrogates.predict);   % lokale Attribution moeglich?

% --- Farben (wie in plot_results.m) ---
bg = cfg.bg; fg = cfg.fg; gc = cfg.grid; c_ax = cfg.c_ax;
c_base = cfg.col_baseline; c_opt = cfg.col_optimal; c_par = cfg.col_pareto;
c_FL = cfg.col_FL; c_FR = cfg.col_FR; c_RL = cfg.col_RL; c_RR = cfg.col_RR;

% --- Viz-Defaults (ueberschreibbar via cfg.viz) ---
if ~isfield(cfg,'viz'); cfg.viz = struct(); end
viz_cfg = cfg.viz;
if ~isfield(viz_cfg,'pareto_labels'); viz_cfg.pareto_labels = {'Grip gesamt [N] (min)','RH-Varianz [mm] (min)'}; end
if ~isfield(viz_cfg,'attr_kpi_names'); viz_cfg.attr_kpi_names = {'grip\_total','rh\_var\_mean','roll\_grad'}; end   % 3 GA-Ziele
c_pos = [0.30 0.80 0.45];   % gruen = Verbesserung
c_neg = [0.90 0.35 0.35];   % rot   = Verschlechterung
c_neu = [0.60 0.60 0.60];   % grau  = neutral/informativ

%% VORBERECHNUNGEN

param_names = cfg.opt.param_names;
param_units = cfg.opt.param_units;
act = res.active_idx(:)';                    % aktive Parameter-Indizes (Zeilenvektor)
n_act = numel(act);

% Attributionsmatrizen berechnen (global immer, lokal nur mit Surrogat)
attr = compute_attribution(res, act, viz_cfg, surrogates, has_local);

viz = struct();
viz.attr = attr;

%% VISUALISIERUNG

% =====================================================================
%% FIG 1 - ERGEBNIS-UEBERBLICK
% =====================================================================
fig1 = figure('Name','Ergebnis-Ueberblick','Color',bg,'Position',[40 60 1400 720]);
viz.fig_overview = fig1;
tl1 = tiledlayout(fig1, 2, 2, 'TileSpacing','compact','Padding','compact');

% --- (a) KPI-Scorecard (linke Spalte, volle Hoehe) ---
% Richtung (higher_better): +1 hoeher=besser, -1 niedriger=besser, 0 neutral/info.
% HINWEIS: Richtungen sind Annahmen der Interpretation -> bei Bedarf anpassen.
kpi_def = {
  'Grip/Last', 'grip_F',              'Grip VA (Fz-Var)',  'N',     -1;
  'Grip/Last', 'grip_R',              'Grip HA (Fz-Var)',  'N',     -1;
  'Grip/Last', 'Fz_rms_total',        'Fz-RMS gesamt',     'N',     -1;
  'Lage/Ride', 'rh_var_f',            'RH-Varianz VA',     'mm',    -1;
  'Lage/Ride', 'rh_var_r',            'RH-Varianz HA',     'mm',    -1;
  'Lage/Ride', 'roll_grad',           'Rollgradient',      'deg/g', -1;
  'Lage/Ride', 'pitch_grad',          'Nickgradient',      'deg/g', -1;
  'Lage/Ride', 'heave_rms',           'Hub-RMS',           'mm',    -1;
  'Reifen',    'util_max',            'Auslastung max',    '-',     -1;
  'Reifen',    'util_p95',            'Auslastung P95',    '-',     -1;
  'Reifen',    'slip_time_pct',       'Slip-Zeit',         '%',     -1;
  'Komfort',   'comfort',             'Diskomfort',        'm/s2',  -1;
  'Kinematik', 'camber_rms_FL',       'Sturz-Var VA (FL)', 'deg',   -1;
  'Aero',      'aero_downforce_mean', 'Downforce',         'N',     +1;
  'Aero',      'aero_balance_mean',   'Aero-Balance',      '%',      0;
};
ax1a = nexttile(tl1, 1, [2 1]);
draw_scorecard(ax1a, kpi_def, res.kpis_base, res.kpis_best, fg, c_ax, gc, c_pos, c_neg, c_neu);
title(ax1a, 'KPI-Scorecard  (Baseline \rightarrow Optimal)', 'Color',fg,'FontWeight','bold');

% --- (b) Pareto-Front ---
ax1b = nexttile(tl1, 2);
draw_pareto(ax1b, res, viz_cfg, fg, c_ax, gc, c_opt);

% --- (c) Ziel-/Score-Vergleich ---
ax1c = nexttile(tl1, 4);
draw_score_compare(ax1c, res, viz_cfg, fg, c_ax, gc, c_base, c_opt);

title(tl1, sprintf('Ergebnis-Ueberblick  |  Score %.3f \\rightarrow %.3f', ...
      gf(res.kpis_base,'score'), gf(res.kpis_best,'score')), ...
      'Color',fg,'FontSize',13,'FontWeight','bold');

% =====================================================================
%% FIG 2 - WODURCH (Parameter-Delta + Attribution)
% =====================================================================
fig2 = figure('Name','Wodurch','Color',bg,'Position',[60 60 1500 720]);
viz.fig_attribution = fig2;
n_tiles = iff(has_local, 3, 2);
tl2 = tiledlayout(fig2, 1, n_tiles, 'TileSpacing','compact','Padding','compact');

% --- (a) Parameter-Delta nominal -> best (physikalische Einheiten) ---
ax2a = nexttile(tl2, 1);
draw_param_delta(ax2a, res, param_names, param_units, act, fg, c_ax, gc, c_par, c_opt);

% --- (b) Attributions-Heatmap GLOBAL ---
cmax = attr.cmax;
ax2b = nexttile(tl2, 2);
draw_attr_heatmap(ax2b, attr.B_glob, attr.R2_glob, param_names(act), ...
                  viz_cfg.attr_kpi_names, 'GLOBAL (LHS-Regression)', ...
                  cmax, fg, c_ax);

% --- (c) Attributions-Heatmap LOKAL (nur mit Surrogat) ---
if has_local
    ax2c = nexttile(tl2, 3);
    draw_attr_heatmap(ax2c, attr.B_loc, [], param_names(act), ...
                      viz_cfg.attr_kpi_names, 'LOKAL (Surrogat-Gradient um x\_best)', ...
                      cmax, fg, c_ax);
end

title(tl2, 'Wodurch: Parameter-Aenderung und ihre Wirkung auf die KPIs', ...
      'Color',fg,'FontSize',13,'FontWeight','bold');

% =====================================================================
%% FIG 3 - FAHRVERHALTEN (Modal + Balance)
% =====================================================================
fig3 = figure('Name','Fahrverhalten','Color',bg,'Position',[80 60 1300 720]);
viz.fig_behaviour = fig3;
tl3 = tiledlayout(fig3, 2, 2, 'TileSpacing','compact','Padding','compact');

mb = res.modal_base; mo = res.modal_best;

% --- (a) Ride-Frequenzen + Flat-Ride ---
ax3a = nexttile(tl3, 1);
draw_ride_freq(ax3a, mb, mo, fg, c_ax, gc, c_base, c_opt);

% --- (b) Daempfungsgrade je Mode ---
ax3b = nexttile(tl3, 2);
draw_zeta_modes(ax3b, mb, mo, fg, c_ax, gc, c_base, c_opt);

% --- (c) Aufbau-Gradienten ---
ax3c = nexttile(tl3, 3);
draw_body_gradients(ax3c, res.kpis_base, res.kpis_best, fg, c_ax, gc, c_base, c_opt);

% --- (d) Balance-Kompass ---
ax3d = nexttile(tl3, 4);
draw_balance(ax3d, res, mb, mo, fg, c_ax, gc, c_base, c_opt);

title(tl3, 'Fahrverhalten: Modalverhalten und Balance', ...
      'Color',fg,'FontSize',13,'FontWeight','bold');

% =====================================================================
%% FIG 4 - ZUSTANDSGROESSEN / DEBUG (base vs best, Zeitverlauf)
% =====================================================================
fig4 = figure('Name','Zustandsgroessen (Debug)','Color',bg,'Position',[100 40 1400 800]);
viz.fig_states = fig4;
draw_state_debug(fig4, res, fg, c_ax, gc, c_base, c_opt, c_FL, c_FR, c_RL, c_RR);

n_figs = 3 + 1;
fprintf('=== plot_result_dashboard: %d Figures erstellt (lokale Attribution: %s)\n\n', ...
        n_figs, iff(has_local,'ja','nein (kein Surrogat uebergeben)'));

end


%% ====================================================================
%% LOKALE HILFSFUNKTIONEN
%% ====================================================================

function attr = compute_attribution(res, act, viz_cfg, surrogates, has_local)
%% Globale (LHS-Regression) und lokale (Surrogat-Gradient) Attribution auf die
% 3 aggregierten GA-Ziele: grip_total = grip_F+grip_R, rh_var_mean =
% (rh_var_f+rh_var_r)/2, roll_grad. Beide Matrizen sind standardisiert
% (dY/dX * sx/sy) und direkt vergleichbar. Zeilen=aktive Param, Spalten=Ziele.

    % Aggregierte Ziele aus Y_mat. Spaltenkonvention aus run_optimization:
    % 1 grip_F, 2 grip_R, 3 rh_var_f, 4 rh_var_r, 5 bottoming(=0), 6 roll_grad.
    Yt = [ res.Y_mat(:,1) + res.Y_mat(:,2), ...
           (res.Y_mat(:,3) + res.Y_mat(:,4)) / 2, ...
           res.Y_mat(:,6) ];
    Xa = res.X_valid(:, act);            % [N x n_act] physikalisch
    n_act = numel(act);
    n_tgt = size(Yt, 2);

    sx = std(Xa, 0, 1);   sx(sx == 0) = 1;    % Schutz gegen konstante Spalten
    sy = std(Yt, 0, 1);   sy(sy == 0) = 1;

    % --- GLOBAL: standardisierte Regressionskoeffizienten je Ziel ---
    Zx = (Xa - mean(Xa,1)) ./ sx;
    B_glob  = zeros(n_act, n_tgt);
    R2_glob = zeros(1, n_tgt);
    for k = 1:n_tgt
        zy = (Yt(:,k) - mean(Yt(:,k))) / sy(k);
        A  = [ones(size(Zx,1),1), Zx];
        b  = A \ zy;                          % OLS ohne Toolbox
        B_glob(:,k) = b(2:end);
        yhat = A * b;
        sse = sum((zy - yhat).^2);
        sst = sum((zy - mean(zy)).^2) + eps;
        R2_glob(k) = 1 - sse/sst;
    end

    % --- LOKAL: Surrogat-Gradient um x_best (voller Vektor, aktive Param variiert) ---
    B_loc = [];
    if has_local
        x0 = res.x_best(:)';                  % [1 x n_vars] voll, physikalisch
        rng_p = (res.ub - res.lb);            % Parameterbereich (voll)
        B_loc = zeros(n_act, n_tgt);
        for jj = 1:n_act
            p = act(jj);
            h = 0.01 * rng_p(p);   if h == 0; h = 1e-6; end   % 1% des Bereichs
            xp = x0; xp(p) = xp(p) + h;
            xm = x0; xm(p) = xm(p) - h;
            yp = surrogates.predict(xp);   yp = yp(:)';
            ym = surrogates.predict(xm);   ym = ym(:)';
            grad = (yp - ym) / (2*h);         % dY/dX_p [1 x n_tgt]
            B_loc(jj,:) = grad .* sx(jj) ./ sy;   % standardisieren wie global
        end
    end

    cmax = max([abs(B_glob(:)); abs(B_loc(:)); eps]);   % gemeinsame Farbskala
    attr = struct('B_glob',B_glob,'R2_glob',R2_glob,'B_loc',B_loc,'cmax',cmax);
end


function draw_scorecard(ax, kpi_def, kb, ko, fg, c_ax, gc, c_pos, c_neg, c_neu)
%% Horizontale Verbesserungs-Balken, nach Kategorie gruppiert.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    n = size(kpi_def,1);
    y = n + numel(unique(kpi_def(:,1)));   % Startcursor (Platz fuer Kategorie-Header)
    cats_done = {};
    yt = []; ytl = {};
    for i = 1:n
        cat = kpi_def{i,1}; fld = kpi_def{i,2}; lbl = kpi_def{i,3};
        unit = kpi_def{i,4}; hb = kpi_def{i,5};
        if ~any(strcmp(cats_done, cat))            % Kategorie-Header setzen
            text(ax, 0, y, ['\bf' cat], 'Color',fg,'FontSize',10, ...
                 'HorizontalAlignment','center');
            cats_done{end+1} = cat; %#ok<AGROW>
            y = y - 1;
        end
        b = gf(kb, fld); o = gf(ko, fld);
        if isnan(b) || isnan(o); y = y - 1; continue; end
        if hb == 0
            impr = (o - b) / (abs(b)+eps) * 100;   % nur Betrag, neutrale Farbe
            col = c_neu;
        else
            impr = hb * (o - b) / (abs(b)+eps) * 100;   % >0 = besser
            col = iff(impr >= 0, c_pos, c_neg);
        end
        barh(ax, y, impr, 0.6, 'FaceColor',col,'EdgeColor','none','FaceAlpha',0.9);
        txt = sprintf('%.3g\\rightarrow%.3g %s', b, o, unit);
        xa = impr + sign(impr+eps)*2;
        text(ax, xa, y, txt, 'Color',fg,'FontSize',7.5, ...
             'HorizontalAlignment', iff(impr>=0,'left','right'));
        yt(end+1) = y; ytl{end+1} = lbl; %#ok<AGROW>
        y = y - 1;
    end
    xline(ax, 0, 'Color',[0.75 0.75 0.75],'LineWidth',1.1);
    set(ax,'YTick',flip(yt),'YTickLabel',flip(ytl),'FontSize',8);
    ylim(ax, [y+0.5, n + numel(cats_done) + 0.5]);
    xlim(ax, [-115 115]);
    xlabel(ax, 'Verbesserung [%]  (gruen = besser)', 'Color',fg);
    grid(ax,'on');
end


function draw_pareto(ax, res, viz_cfg, fg, c_ax, gc, c_opt)
%% Pareto-Front (2 Ziele) mit Utopia-Distanz-Faerbung, best/verify markiert.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    f = res.f_pareto;
    fn = (f - min(f,[],1)) ./ (max(f,[],1) - min(f,[],1) + eps);
    ud = sqrt(sum(fn.^2, 2));   % Distanz zum Utopiapunkt (klein = besser)
    scatter(ax, f(:,1), f(:,2), 55, ud, 'filled', 'MarkerFaceAlpha',0.85);
    colormap(ax, parula);

    % Verifikationspunkte
    if isfield(res,'verify_results')
        for i = 1:numel(res.verify_results)
            vr = res.verify_results(i);
            if isfield(vr,'f_surr') && numel(vr.f_surr) >= 2
                plot(ax, vr.f_surr(1), vr.f_surr(2), 'o', 'MarkerSize',9, ...
                     'MarkerEdgeColor',fg,'LineWidth',1.2);
            end
        end
    end
    % Gewaehlter Punkt (best_vi)
    if isfield(res,'best_vi') && isfield(res,'verify_results')
        bv = res.best_vi;
        if bv >= 1 && bv <= numel(res.verify_results) && isfield(res.verify_results(bv),'f_surr')
            fb = res.verify_results(bv).f_surr;
            plot(ax, fb(1), fb(2), 'p', 'MarkerSize',18, 'MarkerFaceColor',c_opt, ...
                 'MarkerEdgeColor',fg,'LineWidth',1.5);
            text(ax, fb(1), fb(2), '  x\_best', 'Color',fg,'FontWeight','bold');
        end
    end
    xlabel(ax, viz_cfg.pareto_labels{1}, 'Color',fg);
    ylabel(ax, viz_cfg.pareto_labels{2}, 'Color',fg);
    title(ax, sprintf('Pareto-Front (%d Punkte)', size(f,1)), 'Color',fg,'FontWeight','bold');
    cb = colorbar(ax,'Color',fg); cb.Label.String = 'Utopia-Distanz'; cb.Label.Color = fg;
    grid(ax,'on');
end


function draw_score_compare(ax, res, viz_cfg, fg, c_ax, gc, c_base, c_opt)
%% Ziel-Werte + Score Baseline vs Optimal.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    names = {viz_cfg.pareto_labels{1}, viz_cfg.pareto_labels{2}, 'Score'};
    % Ziele der Baseline liegen nicht direkt vor -> nur Score vergleichbar,
    % Ziele als Optimal-Wert (aus best_vi) informativ.
    sb = gf(res.kpis_base,'score'); so = gf(res.kpis_best,'score');
    vals_b = [NaN, NaN, sb];
    vals_o = [NaN, NaN, so];
    if isfield(res,'best_vi') && isfield(res,'verify_results')
        bv = res.best_vi;
        if isfield(res.verify_results(bv),'f_surr')
            fb = res.verify_results(bv).f_surr;
            vals_o(1:2) = fb(1:2);
        end
    end
    x = 1:3; w = 0.35;
    bar(ax, x - w/2, vals_b, w, 'FaceColor',c_base,'EdgeColor','none','FaceAlpha',0.9);
    bar(ax, x + w/2, vals_o, w, 'FaceColor',c_opt, 'EdgeColor','none','FaceAlpha',0.9);
    set(ax,'XTick',x,'XTickLabel',names,'FontSize',8);
    ylabel(ax,'Wert','Color',fg);
    title(ax, sprintf('Score %.3f \\rightarrow %.3f (%+.1f%%)', sb, so, (so-sb)/sb*100), ...
          'Color',fg,'FontWeight','bold');
    legend(ax, {'Baseline','Optimal'}, 'Color',c_ax,'TextColor',fg,'Location','best','FontSize',8);
    grid(ax,'on');
end


function draw_param_delta(ax, res, pnames, punits, act, fg, c_ax, gc, c_par, c_opt)
%% Parameter-Aenderung Referenz -> best in physikalischen Einheiten, sortiert.
% Referenz = res.x_base (echtes Baseline-Setup) falls vorhanden, sonst nominal_all.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    if isfield(res,'x_base') && ~isempty(res.x_base)
        ref = res.x_base(:);  ref_lbl = 'Baseline';
    else
        ref = res.nominal_all(:);  ref_lbl = 'Bereichsmitte';
    end
    nom = ref(act);  xb = res.x_best(:);  xba = xb(act);
    rng_p = (res.ub(act) - res.lb(act)) + eps;  rng_p = rng_p(:);
    d_norm = (xba(:) - nom(:)) ./ rng_p * 100;    % % des Bereichs (fuer Sortierung)
    [~, si] = sort(abs(d_norm), 'ascend');        % kleinste unten
    y = 1:numel(si);
    for i = 1:numel(si)
        j = si(i);
        col = iff(d_norm(j) >= 0, c_opt, c_par);
        barh(ax, y(i), d_norm(j), 0.62, 'FaceColor',col,'EdgeColor','none','FaceAlpha',0.9);
        txt = sprintf('%.3g\\rightarrow%.3g %s', nom(j), xba(j), punits{act(j)});
        xa = d_norm(j) + sign(d_norm(j)+eps)*2;
        text(ax, xa, y(i), txt, 'Color',fg,'FontSize',7.5, ...
             'HorizontalAlignment', iff(d_norm(j)>=0,'left','right'));
    end
    xline(ax,0,'Color',[0.75 0.75 0.75],'LineWidth',1.1);
    set(ax,'YTick',y,'YTickLabel',strrep(pnames(act(si)),'_','\_'),'FontSize',8);
    ylim(ax,[0.4 numel(si)+0.6]); xlim(ax,[-110 110]);
    xlabel(ax,'Aenderung [% des Bereichs]','Color',fg);
    title(ax,sprintf('Parameter-Delta: %s \\rightarrow Optimal', ref_lbl),'Color',fg,'FontWeight','bold');
    grid(ax,'on');
end


function draw_attr_heatmap(ax, B, R2, pnames, kpinames, ttl, cmax, fg, c_ax)
%% Attributions-Heatmap (Parameter x KPI), divergierende Skala.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg);
    imagesc(ax, B); axis(ax,'ij');
    colormap(ax, make_diverging_cmap(255));
    set(ax, 'CLim', [-cmax cmax]);   % versionsunabhaengig (statt clim/caxis)
    set(ax,'XTick',1:size(B,2),'XTickLabel',kpinames, ...
        'YTick',1:size(B,1),'YTickLabel',strrep(pnames,'_','\_'),'FontSize',8);
    % Werte annotieren
    for r = 1:size(B,1)
        for c = 1:size(B,2)
            if abs(B(r,c)) > 0.05*cmax
                text(ax, c, r, sprintf('%.2f',B(r,c)), 'Color',fg, ...
                     'FontSize',7,'HorizontalAlignment','center');
            end
        end
    end
    % R2 als Kopfzeile (nur global)
    if ~isempty(R2)
        for c = 1:size(B,2)
            text(ax, c, 0.35, sprintf('R^2=%.2f',R2(c)), 'Color',fg, ...
                 'FontSize',7.5,'HorizontalAlignment','center','FontWeight','bold');
        end
    end
    cb = colorbar(ax,'Color',fg); cb.Label.String = 'std. Sensitivitaet'; cb.Label.Color = fg;
    title(ax, ttl, 'Color',fg,'FontWeight','bold');
end


function draw_ride_freq(ax, mb, mo, fg, c_ax, gc, c_base, c_opt)
%% Ride-Frequenzen VA/HA + Flat-Ride-Hinweis.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    fb = [gf(mb,'f_ride_f'), gf(mb,'f_ride_r')];
    fo = [gf(mo,'f_ride_f'), gf(mo,'f_ride_r')];
    x = 1:2; w = 0.35;
    bar(ax, x-w/2, fb, w, 'FaceColor',c_base,'EdgeColor','none','FaceAlpha',0.9);
    bar(ax, x+w/2, fo, w, 'FaceColor',c_opt, 'EdgeColor','none','FaceAlpha',0.9);
    set(ax,'XTick',x,'XTickLabel',{'VA','HA'},'FontSize',9);
    ylabel(ax,'Ride-Frequenz [Hz]','Color',fg);
    rb = gf(mb,'flat_ride_ratio'); ro = gf(mo,'flat_ride_ratio');
    fr_hint = iff(ro < 1, 'Heck weicher (nickfreudig)', 'Flat-Ride (Heck steifer)');
    title(ax, sprintf('Ride-Frequenzen  |  Flat-Ride %.2f\\rightarrow%.2f (%s)', rb, ro, fr_hint), ...
          'Color',fg,'FontWeight','bold','FontSize',9);
    legend(ax,{'Baseline','Optimal'},'Color',c_ax,'TextColor',fg,'Location','best','FontSize',8);
    grid(ax,'on');
end


function draw_zeta_modes(ax, mb, mo, fg, c_ax, gc, c_base, c_opt)
%% Daempfungsgrade je Mode.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    flds = {'zeta_heave','zeta_pitch','zeta_roll','zeta_ride_f','zeta_ride_r'};
    lbls = {'Heave','Pitch','Roll','Ride VA','Ride HA'};
    zb = cellfun(@(f) gf(mb,f), flds);
    zo = cellfun(@(f) gf(mo,f), flds);
    x = 1:numel(flds); w = 0.35;
    bar(ax, x-w/2, zb, w, 'FaceColor',c_base,'EdgeColor','none','FaceAlpha',0.9);
    bar(ax, x+w/2, zo, w, 'FaceColor',c_opt, 'EdgeColor','none','FaceAlpha',0.9);
    yline(ax, 0.7, 'Color',[0.7 0.7 0.7],'LineStyle',':','Label','\zeta=0.7');
    set(ax,'XTick',x,'XTickLabel',lbls,'FontSize',8);
    ylabel(ax,'Daempfungsgrad \zeta [-]','Color',fg);
    title(ax,'Modale Daempfung','Color',fg,'FontWeight','bold');
    legend(ax,{'Baseline','Optimal'},'Color',c_ax,'TextColor',fg,'Location','best','FontSize',8);
    grid(ax,'on');
end


function draw_body_gradients(ax, kb, ko, fg, c_ax, gc, c_base, c_opt)
%% Roll-/Nickgradient Baseline vs Optimal.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    flds = {'roll_grad','pitch_grad'};
    lbls = {'Rollgradient','Nickgradient'};
    gb = cellfun(@(f) gf(kb,f), flds);
    go = cellfun(@(f) gf(ko,f), flds);
    x = 1:numel(flds); w = 0.35;
    bar(ax, x-w/2, gb, w, 'FaceColor',c_base,'EdgeColor','none','FaceAlpha',0.9);
    bar(ax, x+w/2, go, w, 'FaceColor',c_opt, 'EdgeColor','none','FaceAlpha',0.9);
    for i = 1:numel(flds)
        text(ax, x(i), max(gb(i),go(i))*1.03, sprintf('%+.0f%%',(go(i)-gb(i))/gb(i)*100), ...
             'Color',fg,'FontSize',8,'HorizontalAlignment','center');
    end
    set(ax,'XTick',x,'XTickLabel',lbls,'FontSize',9);
    ylabel(ax,'Gradient [deg/g]','Color',fg);
    title(ax,'Aufbau-Gradienten','Color',fg,'FontWeight','bold');
    legend(ax,{'Baseline','Optimal'},'Color',c_ax,'TextColor',fg,'Location','best','FontSize',8);
    grid(ax,'on');
end


function draw_balance(ax, res, mb, mo, fg, c_ax, gc, c_base, c_opt)
%% Balance-Kompass: mech. Rollsteifigkeit / Aero / Reifenauslastung (Front-Anteil %).
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    kb = res.kpis_base; ko = res.kpis_best;
    % Front-Anteile in %
    mech_b = gf(mb,'roll_stiffness_dist_f'); mech_o = gf(mo,'roll_stiffness_dist_f');
    aero_b = gf(kb,'aero_balance_mean');      aero_o = gf(ko,'aero_balance_mean');
    uf_b = gf(kb,'util_F'); ur_b = gf(kb,'util_R');
    uf_o = gf(ko,'util_F'); ur_o = gf(ko,'util_R');
    tire_b = uf_b/(uf_b+ur_b+eps)*100; tire_o = uf_o/(uf_o+ur_o+eps)*100;
    vb = [mech_b, aero_b, tire_b];
    vo = [mech_o, aero_o, tire_o];
    lbls = {'Mech. Rollsteif.','Aero-Balance','Reifenauslastung'};
    y = 1:3;
    plot(ax, vb, y, 's','MarkerSize',11,'MarkerFaceColor',c_base,'MarkerEdgeColor',fg,'LineWidth',1);
    plot(ax, vo, y, 'p','MarkerSize',15,'MarkerFaceColor',c_opt,'MarkerEdgeColor',fg,'LineWidth',1);
    for i=1:3
        plot(ax,[vb(i) vo(i)],[y(i) y(i)],'-','Color',[fg 0.4],'LineWidth',1);
    end
    xline(ax,50,'Color',[0.7 0.7 0.7],'LineStyle','--','Label','50% (neutral)','LabelColor',fg);
    set(ax,'YTick',y,'YTickLabel',lbls,'FontSize',9);
    ylim(ax,[0.5 3.5]); xlim(ax,[40 70]);
    xlabel(ax,'Front-Anteil [%]  (>50 = frontlastig)','Color',fg);
    title(ax,'Balance-Kompass','Color',fg,'FontWeight','bold');
    legend(ax,{'Baseline','Optimal'},'Color',c_ax,'TextColor',fg,'Location','best','FontSize',8);
    grid(ax,'on');
end


function draw_state_debug(fig, res, fg, c_ax, gc, c_base, c_opt, c_FL, c_FR, c_RL, c_RR)
%% Rohe Zustandsgroessen base vs best (eigene Zeitvektoren, ggf. versch. Laenge).
    tl = tiledlayout(fig, 3, 2, 'TileSpacing','compact','Padding','compact');
    db = res.derived_base_full; do_ = res.derived_best_full;
    tb = res.t_base_full(:); to = res.t_best_full(:);

    % Einheiten-Annahme: z_s [m], phi/theta [rad], ddz_s [m/s2], dz_rel [m] (SI).
    % Bei abweichenden Einheiten die Faktoren unten anpassen.
    plot_ts(nexttile(tl,1), tb, db.z_s(:)*1000,  to, do_.z_s(:)*1000, ...
            'Aufbau-Hub z\_s [mm]', c_base, c_opt, fg, c_ax, gc, true);
    plot_ts(nexttile(tl,2), tb, rad2deg(db.phi(:)), to, rad2deg(do_.phi(:)), ...
            'Rollwinkel \phi [deg]', c_base, c_opt, fg, c_ax, gc, false);
    plot_ts(nexttile(tl,3), tb, rad2deg(db.theta(:)), to, rad2deg(do_.theta(:)), ...
            'Nickwinkel \theta [deg]', c_base, c_opt, fg, c_ax, gc, false);
    plot_ts(nexttile(tl,4), tb, db.ddz_s(:), to, do_.ddz_s(:), ...
            'Aufbau-Beschl. ddz\_s [m/s^2]', c_base, c_opt, fg, c_ax, gc, false);

    % Einfederung pro Ecke: + = einfedern (Vorzeichen wie in plot_results Fig7)
    axVA = nexttile(tl,5);
    set(axVA,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(axVA,'on');
    plot(axVA, tb, -db.dz_rel_FL(:)*1000, '--','Color',[c_base 0.6],'DisplayName','FL base');
    plot(axVA, tb, -db.dz_rel_FR(:)*1000, ':','Color',[c_base 0.6],'DisplayName','FR base');
    plot(axVA, to, -do_.dz_rel_FL(:)*1000,'-','Color',c_FL,'LineWidth',1.1,'DisplayName','FL opt');
    plot(axVA, to, -do_.dz_rel_FR(:)*1000,'-','Color',c_FR,'LineWidth',1.1,'DisplayName','FR opt');
    xlabel(axVA,'Zeit [s]','Color',fg); ylabel(axVA,'Einfederung VA [mm]','Color',fg);
    legend(axVA,'Color',c_ax,'TextColor',fg,'FontSize',7,'Location','best'); grid(axVA,'on');

    axHA = nexttile(tl,6);
    set(axHA,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(axHA,'on');
    plot(axHA, tb, -db.dz_rel_RL(:)*1000, '--','Color',[c_base 0.6],'DisplayName','RL base');
    plot(axHA, tb, -db.dz_rel_RR(:)*1000, ':','Color',[c_base 0.6],'DisplayName','RR base');
    plot(axHA, to, -do_.dz_rel_RL(:)*1000,'-','Color',c_RL,'LineWidth',1.1,'DisplayName','RL opt');
    plot(axHA, to, -do_.dz_rel_RR(:)*1000,'-','Color',c_RR,'LineWidth',1.1,'DisplayName','RR opt');
    xlabel(axHA,'Zeit [s]','Color',fg); ylabel(axHA,'Einfederung HA [mm]','Color',fg);
    legend(axHA,'Color',c_ax,'TextColor',fg,'FontSize',7,'Location','best'); grid(axHA,'on');

    title(tl, 'Zustandsgroessen: Baseline vs. Optimal  (Zeitvektoren ggf. versch. Laenge)', ...
          'Color',fg,'FontSize',12,'FontWeight','bold');
end


function plot_ts(ax, tb, yb, to, yo, lbl, c_base, c_opt, fg, c_ax, gc, show_leg)
%% Ein Zeitreihen-Paar (base gestrichelt, opt durchgezogen) mit RMS-Annotation.
    set(ax,'Color',c_ax,'XColor',fg,'YColor',fg,'GridColor',gc); hold(ax,'on');
    plot(ax, tb, yb, '-','Color',[c_base 0.55],'LineWidth',0.8,'DisplayName','Baseline');
    plot(ax, to, yo, '-','Color',c_opt,'LineWidth',1.1,'DisplayName','Optimal');
    yline(ax,0,'Color',[0.5 0.5 0.5],'LineStyle',':');
    text(ax, 0.98, 0.95, sprintf('RMS %.3g\\rightarrow%.3g', rms_(yb), rms_(yo)), ...
         'Units','normalized','Color',fg,'FontSize',8,'HorizontalAlignment','right', ...
         'VerticalAlignment','top','BackgroundColor',c_ax);
    xlabel(ax,'Zeit [s]','Color',fg); ylabel(ax,lbl,'Color',fg); grid(ax,'on');
    if show_leg; legend(ax,'Color',c_ax,'TextColor',fg,'Location','best','FontSize',8); end
end


function cmap = make_diverging_cmap(n)
%% Blau-Weiss-Rot fuer signierte Sensitivitaeten (kein Toolbox noetig).
    m = floor(n/2);
    b = [linspace(0.20,1,m)', linspace(0.45,1,m)', linspace(0.85,1,m)'];
    r = [linspace(1,0.85,n-m)', linspace(1,0.25,n-m)', linspace(1,0.25,n-m)'];
    cmap = [b; r];
end


function v = gf(s, name)
%% Feld sicher lesen (NaN falls fehlend), als double.
    if isstruct(s) && isfield(s, name); v = double(s.(name)); else; v = NaN; end
end


function r = rms_(x)
    x = x(~isnan(x)); if isempty(x); r = NaN; else; r = sqrt(mean(x.^2)); end
end


function s = iff(cond, a, b)
    if cond; s = a; else; s = b; end
end
