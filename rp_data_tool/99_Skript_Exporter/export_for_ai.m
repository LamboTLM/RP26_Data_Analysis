% Autor: Lambo || Datum: 11.07.2026
% Beschreibung: Vereinter Exporter für KI-Code-Reviews.
%               Exportiert wahlweise den Projekt-Code (alle Abhängigkeiten
%               des Hauptskripts), den aktuellen Workspace, oder beides,
%               in EINE strukturierte JSON-Datei.
%
% Verwendung (aus dem Command Window, NICHT als Skript ausführen!):
%   export_for_ai                      % zeigt Auswahlmenü
%   export_for_ai('project')           % nur Projekt-Code
%   export_for_ai('workspace')         % nur Workspace-Variablen
%   export_for_ai('both')              % beides
%   export_for_ai('workspace', 'tag')  % mit optionalem Datei-Tag
%
% Hinweis: Muss als Funktion aufgerufen werden (nicht per "Run"-Button),
%          damit der Workspace-Zugriff via evalin('base', ...) sauber
%          vom Funktions-Scope getrennt bleibt.

function export_for_ai(mode, tag)

%% Konfiguration -- HIER ANPASSEN
root_script = 'C:\Users\Danie\OneDrive\Desktop\RP26_Data_Analysis\rp_data_tool\rp_data_tool.m';
export_dir  = 'C:\Users\Danie\OneDrive\Desktop\RP26_Data_Analysis\rp_data_tool\99_Skript_Exporter';
copy_to_clipboard = false;   % true = JSON direkt in Zwischenablage kopieren (Windows)

%% Argumente prüfen / Menü anzeigen
if nargin < 1 || isempty(mode)
    choice = menu('Was soll exportiert werden?', ...
        'Projekt-Code (Abhängigkeiten)', ...
        'Workspace (Variablen)', ...
        'Beides');
    switch choice
        case 1, mode = 'project';
        case 2, mode = 'workspace';
        case 3, mode = 'both';
        otherwise
            fprintf('[Exporter] Abgebrochen.\n');
            return
    end
else
    mode = lower(mode);
    if ~ismember(mode, {'project', 'workspace', 'both'})
        error('[Exporter] Ungültiger mode: %s (erlaubt: project | workspace | both)', mode);
    end
end

if nargin < 2 || isempty(tag)
    tag = '';
end

fprintf('[Exporter] Modus: %s\n', mode);

%% Exportordner anlegen
if ~isfolder(export_dir)
    mkdir(export_dir);
    fprintf('[Exporter] Ordner angelegt:\n  %s\n', export_dir);
end

%% Payload-Grundgerüst
payload = struct();
payload.meta = struct( ...
    'export_date', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
    'mode', mode, ...
    'root_script', root_script);

%% PROJEKT-CODE
if ismember(mode, {'project', 'both'})
    if ~isfile(root_script)
        error('[Exporter] Hauptskript nicht gefunden:\n  %s', root_script);
    end

    fprintf('[Exporter] Analysiere Projekt-Abhängigkeiten...\n');
    [files, products] = matlab.codetools.requiredFilesAndProducts(root_script);
    files = files(:);

    % Root-Script an den Anfang setzen
    root_idx = strcmp(files, root_script);
    if any(root_idx)
        files = [files(root_idx); files(~root_idx)];
    end

    proj_products = {};
    for i = 1:numel(products)
        proj_products{end+1} = products(i).Name; %#ok<AGROW>
    end

    proj_files = cell(numel(files), 1);
    total_chars = 0;
    for i = 1:numel(files)
        [~, fname, fext] = fileparts(files{i});
        entry = struct('name', [fname fext], 'path', files{i});
        try
            content = fileread(files{i});
            entry.content = content;
            total_chars = total_chars + strlength(content);
        catch ME
            entry.content = '';
            entry.read_error = ME.message;
        end
        proj_files{i} = entry;
    end

    payload.project = struct( ...
        'products', {proj_products}, ...
        'file_count', numel(files), ...
        'total_chars', total_chars, ...
        'files', {proj_files});

    fprintf('[Exporter] Projekt: %d Dateien, ~%d Zeichen\n', numel(files), total_chars);
