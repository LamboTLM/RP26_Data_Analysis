% --- Generische Steuerung: Zurueckspulen (Rewind) ---
function rewind_callback(~, ~, f)
    playback_data = getappdata(f, 'PlaybackData');
    
    % KORRIGIERT: Überprüfe, ob das Feld existiert, sonst initialisiere es
    if ~isfield(playback_data, 'play_timer')
        playback_data.play_timer = [];
    end
    
    if isfield(playback_data, 'play_timer') && isvalid(playback_data.play_timer)
        stop(playback_data.play_timer);
        playback_data.timer_running = false;
    end
    
    % ... (Rest der Rewind-Logik bleibt gleich) ...
    playback_data.current_time_idx = 1;
    setappdata(f, 'PlaybackData', playback_data);
    
    T_data = playback_data.T_data;
    window_size = 20; 
    xlim(playback_data.all_axes, [T_data(1), T_data(1) + min(window_size, T_data(end)-T_data(1))]);

    t_start = T_data(1);
    data_at_start = playback_data.data_interpolation(t_start); 
    
    for i = 1:numel(playback_data.vertical_lines)
        v_line = playback_data.vertical_lines(i);
        ax = get(v_line, 'Parent');
        y_limits = get(ax, 'YLim');
        set(v_line, 'XData', [t_start, t_start], 'YData', y_limits, 'Visible', 'on');
    end
    
    set(playback_data.value_display, 'String', data_at_start.display_str);
    disp(['Wiedergabe fuer ' f.Name ' zurueckgespult.']);
end