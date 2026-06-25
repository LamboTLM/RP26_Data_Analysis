function style(varargin)
%RP.STYLE  Apply Dynamics Regensburg e.V. brand theme as MATLAB global defaults
%
%   RP.style()           Dark mode (default)
%   RP.style('dark')     Dark mode
%   RP.style('light')    Light mode (printing)
%   RP.style('reset')    Restore MATLAB factory defaults
%
%   Call once at the top of a script or in startup.m.
%
%   IMPORTANT — addpath:
%     addpath('C:\...\your_project')   % folder that CONTAINS +RP
%     NOT: addpath('C:\...\+RP')       % this causes a MATLAB warning
%
%   FIX vs. previous version:
%     - DefaultTextInterpreter / DefaultLegendInterpreter are NOT set
%       globally — this caused "SceneNode" warnings from MATLAB internals.
%       LaTeX interpreter is set only on axes-specific properties.
%     - set(ax,'XLabel',text(...)) removed — illegal MATLAB syntax.
%
% Autor: Lambo || Datum: 05.05.2026

    mode = 'dark';
    if nargin > 0, mode = lower(varargin{1}); end

    if strcmp(mode, 'reset')
        rp_reset(); return;
    end

    c    = RP.colors(mode);
    font = RP.resolveFont();
    rp_apply(c, font);

    fprintf('[RP] Dynamics E.V. ''%s'' theme active. Font: %s\n', mode, font);
    fprintf('[RP] Reset with RP.style(''reset'') when done.\n');
end


function rp_apply(c, font)
    g = groot;

    % Figure
    set(g, 'DefaultFigureColor',                     c.bg);
    set(g, 'DefaultFigurePaperPositionMode',         'auto');

    % Axes background & frame
    set(g, 'DefaultAxesColor',                       c.axesBg);
    set(g, 'DefaultAxesBox',                         'off');
    set(g, 'DefaultAxesLayer',                       'top');

    % Axis colors
    set(g, 'DefaultAxesXColor',                      c.axis);
    set(g, 'DefaultAxesYColor',                      c.axis);
    set(g, 'DefaultAxesZColor',                      c.axis);

    % Grid
    set(g, 'DefaultAxesXGrid',                       'on');
    set(g, 'DefaultAxesYGrid',                       'on');
    set(g, 'DefaultAxesZGrid',                       'on');
    set(g, 'DefaultAxesGridColor',                   c.grid);
    set(g, 'DefaultAxesMinorGridColor',              c.gridMinor);
    set(g, 'DefaultAxesGridAlpha',                   1.0);
    set(g, 'DefaultAxesMinorGridAlpha',              1.0);
    set(g, 'DefaultAxesGridLineStyle',               '-');
    set(g, 'DefaultAxesMinorGridLineStyle',          ':');

    % Ticks
    set(g, 'DefaultAxesTickDir',                     'out');
    set(g, 'DefaultAxesTickLength',                  [0.008, 0.008]);

    % Font — Segoe UI is the official Dynamics body font
    set(g, 'DefaultAxesFontName',                    font);
    set(g, 'DefaultAxesFontSize',                    11);
    set(g, 'DefaultAxesFontWeight',                  'normal');
    set(g, 'DefaultAxesTitleFontSizeMultiplier',     1.25);
    set(g, 'DefaultAxesTitleFontWeight',             'bold');
    set(g, 'DefaultAxesLabelFontSizeMultiplier',     1.05);
    set(g, 'DefaultAxesLineWidth',                   1.0);

    % ColorOrder
    set(g, 'DefaultAxesColorOrder',                  c.lineColors);
    set(g, 'DefaultAxesColorOrderIndex',             1);

    % Tick label interpreter — LaTeX for axis ticks only (safe globally)
    % NOTE: DefaultTextInterpreter is intentionally NOT set here.
    %       Setting it globally causes MATLAB internal SceneNode warnings
    %       (toolbar text, figure titles, etc. all break).
    %       Set title/label interpreters per-axes via RP.newFig or RP.styleAxes.
    set(g, 'DefaultAxesTickLabelInterpreter',        'latex');

    % Lines
    set(g, 'DefaultLineLineWidth',                   2.0);
    set(g, 'DefaultLineMarkerSize',                  6);

    % Text objects (annotations, text() calls) — keep 'none' to be safe
    set(g, 'DefaultTextColor',                       c.text);
    set(g, 'DefaultTextFontName',                    font);
    set(g, 'DefaultTextFontSize',                    11);

    % Legend
    set(g, 'DefaultLegendColor',                     c.legendBg);
    set(g, 'DefaultLegendTextColor',                 c.text);
    set(g, 'DefaultLegendEdgeColor',                 c.legendEdge);
    set(g, 'DefaultLegendFontSize',                  10);
    set(g, 'DefaultLegendFontName',                  font);

    % Scatter
    set(g, 'DefaultScatterLineWidth',                1.2);
end


function rp_reset()
    g = groot;
    props = {
        'DefaultFigureColor',              'DefaultFigurePaperPositionMode',
        'DefaultAxesColor',                'DefaultAxesBox',
        'DefaultAxesLayer',                'DefaultAxesXColor',
        'DefaultAxesYColor',               'DefaultAxesZColor',
        'DefaultAxesXGrid',                'DefaultAxesYGrid',
        'DefaultAxesZGrid',                'DefaultAxesGridColor',
        'DefaultAxesMinorGridColor',       'DefaultAxesGridAlpha',
        'DefaultAxesMinorGridAlpha',       'DefaultAxesGridLineStyle',
        'DefaultAxesMinorGridLineStyle',   'DefaultAxesTickDir',
        'DefaultAxesTickLength',           'DefaultAxesFontName',
        'DefaultAxesFontSize',             'DefaultAxesFontWeight',
        'DefaultAxesTitleFontSizeMultiplier','DefaultAxesTitleFontWeight',
        'DefaultAxesLabelFontSizeMultiplier','DefaultAxesLineWidth',
        'DefaultAxesColorOrder',           'DefaultAxesColorOrderIndex',
        'DefaultAxesTickLabelInterpreter', 'DefaultLineLineWidth',
        'DefaultLineMarkerSize',           'DefaultTextColor',
        'DefaultTextFontName',             'DefaultTextFontSize',
        'DefaultLegendColor',              'DefaultLegendTextColor',
        'DefaultLegendEdgeColor',          'DefaultLegendFontSize',
        'DefaultLegendFontName',           'DefaultScatterLineWidth',
    };
    for i = 1:numel(props)
        try; set(g, props{i}, 'factory'); catch; end
    end
    fprintf('[RP] All defaults reset to MATLAB factory settings.\n');
end