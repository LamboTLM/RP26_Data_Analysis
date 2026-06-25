function feldname = signal_zu_feldname(signal_name)
% Wandelt Signalnamen in gueltige MATLAB-Feldnamen um
% Autor: [Benutzer]
% Datum: 2026-06-24

feldname = regexprep(signal_name, '[^a-zA-Z0-9_]', '_');
if ~isempty(feldname) && ~isletter(feldname(1))
    feldname = ['sig_', feldname];
end
end