end

%% WORKSPACE
if ismember(mode, {'workspace', 'both'})
    fprintf('[Exporter] Serialisiere Workspace...\n');
    ws_vars = evalin('base', 'whos');
    skipped = {};
    ws_payload = struct();

    skip_classes = {'function_handle', 'timer', 'VideoWriter', ...
                     'VideoReader', 'serial', 'tcpclient'};

    for k = 1:numel(ws_vars)
        vname  = ws_vars(k).name;
        vclass = ws_vars(k).class;

        if any(strcmp(vclass, skip_classes))
            skipped{end+1} = sprintf('%s (%s)', vname, vclass); %#ok<AGROW>
            continue
        end

        try
            val = evalin('base', vname);
            ws_payload.(vname) = sanitize_for_json(val, vname);
        catch ME
            skipped{end+1} = sprintf('%s - %s', vname, ME.message); %#ok<AGROW>
        end
    end

    payload.workspace = struct( ...
        'variable_count', numel(ws_vars) - numel(skipped), ...
        'skipped_count', numel(skipped), ...
        'skipped', {skipped}, ...
        'variables', ws_payload);

    fprintf('[Exporter] Workspace: %d Variablen exportiert, %d übersprungen\n', ...
        numel(ws_vars) - numel(skipped), numel(skipped));
end

%% JSON schreiben
try
    json_str = jsonencode(payload, 'PrettyPrint', true);
catch
    json_str = jsonencode(payload);  % Fallback für MATLAB < R2021a
end

timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
if isempty(tag)
    filename = sprintf('export_%s_%s.json', mode, timestamp);
else
    safe_tag = regexprep(tag, '[^\w\-]', '_');
    filename = sprintf('export_%s_%s_%s.json', mode, safe_tag, timestamp);
end
filepath = fullfile(export_dir, filename);

fid = fopen(filepath, 'w', 'n', 'UTF-8');
if fid == -1
    error('[Exporter] Datei konnte nicht geöffnet werden:\n  %s', filepath);
end
fwrite(fid, json_str, 'char');
fclose(fid);

%% Zusammenfassung
info = dir(filepath);
fprintf('\n[Exporter] Export abgeschlossen\n');
fprintf('  Modus  : %s\n', mode);
fprintf('  Datei  : %s\n', filename);
fprintf('  Pfad   : %s\n', export_dir);
fprintf('  Größe  : %.1f kB\n', info.bytes / 1024);

%% Optional: Zwischenablage (Windows)
if copy_to_clipboard && ispc
    try
        clipboard('copy', json_str);
        fprintf('  Zwischenablage: kopiert (Strg+V zum Einfügen)\n');
    catch
        fprintf('  Zwischenablage: Fehler beim Kopieren\n');
    end
end

end

%% ==================== Hilfsfunktionen ====================

function out = sanitize_for_json(val, name)
% Wandelt einen MATLAB-Wert rekursiv in einen jsonencode-kompatiblen Typ um.

    if isnumeric(val) || islogical(val)
        out = val;

    elseif ischar(val) || isstring(val)
        out = val;

    elseif isstruct(val)
        if numel(val) > 1
            out = cell(numel(val), 1);
            for ei = 1:numel(val)
                out{ei} = sanitize_struct_scalar(val(ei), sprintf('%s(%d)', name, ei));
            end
        else
            out = sanitize_struct_scalar(val, name);
        end

    elseif iscell(val)
        out = cell(size(val));
        for idx = 1:numel(val)
            try
                out{idx} = sanitize_for_json(val{idx}, sprintf('%s{%d}', name, idx));
            catch
                out{idx} = '<nicht serialisierbar>';
            end
        end

    else
        out = sprintf('<Typ %s nicht exportierbar>', class(val));
    end

end

function out = sanitize_struct_scalar(s, name)
% Verarbeitet ein einzelnes (skalares) Struct rekursiv.
    fields = fieldnames(s);
    out = struct();
    for f = 1:numel(fields)
        fn = fields{f};
        out.(fn) = sanitize_for_json(s.(fn), [name '.' fn]);
    end
end