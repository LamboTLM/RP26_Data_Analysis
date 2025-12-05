% --- Zentrale Update-Funktion, unabhaengig von den dargestellten Daten ---
function timer_generic_update_callback(mTimer, event, f)
    playback_data = getappdata(f, 'PlaybackData');
    
    if isempty(playback_data) || ~isfield(playback_data, 'T_data')
        stop(mTimer); delete(mTimer); return;
    end
    
    idx = playback_data.current_time_idx;
    T_data = playback_data.T_data;
    
    if idx <= numel(T_data)
        t_val = T_data(idx);
        
        % 1. Daten Interpolieren/Abrufen mit der figurespezifischen Funktion
        data_at_time = playback_data.data_interpolation(t_val); 
        
        % 2. Vertikale Linien aktualisieren
        for i = 1:numel(playback_data.vertical_lines)
            v_line = playback_data.vertical_lines(i);
            ax = get(v_line, 'Parent');
            y_limits = get(ax, 'YLim'); 
            set(v_line, 'XData', [t_val, t_val], 'YData', y_limits, 'Visible', 'on');
        end
        
        % 3. Wertanzeige aktualisieren
        set(playback_data.value_display, 'String', data_at_time.display_str);
        
        % 4. X-Achsen-Ansicht mitfuehren
        ax_lim = xlim(playback_data.all_axes(1));
        if t_val > ax_lim(2) || t_val < ax_lim(1)
            window_size = ax_lim(2) - ax_lim(1);
            new_xlim_start = t_val - window_size/2;
            new_xlim_end = t_val + window_size/2;
            % Range-Check
            if new_xlim_start < T_data(1)
                new_xlim_start = T_data(1);
                new_xlim_end = T_data(1) + window_size;
            end
            xlim(playback_data.all_axes, [new_xlim_start, new_xlim_end]);
        end

        % 5. Nächsten Index setzen
        playback_data.current_time_idx = idx + 1;
        setappdata(f, 'PlaybackData', playback_data);
        
    else
        % Ende erreicht
        stop(mTimer);
        playback_data.timer_running = false;
        setappdata(f, 'PlaybackData', playback_data);
        for i = 1:numel(playback_data.vertical_lines)
            set(playback_data.vertical_lines(i), 'Visible', 'off');
        end
    end
end