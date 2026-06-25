function addLogo(ax, varargin)
%RP.ADDLOGO  Add Dynamics E.V. logo as transparent watermark on an axes
%
%   RP.addLogo(ax)
%   RP.addLogo(ax, Name, Value, ...)
%
%   Options:
%     'Alpha'     0–1      Watermark opacity (default: 0.10)
%     'Position'  string   'center'|'br'|'bl'|'tr'|'tl' (default: 'center')
%     'Scale'     0–1      Logo width as fraction of x-axis range (default: 0.45)
%
%   Logo file:
%     Place processed PNG at:  <+RP folder>/assets/dynamics_logo.png
%     Requirements: RGBA PNG with black background removed (use the
%     provided pre-processed file from the +RP package).
%     If file is absent, a minimal text watermark is used as fallback.
%
%   DESIGN — why we draw directly on the main axes:
%     Previous approach (separate logoAx + uistack) failed because with
%     tiledlayout, axes are children of TiledChartLayout, not the figure.
%     A logoAx added as figure-child gets wrong coordinates and cannot be
%     correctly stacked relative to tiledlayout-managed axes.
%
%     Solution: draw the logo image as an image() object directly on the
%     main axes in data coordinates, then uistack it below all plot data.
%     This is simple, robust, and works with any layout.
%
%   NOTE: Call AFTER plot(), xlabel(), ylabel() — xlim/ylim must be final.
%
% Autor: Lambo || Datum: 12.05.2026

    p = inputParser; p.CaseSensitive = false;
    addParameter(p, 'Alpha',    0.10,     @(x) isnumeric(x) && x>0 && x<=1);
    addParameter(p, 'Position', 'center', @ischar);
    addParameter(p, 'Scale',    0.45,     @(x) isnumeric(x) && x>0 && x<=1);
    parse(p, varargin{:});
    opt = p.Results;

    % ------------------------------------------------------------------ %
    % Locate logo PNG
    % ------------------------------------------------------------------ %
    thisDir  = fileparts(mfilename('fullpath'));
    logoPath = fullfile(thisDir, 'assets', 'dynamics_logo.png');

    if exist(logoPath, 'file') == 2
        rp_draw_image(ax, logoPath, opt);
    else
        rp_draw_text(ax, opt);
    end
end


% ========================================================================= %
function rp_draw_image(ax, logoPath, opt)
%RRP_DRAW_IMAGE  Draw logo image directly on main axes in data coordinates

    % Load image
    try
        [img, ~, alphaChannel] = imread(logoPath);
    catch ME
        warning('[RP.addLogo] Could not read logo: %s\nFalling back to text.', ME.message);
        rp_draw_text(ax, opt);
        return;
    end

    img = double(img) / 255;                       % [0..1] RGB
    [imgH, imgW, ~] = size(img);
    logoAR = imgW / imgH;                          % aspect ratio (should be ~1.0)

    % Build alpha data
    if ~isempty(alphaChannel)
        % Proper RGBA PNG
        aData = double(alphaChannel) / 255 * opt.Alpha;
    else
        % RGB-only: derive alpha — make black/near-black transparent
        lum   = 0.299*img(:,:,1) + 0.587*img(:,:,2) + 0.114*img(:,:,3);
        aData = double(lum > 0.12) .* opt.Alpha;   % hard threshold on luminance
    end

    % ------------------------------------------------------------------ %
    % Compute placement in data coordinates
    % ------------------------------------------------------------------ %
    xl = xlim(ax);
    yl = ylim(ax);

    xSpan = diff(xl);
    ySpan = diff(yl);

    % Center offsets based on position parameter
    [xFrac, yFrac] = rp_position_fracs(opt.Position);
    xc = xl(1) + xSpan * xFrac;
    yc = yl(1) + ySpan * yFrac;

    % ------------------------------------------------------------------ %
    % Aspect-ratio-correct sizing
    %   We want the logo to appear undistorted regardless of the axes
    %   data range and figure dimensions.
    %
    %   Step 1: measure the axes in pixels
    %   Step 2: compute data-units-per-pixel in each direction
    %   Step 3: choose logo width (dx) from Scale parameter
    %   Step 4: derive dy so that the logo fills the same pixel height
    %           as its natural aspect ratio demands
    %
    %   dy = dx * (duPerPxY / duPerPxX) / logoAR
    % ------------------------------------------------------------------ %
    prevUnits  = ax.Units;
    ax.Units   = 'pixels';
    axPosPx    = ax.Position;            % [x y width height] in pixels
    ax.Units   = prevUnits;

    axWidthPx  = axPosPx(3);
    axHeightPx = axPosPx(4);

    duPerPxX = xSpan / axWidthPx;       % data units per pixel, x-direction
    duPerPxY = ySpan / axHeightPx;      % data units per pixel, y-direction

    dx = xSpan * opt.Scale / 2;         % half-width in data units
    dy = dx * (duPerPxY / duPerPxX) / logoAR;  % half-height, aspect-corrected

    xLims = [xc - dx, xc + dx];
    yLims = [yc - dy, yc + dy];

    % ------------------------------------------------------------------ %
    % FIX: image() on a normal axes (Y up) places row 1 at the bottom,
    % flipping the image vertically. Correct with flipud() before drawing.
    % ------------------------------------------------------------------ %
    img   = flipud(img);
    aData = flipud(aData);

    % ------------------------------------------------------------------ %
    % Draw image on the main axes — hold state preserved
    % ------------------------------------------------------------------ %
    holdWas = ishold(ax);
    hold(ax, 'on');

    ih = image(ax, xLims, yLims, img);
    ih.AlphaData = aData;
    ih.Tag       = 'RP_LogoImage';

    % Push image to bottom of axes children stack (behind all plot data)
    uistack(ih, 'bottom');

    % Restore hold state
    if ~holdWas
        hold(ax, 'off');
    end

    % Restore axis limits (image() can expand them)
    xlim(ax, xl);
    ylim(ax, yl);
