% Diese Funktion sollte in Ihrem Pfad (z.B. Functions Ordner) gespeichert werden.
function data_output = getDriverDataAtTime(t_query, Driver_data, T_data)
    % Finde den naechstgelegenen Datenpunkt
    [~, idx] = min(abs(T_data - t_query));
    
    t_val = T_data(idx);
    apps_val = Driver_data.apps_res_can(idx);
    pbrake_f_val = Driver_data.pbrake_front_can(idx);
    pbrake_r_val = Driver_data.pbrake_rear_can(idx);
    steer_val = Driver_data.steering_wheel_angle_can(idx);
    
    % NEUES MEHRZEILIGES FORMAT mit \n (Zeilenumbruch)
    display_str = sprintf('Zeit: %.2f s \nAPPS: %.1f \nBremse V: %.1f Bar \nBremse H: %.1f Bar \nLenkwinkel: %.1f °', ...
        t_val, apps_val, pbrake_f_val, pbrake_r_val, steer_val);
    
    data_output.t_val = t_val;
    data_output.display_str = display_str;
end