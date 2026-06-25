function [fig, ax] = newFig(varargin)
%RP.NEWFIG  Create a Dynamics Regensburg e.V. branded figure
%
%   [fig, ax] = RP.newFig()
%   [fig, ax] = RP.newFig(Name, Value, ...)
%
%   Options:
%     'Title'      string    Plot title (shown in red header bar)
%     'Size'       [w h]     Figure size in pixels (default: [960 620])
%     'Mode'       string    'dark' (default) | 'light'
%     'Subplots'   [r c]     Subplot grid; ax returned as [r×c] array
%     'Logo'       logical   Add logo watermark automatically (default: true)
%     'LogoAlpha'  scalar    Watermark opacity (default: 0.10)
%     'LogoScale'  scalar    Logo size (default: 0.45)
%     'LogoPos'    string    'center'|'br'|'bl'|'tr'|'tl' (default:'center')
%     'HeaderBar'  logical   Red Dynamics title bar (default: true)
%     'Tag'        string    Figure Tag for later retrieval
%
%   Returns:
%     fig  — Figure handle
%     ax   — Axes handle, or [r×c] array for subplots
%
%   Logo behaviour:
%     When 'Logo' is true, RP.addLogo() is NOT called immediately —
%     instead an XLim listener is attached to each axes. The logo is
%     drawn automatically the first time plot()/scatter()/etc. changes
%     the axis limits, then the listener removes itself.
%
%     This means xlim/ylim are final when the logo is placed, so sizing
%     and aspect-ratio correction are always correct.
%
%     If you need the logo at a specific moment, or want custom params,
%     set 'Logo', false and call RP.addLogo(ax, ...) manually after plotting.
%
%   Example:
%     [fig, ax] = RP.newFig('Title', 'Fy vs. Slip Angle');
%     plot(ax, SA_deg, Fy_N);      % <-- logo auto-fires here
%     xlabel(ax, '$\alpha$ [deg]');
%     ylabel(ax, '$F_y$ [N]');
%     RP.export(fig, 'Fy_vs_SA');
%
% Autor: Lambo || Datum: 12.05.2026

    p = inputParser; p.CaseSensitive = false;
    addParameter(p, 'Title',     '',        @ischar);
    addParameter(p, 'Size',      [960 620], @(x) isnumeric(x) && numel(x)==2);
    addParameter(p, 'Mode',      'dark',    @ischar);
    addParameter(p, 'Subplots',  [1 1],     @(x) isnumeric(x) && numel(x)==2);
    addParameter(p, 'Logo',      true,      @islogical);
    addParameter(p, 'LogoAlpha', 0.10,      @(x) isnumeric(x) && x>0 && x<=1);
    addParameter(p, 'LogoScale', 0.45,      @(x) isnumeric(x) && x>0 && x<=1);
    addParameter(p, 'LogoPos',   'center',  @ischar);
    addParameter(p, 'HeaderBar', true,      @islogical);
    addParameter(p, 'Tag',       '',        @ischar);
    parse(p, varargin{:});
    opt = p.Results;

    c    = RP.colors(opt.Mode);
    font = RP.resolveFont();

    % ------------------------------------------------------------------ %
    % Figure
    % ------------------------------------------------------------------ %
    scr  = get(0, 'ScreenSize');
    figX = round((scr(3) - opt.Size(1)) / 2);
    figY = round((scr(4) - opt.Size(2)) / 2);

    fig = figure( ...
        'Color',       c.bg, ...
        'Position',    [figX, figY, opt.Size(1), opt.Size(2)], ...
        'Name',        opt.Title, ...
        'NumberTitle', 'off', ...
        'Tag',         opt.Tag, ...
        'Renderer',    'opengl');

    % ------------------------------------------------------------------ %
    % Header bar  (#C72229 Fire Engine Red — mirrors PowerPoint template)
    % ------------------------------------------------------------------ %
    headerH_norm = 0;
    if opt.HeaderBar && ~isempty(opt.Title)
        headerPx     = 34;
        headerH_norm = headerPx / opt.Size(2);

        hp = uipanel(fig, ...
            'BackgroundColor', c.red, ...
            'BorderType',      'none', ...
            'Units',           'normalized', ...
            'Position',        [0, 1-headerH_norm, 1, headerH_norm]);

        uicontrol(hp, ...
            'Style',               'text', ...
            'String',              upper(opt.Title), ...
            'BackgroundColor',     c.red, ...
            'ForegroundColor',     [1 1 1], ...
            'FontName',            font, ...
            'FontSize',            13, ...
            'FontWeight',          'bold', ...
            'HorizontalAlignment', 'left', ...
            'Units',               'normalized', ...
            'Position',            [0.012, 0, 0.98, 1]);
    end

    % ------------------------------------------------------------------ %
    % Tiled layout
    % ------------------------------------------------------------------ %
    nRows = opt.Subplots(1);
    nCols = opt.Subplots(2);

    tl = tiledlayout(fig, nRows, nCols, ...
        'Padding',     'compact', ...
        'TileSpacing', 'compact');

    if headerH_norm > 0
        tl.OuterPosition = [0, 0, 1, 1 - headerH_norm];
    end

    % ------------------------------------------------------------------ %
    % Create and style axes
    % ------------------------------------------------------------------ %
    ax = gobjects(nRows, nCols);
    for idx = 1:(nRows * nCols)
        r   = ceil(idx / nCols);
        col = idx - (r-1)*nCols;
        ax(r, col) = nexttile(tl, idx);
        rp_style_axes(ax(r,col), c, font);
    end

    % ------------------------------------------------------------------ %
    % Logo — attach deferred listener (fires once after first plot call)
    % ------------------------------------------------------------------ %
    if opt.Logo
        logoOpts = struct( ...
            'Alpha', opt.LogoAlpha, ...
            'Scale', opt.LogoScale, ...
            'Pos',   opt.LogoPos);

        for r = 1:nRows
            for col = 1:nCols
                rp_attach_logo_listener(ax(r,col), logoOpts);
            end
        end
    end

    % Unwrap for single-axes case
    if isequal(opt.Subplots, [1 1])
        ax = ax(1,1);
    end
end


% ========================================================================= %
function rp_attach_logo_listener(ax, logoOpts)
%RRP_ATTACH_LOGO_LISTENER
%   Registers a one-shot XLim PostSet listener on ax.
%   Fires RP.addLogo() the first time axis limits change (i.e. after the
%   first plot/scatter/surf call), then immediately removes itself.

    % Guard: don't attach twice
    if isstruct(ax.UserData) && isfield(ax.UserData, 'rpLogoScheduled') ...
            && ax.UserData.rpLogoScheduled
        return;
    end

    % Init UserData
    if ~isstruct(ax.UserData)
        ax.UserData = struct();
    end
    ax.UserData.rpLogoScheduled = true;
    ax.UserData.rpLogoOpts      = logoOpts;

    % Attach listener — callback references ax by handle (not by copy)
    lh = addlistener(ax, 'XLim', 'PostSet', @(~,~) rp_logo_listener_cb(ax));
    ax.UserData.rpLogoListener  = lh;
end


% ========================================================================= %
function rp_logo_listener_cb(ax)
%RRP_LOGO_LISTENER_CB  One-shot callback: draw logo then delete listener

    if ~isvalid(ax), return; end

    % Only fire once
    if ~isstruct(ax.UserData) || ~isfield(ax.UserData, 'rpLogoScheduled') ...
            || ~ax.UserData.rpLogoScheduled
        return;
    end
    ax.UserData.rpLogoScheduled = false;

    % Remove the listener so it never fires again
    if isfield(ax.UserData, 'rpLogoListener') ...
            && isvalid(ax.UserData.rpLogoListener)
        delete(ax.UserData.rpLogoListener);
    end

    % Skip if limits are still default [0 1] — nothing plotted yet
    xl = xlim(ax);
    if isequal(xl, [0 1])
        % Re-arm for next change
        ax.UserData.rpLogoScheduled = true;
        lh = addlistener(ax, 'XLim', 'PostSet', @(~,~) rp_logo_listener_cb(ax));
        ax.UserData.rpLogoListener  = lh;
        return;
    end

    % Draw the logo with stored options
    opts = ax.UserData.rpLogoOpts;
    RP.addLogo(ax, ...
        'Alpha',    opts.Alpha, ...
        'Scale',    opts.Scale, ...
        'Position', opts.Pos);
end


% ========================================================================= %
function rp_style_axes(ax, c, font)
%RRP_STYLE_AXES  Apply brand style to a single axes handle

    set(ax, ...
        'Color',               c.axesBg, ...
        'XColor',              c.axis, ...
        'YColor',              c.axis, ...
        'ZColor',              c.axis, ...
        'GridColor',           c.grid, ...
        'MinorGridColor',      c.gridMinor, ...
        'GridAlpha',           1.0, ...
        'MinorGridAlpha',      1.0, ...
        'GridLineStyle',       '-', ...
        'MinorGridLineStyle',  ':', ...
        'XGrid',               'on', ...
        'YGrid',               'on', ...
        'Box',                 'off', ...
        'Layer',               'top', ...
        'TickDir',             'out', ...
        'TickLength',          [0.008 0.008], ...
        'LineWidth',           1.0, ...
        'FontName',            font, ...
        'FontSize',            11, ...
        'ColorOrder',          c.lineColors, ...
        'ColorOrderIndex',     1, ...
        'TickLabelInterpreter','latex');

    ax.Title.Color       = c.text;
    ax.Title.FontName    = font;
    ax.Title.FontWeight  = 'bold';
    ax.Title.FontSize    = 13;
    ax.Title.Interpreter = 'latex';

    ax.XLabel.Color       = c.textMuted;
    ax.XLabel.FontName    = font;
    ax.XLabel.Interpreter = 'latex';

    ax.YLabel.Color       = c.textMuted;
    ax.YLabel.FontName    = font;
    ax.YLabel.Interpreter = 'latex';

    ax.ZLabel.Color       = c.textMuted;
    ax.ZLabel.FontName    = font;
    ax.ZLabel.Interpreter = 'latex';
end