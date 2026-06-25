function export_report(signale, meta, cfg)
% Exportiert aktive Figure als PDF oder PNG mit +RP Design
% Autor: [Benutzer]
% Datum: 2026-06-24

[datei_name, datei_pfad] = uiputfile({'*.pdf', 'PDF Report'; '*.png', 'PNG Screenshot'}, ...
    'Report speichern', sprintf('Report_%s_%s', meta.fahrzeug, strrep(meta.datum, '-', '')));
if isequal(datei_name, 0)
    return;
end
[~, ~, ext] = fileparts(datei_name);
ausgabe_pfad = fullfile(datei_pfad, datei_name);

aktive_fig = gcf;
if ~isempty(aktive_fig) && isvalid(aktive_fig)
    try
        % Versuche +RP Export wenn verfuegbar
        if cfg.rp_theme.aktiv && exist('RP.export', 'file')
            [~, name_ohne_ext] = fileparts(datei_name);
            RP.export(aktive_fig, name_ohne_ext, 'Format', lower(ext(2:end)), 'DPI', 200);
        else
            % Fallback
            if strcmpi(ext, '.pdf')
                exportgraphics(aktive_fig, ausgabe_pfad, 'ContentType', 'vector', 'Resolution', 150);
            else
                exportgraphics(aktive_fig, ausgabe_pfad, 'Resolution', 200);
            end
        end
        fprintf('Export: %s\n', ausgabe_pfad);
    catch ME
        warning('Export fehlgeschlagen: %s', ME.message);
    end
end
msgbox(sprintf('Export abgeschlossen:\n%s', ausgabe_pfad), 'Export OK');
end