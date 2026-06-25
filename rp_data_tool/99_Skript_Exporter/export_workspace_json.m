% Autor: Lambo || Datum: 08.06.2026
% Beschreibung: Exportiert alle Workspace-Variablen als JSON in den
%               einen Exporter Ordner. 
%
% Verwendung:
%   export_workspace_json          % exportiert alles
%   export_workspace_json('tag')   % hängt einen optionalen Tag an den Namen
%
% Unterstützte Typen: double, single, int*, uint*, logical, char, string,
%                     struct, cell. Komplexe/nicht-serialisierbare Typen
%                     (function_handle, object, …) werden übersprungen
%                     und im Report aufgelistet.

function export_workspace_json(tag)

%% Konfiguration
EXPORT_DIR = 'C:\Users\Danie\OneDrive\Desktop\RP26_Mech_Optimiser\Skript_Exporter';

if nargin < 1 || isempty(tag)
    tag = '';
end

%% Dateiname mit Timestamp ──────────────────────────────────────────────
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');

if isempty(tag)
    filename = sprintf('workspace_%s.json', timestamp);
else
    % Sonderzeichen im Tag bereinigen
    safe_tag = regexprep(tag, '[^\w\-]', '_');
    filename  = sprintf('workspace_%s_%s.json', safe_tag, timestamp);
end

filepath = fullfile(EXPORT_DIR, filename);

%% Exportordner anlegen (falls nicht vorhanden) ─────────────────────────
if ~isfolder(EXPORT_DIR)
    mkdir(EXPORT_DIR);
    fprintf('[Exporter] Ordner angelegt:\n  %s\n', EXPORT_DIR);
end

%% Workspace-Variablen einlesen ─────────────────────────────────────────
% evalin('base',...) greift auf den aufrufenden Workspace zu,
% nicht auf den Funktions-Scope.
ws_vars  = evalin('base', 'whos');
skipped  = {};
payload  = struct();

fprintf('[Exporter] %d Variablen gefunden – Serialisierung läuft …\n', numel(ws_vars));

for k = 1 : numel(ws_vars)
    vname = ws_vars(k).name;
    vclass = ws_vars(k).class;

    % Variablen überspringen, die nicht JSON-serialisierbar sind
    skip_classes = {'function_handle', 'timer', 'VideoWriter', ...
                    'VideoReader',     'serial',  'tcpclient'};
    if any(strcmp(vclass, skip_classes))
        skipped{end+1} = sprintf('%s (%s)', vname, vclass); %#ok<AGROW>
        continue
    end

    try
        val = evalin('base', vname);
        payload.(vname) = sanitize_for_json(val, vname);
    catch ME
        skipped{end+1} = sprintf('%s – %s', vname, ME.message); %#ok<AGROW>
    end
end

%% JSON schreiben
try
    json_str = jsonencode(payload, 'PrettyPrint', true);
catch
    % Fallback ohne PrettyPrint (MATLAB < R2021a)
    json_str = jsonencode(payload);
end

fid = fopen(filepath, 'w', 'n', 'UTF-8');
if fid == -1
    error('[Exporter] Datei konnte nicht geöffnet werden:\n  %s', filepath);
end
fwrite(fid, json_str, 'char');
fclose(fid);

%% Report
info = dir(filepath);
fprintf('\n[Exporter] ✓ Export abgeschlossen\n');
fprintf('  Datei  : %s\n',       filename);
fprintf('  Pfad   : %s\n',       EXPORT_DIR);
fprintf('  Größe  : %.1f kB\n',  info.bytes / 1024);
fprintf('  Vars   : %d exportiert',  numel(ws_vars) - numel(skipped));

if ~isempty(skipped)
    fprintf(', %d übersprungen:\n', numel(skipped));
    for k = 1 : numel(skipped)
        fprintf('    • %s\n', skipped{k});
    end
else
    fprintf('\n');
end

end

%%  Hilfsfunktion: nicht-serialisierbare Werte bereinigen
function out = sanitize_for_json(val, name)
% Wandelt einen MATLAB-Wert rekursiv in einen jsonencode-kompatiblen Typ um.

    if isnumeric(val) || islogical(val)
        % Inf / NaN → null-kompatible Strings (JSON kennt kein Inf/NaN)
        if any(~isfinite(val(:)))
            val = double(val);
            val(isnan(val))  = [];   % wird als [] gespeichert falls leer
            % Alternativ: String-Repräsentation behalten
            out = val;
        else
            out = val;
        end

    elseif ischar(val) || isstring(val)
        out = val;

    elseif isstruct(val)
        if numel(val) > 1
            % Struct-Array → JSON-Array: jedes Element einzeln sanitizen,
            % dann als Cell-Array übergeben (jsonencode macht daraus []).
            out = cell(numel(val), 1);
            for ei = 1 : numel(val)
                out{ei} = sanitize_struct_scalar(val(ei), sprintf('%s(%d)', name, ei));
            end
        else
            out = sanitize_struct_scalar(val, name);
        end

    elseif iscell(val)
        out = cell(size(val));
        for idx = 1 : numel(val)
            try
                out{idx} = sanitize_for_json(val{idx}, sprintf('%s{%d}', name, idx));
            catch
                out{idx} = '<nicht serialisierbar>';
            end
        end

    else
        % Nicht unterstützter Typ → Platzhalter
        out = sprintf('<Typ %s nicht exportierbar>', class(val));
    end

end

%%  Hilfsfunktion: einzelnes Struct-Scalar sanitizen (kein Array)
function out = sanitize_struct_scalar(s, name)
% Verarbeitet ein einzelnes (skalares) Struct rekursiv.
    fields = fieldnames(s);
    out = struct();
    for f = 1 : numel(fields)
        fn = fields{f};
        out.(fn) = sanitize_for_json(s.(fn), [name '.' fn]);
    end
end