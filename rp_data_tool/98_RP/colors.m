function c = colors(mode)
%RP.COLORS  Dynamics Regensburg e.V. — Official Brand Color Palette
%
%   c = RP.colors()        Dark mode (default, matches PowerPoint template)
%   c = RP.colors('dark')  Dark mode
%   c = RP.colors('light') Light mode (printing)
%
%   Brand tokens (Dynamics e.V. Style Guide):
%     #1B1B1B  Eerie Black   — figure background
%     #2A2A2A  Jet           — axes surface
%     #C72229  Fire Eng. Red — header bar, accent, brand highlight
%     #FFFFFF  White         — primary text
%     Segoe UI               — body font
%
% Autor: Lambo || Datum: 05.05.2026

    if nargin < 1, mode = 'dark'; end
    mode = lower(mode);

    % --- Official Brand Colors -------------------------------------------
    c.red    = [0.780, 0.133, 0.161];   % #C72229  Fire Engine Red
    c.white  = [1.000, 1.000, 1.000];   % #FFFFFF
    c.black  = [0.106, 0.106, 0.106];   % #1B1B1B  Eerie Black
    c.jet    = [0.165, 0.165, 0.165];   % #2A2A2A  Jet

    % --- Extended data palette (contrast-tested on #1B1B1B) --------------
    c.teal   = [0.000, 0.749, 0.800];   % #00BFcc  — primary data line
    c.orange = [0.960, 0.580, 0.090];   % #F59417
    c.blue   = [0.220, 0.600, 0.960];   % #3899F5
    c.green  = [0.380, 0.820, 0.220];   % #61D138
    c.purple = [0.650, 0.200, 0.870];   % #A633DE
    c.yellow = [0.980, 0.840, 0.060];   % #FAD60F
    c.gray   = [0.500, 0.500, 0.500];   % #808080

    % --- Mode-specific roles ---------------------------------------------
    switch mode
        case 'dark'
            c.bg         = [0.106, 0.106, 0.106];  % #1B1B1B
            c.axesBg     = [0.165, 0.165, 0.165];  % #2A2A2A
            c.text       = [1.000, 1.000, 1.000];  % #FFFFFF
            c.textMuted  = [0.650, 0.650, 0.650];  % #A6A6A6
            c.axis       = [0.420, 0.420, 0.420];  % #6B6B6B
            c.grid       = [0.240, 0.240, 0.240];  % #3D3D3D
            c.gridMinor  = [0.200, 0.200, 0.200];  % #333333
            c.legendBg   = [0.165, 0.165, 0.165];
            c.legendEdge = [0.320, 0.320, 0.320];
        case 'light'
            c.bg         = [0.960, 0.960, 0.960];
            c.axesBg     = [1.000, 1.000, 1.000];
            c.text       = [0.080, 0.080, 0.080];
            c.textMuted  = [0.400, 0.400, 0.400];
            c.axis       = [0.280, 0.280, 0.280];
            c.grid       = [0.840, 0.840, 0.840];
            c.gridMinor  = [0.910, 0.910, 0.910];
            c.legendBg   = [1.000, 1.000, 1.000];
            c.legendEdge = [0.720, 0.720, 0.720];
        otherwise
            error('[RP] Unknown mode ''%s''. Use ''dark'' or ''light''.', mode);
    end

    % --- Line ColorOrder (8 channels) ------------------------------------
    c.lineColors = [
        c.teal;    % 1  Primary measurement
        c.red;     % 2  Fit / reference / brand highlight
        c.orange;  % 3
        c.blue;    % 4
        c.green;   % 5
        c.purple;  % 6
        c.yellow;  % 7
        c.white;   % 8  Neutral fallback
    ];

    % --- Colormaps -------------------------------------------------------
    n  = 256;
    t  = linspace(0,1,n)';
    bg = c.axesBg;

    m = zeros(n,3);
    for k=1:3; m(:,k)=interp1([0 .55 1],[bg(k),c.teal(k),1],t); end
    c.map.teal = m;                     % surface → teal → white

    m2 = zeros(n,3);
    for k=1:3; m2(:,k)=interp1([0 .5 1],[c.red(k),bg(k),c.teal(k)],t); end
    c.map.div  = m2;                    % red → surface → teal  (diverging)

    m3 = zeros(n,3);
    for k=1:3; m3(:,k)=interp1([0 1],[bg(k),c.teal(k)],t); end
    c.map.seq  = m3;                    % surface → teal  (sequential)

    m4 = zeros(n,3);
    for k=1:3; m4(:,k)=interp1([0 .55 1],[bg(k),c.red(k),1],t); end
    c.map.red  = m4;                    % surface → red → white  (overheating)
end