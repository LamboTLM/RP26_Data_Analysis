function ts_out = sicheres_resample(ts_in, t_ref)
% Sicheres resample mit Extrapolation
% Autor: [Benutzer]
% Datum: 2026-06-24

try
    ts_out = resample(ts_in, t_ref);
catch
    % Manuelle Interpolation mit Extrapolation
    t_in = ts_in.Time;
    d_in = double(ts_in.Data);
    if size(d_in, 2) > 1
        d_in = d_in(:, 1);
    end
    d_out = interp1(t_in, d_in, t_ref, 'linear', 'extrap');
    ts_out = timeseries(d_out, t_ref, 'Name', ts_in.Name);
end
end