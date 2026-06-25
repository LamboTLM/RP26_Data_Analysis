%% Dependency Exporter
% Passe diese Pfade an:
clear

root_script = 'C:\Users\Danie\OneDrive\Desktop\RP26_Mech_Optimiser\03 Skripts\run_optimization.m';          % Das Hauptskript
export_folder = 'C:\Users\Danie\OneDrive\Desktop\RP26_Mech_Optimiser\Skript_Exporter';                      % Zielordner

%% Analyse
[files, ~] = matlab.codetools.requiredFilesAndProducts(root_script);

%% Kopieren
% if ~exist(export_folder, 'dir')
%     mkdir(export_folder);
% end

for i = 1:length(files)
    [src_folder, name, ext] = fileparts(files{i});
    
    % Ordnerstruktur relativ zum aktuellen Pfad beibehalten (optional)
    dest = fullfile(export_folder, [name ext]);
    copyfile(files{i}, dest);
    % fprintf('Kopiert: %s\n', [name ext]);
end

fprintf('\nFertig! %d Dateien exportiert nach:\n%s\n', length(files), export_folder);