end


% ========================================================================= %
function rp_draw_text(ax, opt)
%RRP_DRAW_TEXT  Minimal text fallback — used when no logo PNG is found

    font = RP.resolveFont();
    c    = RP.colors('dark');

    xl = xlim(ax); yl = ylim(ax);
    [xFrac, yFrac] = rp_position_fracs(opt.Position);
    xc = xl(1) + diff(xl) * xFrac;
    yc = yl(1) + diff(yl) * yFrac;

    a = min(1, opt.Alpha * 6);    % scale opacity up slightly for text readability

    holdWas = ishold(ax);
    hold(ax, 'on');

    th1 = text(ax, xc, yc + diff(yl)*0.06, 'DYNAMICS', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment',   'middle', ...
        'FontName',  font, 'FontSize', 26, 'FontWeight', 'bold', ...
        'Color',     [1, 1, 1, a], ...
        'Interpreter', 'none', 'Tag', 'RP_LogoText');

    th2 = text(ax, xc, yc - diff(yl)*0.04, 'e.V.', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment',   'middle', ...
        'FontName',  font, 'FontSize', 13, 'FontWeight', 'bold', ...
        'Color',     [c.red, a], ...
        'Interpreter', 'none', 'Tag', 'RP_LogoText');

    th3 = text(ax, xc, yc - diff(yl)*0.13, 'REGENSBURG FORMULA STUDENT TEAM', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment',   'middle', ...
        'FontName',  font, 'FontSize', 7, 'FontWeight', 'normal', ...
        'Color',     [1, 1, 1, a*0.5], ...
        'Interpreter', 'none', 'Tag', 'RP_LogoText');

    % Push text objects behind data
    uistack(th1, 'bottom');
    uistack(th2, 'bottom');
    uistack(th3, 'bottom');

    if ~holdWas, hold(ax, 'off'); end
end


% ========================================================================= %
function [xf, yf] = rp_position_fracs(pos)
%RRP_POSITION_FRACS  Returns [xFrac, yFrac] in [0,1] of data range

    switch lower(pos)
        case 'center'; xf = 0.50; yf = 0.50;
        case 'br';     xf = 0.78; yf = 0.22;
        case 'bl';     xf = 0.22; yf = 0.22;
        case 'tr';     xf = 0.78; yf = 0.78;
        case 'tl';     xf = 0.22; yf = 0.78;
        otherwise;     xf = 0.50; yf = 0.50;
    end
end