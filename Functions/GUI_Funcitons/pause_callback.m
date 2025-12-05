% --- Generische Steuerung: Pause ---
function pause_callback(~, ~, f)
    playback_data = getappdata(f, 'PlaybackData');
    if isfield(playback_data, 'play_timer') && isvalid(playback_data.play_timer)
        stop(playback_data.play_timer);
        playback_data.timer_running = false;
        setappdata(f, 'PlaybackData', playback_data);
        disp(['Wiedergabe fuer ' f.Name ' angehalten.']);
    end
end