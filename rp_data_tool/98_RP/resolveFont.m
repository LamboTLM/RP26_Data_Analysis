function font = resolveFont()
%RP.RESOLVEFONT  Returns best available font matching Dynamics style guide
%
%   font = RP.resolveFont()
%
%   Priority:
%     1. Segoe UI        — official Dynamics body font (ships with Windows)
%     2. Helvetica Neue  — macOS fallback
%     3. Arial           — universal fallback
%
%   Called internally by RP.style(), RP.newFig(), RP.styleAxes().
%   No need to call this directly in normal usage.
%
% Autor: Lambo || Datum: 12.05.2026

    installed = listfonts();

    if any(strcmpi(installed, 'Segoe UI'))
        font = 'Segoe UI';
    elseif any(strcmpi(installed, 'Helvetica Neue'))
        font = 'Helvetica Neue';
    else
        font = 'Arial';
    end
end