function export(fig, filename, varargin)
%RP.EXPORT  Export figure in Dynamics E.V. standard format
%
%   RP.export(fig, filename)
%   RP.export(fig, filename, Name, Value, ...)
%
%   Options:
%     'Format'  string|cell   'png'|'pdf'|'svg'|{'png','pdf'} (default:'png')
%     'DPI'     scalar        Resolution in DPI (default: 200)
%     'OutDir'  string        Output folder (default: current folder)
%     'Suffix'  string        Appended to filename, e.g. '_v2'
%
% Autor: Lambo || Datum: 12.05.2026

    p = inputParser; p.CaseSensitive = false;
    addParameter(p, 'Format', 'png', @(x) ischar(x)||iscell(x));
    addParameter(p, 'DPI',    200,   @isnumeric);
    addParameter(p, 'OutDir', pwd,   @ischar);
    addParameter(p, 'Suffix', '',    @ischar);
    parse(p, varargin{:});
    opt = p.Results;

    formats = cellstr(opt.Format);
    if ~exist(opt.OutDir, 'dir'), mkdir(opt.OutDir); end

    for i = 1:numel(formats)
        fmt  = lower(formats{i});
        out  = fullfile(opt.OutDir, [filename, opt.Suffix, '.', fmt]);
        switch fmt
            case 'png'
                exportgraphics(fig, out, ...
                    'Resolution',      opt.DPI, ...
                    'BackgroundColor', fig.Color);
            case {'pdf','svg','eps'}
                exportgraphics(fig, out, ...
                    'ContentType',     'vector', ...
                    'BackgroundColor', fig.Color);
            otherwise
                warning('[RP.export] Unknown format ''%s'', skipping.', fmt);
                continue;
        end
        fprintf('[RP] Exported: %s\n', out);
    end
end