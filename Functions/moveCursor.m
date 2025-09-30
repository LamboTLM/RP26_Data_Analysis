%% Callback-Funktion für Cursor
function moveCursor(~,~,Driver_data,all_axes,cursorLines,cursorMarkers,cursorText)
    % aktuelle Mausposition im ersten Plot
    C = get(all_axes(1),'CurrentPoint');
    x = C(1,1);

    % nur reagieren, wenn innerhalb der X-Achse
    if x < min(Driver_data.t) || x > max(Driver_data.t)
        return
    end

    % Nächsten Index finden
    [~,idx] = min(abs(Driver_data.t - x));

    % vertikale Linien aktualisieren
    for i=1:numel(cursorLines)
        cursorLines(i).Value = Driver_data.t(idx);
    end

    % Marker-Positionen setzen
    cursorMarkers(1).XData = Driver_data.t(idx);
    cursorMarkers(1).YData = Driver_data.apps_res_can(idx);

    cursorMarkers(2).XData = Driver_data.t(idx);
    cursorMarkers(2).YData = Driver_data.pbrake_front_can(idx);

    cursorMarkers(3).XData = Driver_data.t(idx);
    cursorMarkers(3).YData = Driver_data.steering_wheel_angle_can(idx);

    % Textbox aktualisieren
    str = sprintf(['t = %.2f s\n' ...
                   'Throttle = %.1f\n' ...
                   'BrakeF   = %.1f\n' ...
                   'Steer    = %.1f°'], ...
                   Driver_data.t(idx), ...
                   Driver_data.apps_res_can(idx), ...
                   Driver_data.pbrake_front_can(idx), ...
                   Driver_data.steering_wheel_angle_can(idx));

    set(cursorText,'String',str);
end