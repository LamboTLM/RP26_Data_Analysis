function meta = parse_dateiname(datei_name, cfg)
% Parst Dateinamen nach Schema: Fahrzeug_YYYY-MM-DD_HH-MM-MM_Modus_Event.mf4
% Autor: [Benutzer]
% Datum: 2026-06-24
% Changelog: meta.modus initialisiert (Bugfix)

meta.dateiname = datei_name;
meta.fahrzeug = 'Unbekannt';
meta.datum = 'Unbekannt';
meta.zeit = '';
meta.event = 'Unbekannt';
meta.modus = 'Unbekannt';

tokens = regexp(datei_name, '^(.+?)_(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})_(.+?)_(.+?)\.mf4$', 'tokens', 'ignorecase');
if ~isempty(tokens)
    t = tokens{1};
    if numel(t) >= 5
        meta.fahrzeug = t{1};
        meta.datum = t{2};
        meta.zeit = strrep(t{3}, '-', ':');
        meta.modus = t{4};
        meta.event = strrep(t{5}, '_', ' ');
    end
end
end