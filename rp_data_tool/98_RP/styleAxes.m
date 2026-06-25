function styleAxes(ax, varargin)
%RP.STYLEAXES  Apply Dynamics E.V. theme to existing axes handles
%
%   Use when axes were created BEFORE calling RP.style(), or to restyle
%   individual panels within a figure.
%
%   RP.styleAxes(ax)
%   RP.styleAxes(ax, 'Mode', 'light')
%
% Autor: Lambo || Datum: 12.05.2026

    p = inputParser; p.CaseSensitive = false;
    addParameter(p, 'Mode', 'dark', @ischar);
    parse(p, varargin{:});

    c    = RP.colors(p.Results.Mode);
    font = RP.resolveFont();

    for i = 1:numel(ax)
        a = ax(i);
        if ~isvalid(a), continue; end

        % Core axes properties
        set(a, ...
            'Color',              c.axesBg, ...
            'XColor',             c.axis, ...
            'YColor',             c.axis, ...
            'ZColor',             c.axis, ...
            'GridColor',          c.grid, ...
            'MinorGridColor',     c.gridMinor, ...
            'GridAlpha',          1.0, ...
            'MinorGridAlpha',     1.0, ...
            'XGrid',              'on', ...
            'YGrid',              'on', ...
            'Box',                'off', ...
            'Layer',              'top', ...
            'TickDir',            'out', ...
            'LineWidth',          1.0, ...
            'FontName',           font, ...
            'FontSize',           11, ...
            'ColorOrder',         c.lineColors, ...
            'ColorOrderIndex',    1, ...
            'TickLabelInterpreter','latex');

        % Title and label text objects — set directly (NOT via set())
        a.Title.Color       = c.text;
        a.Title.FontName    = font;
        a.Title.FontWeight  = 'bold';
        a.Title.Interpreter = 'latex';

        a.XLabel.Color       = c.textMuted;
        a.XLabel.FontName    = font;
        a.XLabel.Interpreter = 'latex';

        a.YLabel.Color       = c.textMuted;
        a.YLabel.FontName    = font;
        a.YLabel.Interpreter = 'latex';

        a.ZLabel.Color       = c.textMuted;
        a.ZLabel.FontName    = font;
        a.ZLabel.Interpreter = 'latex';

        % Update parent figure background
        if isvalid(a.Parent)
            a.Parent.Color = c.bg;
        end
    end
end