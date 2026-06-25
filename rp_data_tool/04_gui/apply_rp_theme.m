function apply_rp_theme(ax, cfg)
% Wendet +RP Theme auf uiaxes an (wenn verfuegbar)
% Autor: [Benutzer]
% Datum: 2026-06-24

if ~cfg.rp_theme.aktiv || ~exist('RP.styleAxes', 'file')
    % Fallback auf internes Styling
    C = cfg.farben;
    ax.Color = [0.13, 0.13, 0.13];
    ax.XColor = C.grau;
    ax.YColor = C.grau;
    ax.GridColor = [0.25, 0.25, 0.25];
    ax.GridAlpha = 0.5;
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    ax.FontSize = 9;
    ax.Box = 'on';
    ax.BackgroundColor = [0.13, 0.13, 0.13];
    return;
end

try
    RP.styleAxes(ax, 'Mode', cfg.rp_theme.modus);
catch
    % Fallback
    C = cfg.farben;
    ax.Color = [0.13, 0.13, 0.13];
    ax.XColor = C.grau;
    ax.YColor = C.grau;
    ax.GridColor = [0.25, 0.25, 0.25];
    ax.GridAlpha = 0.5;
    ax.XGrid = 'on';
    ax.YGrid = 'on';
    ax.FontSize = 9;
    ax.Box = 'on';
    ax.BackgroundColor = [0.13, 0.13, 0.13];
end
end