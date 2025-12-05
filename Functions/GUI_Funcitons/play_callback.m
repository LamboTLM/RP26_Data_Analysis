% --- Generische Steuerung: Start (Play) ---
function play_callback(~, ~, f)
    playback_data = getappdata(f, 'PlaybackData');
    if isempty(playback_data)
        disp('Fehler: PlaybackData fehlt im Figure-Handle.');
        return;
    end
    
    % KORRIGIERT: Überprüfe, ob das Feld existiert, sonst initialisiere es
    if ~isfield(playback_data, 'play_timer')
        playback_data.play_timer = [];
    end

    if isempty(playback_data.play_timer) || ~isvalid(playback_data.play_timer)
        playback_data.play_timer = timer('ExecutionMode', 'fixedRate', ...
            'Period', 0.01, ... 
            'TimerFcn', {@timer_generic_update_callback, f}, ...
            'StopFcn', @(~,~) disp('Wiedergabe beendet.'));
        playback_data.timer_running = true;
        setappdata(f, 'PlaybackData', playback_data);
        start(playback_data.play_timer);
        disp(['Wiedergabe fuer ' f.Name ' gestartet.']);
        
    elseif ~playback_data.timer_running
        playback_data.timer_running = true;
        setappdata(f, 'PlaybackData', playback_data);
        start(playback_data.play_timer);
        disp(['Wiedergabe fuer ' f.Name ' fortgesetzt.']);
    end
end