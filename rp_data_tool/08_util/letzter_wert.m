function wert = letzter_wert(signale, feldname, standard_wert)
% Autor: [Benutzer]
% Datum: 2026-06-24

if isfield(signale, feldname) && isfield(signale, [feldname, '_ok']) && signale.([feldname, '_ok'])
    try
        ts = signale.(feldname);
        wert = sprintf('%.2f', util.tern_str(isa(ts, 'timeseries'), ts.Data(end), ts(end)));
    catch
        wert = standard_wert;
    end
else
    wert = standard_wert;
end
end