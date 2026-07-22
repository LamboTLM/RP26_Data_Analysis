% =========================================================================
%  subsystem_aus_name  –  Signalname einem Subsystem zuordnen
% -------------------------------------------------------------------------
%  Zweck         : Ordnet einen CAN-Signalnamen anhand seines Praefixes
%                  einem Subsystem zu (fuer Browser-Gruppierung + Health).
%  Abhaengigkeiten: keine
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function subsystem = subsystem_aus_name(name)
%SUBSYSTEM_AUS_NAME  Liefert das Subsystem-Kuerzel zu einem Signalnamen.
%   subsystem = SUBSYSTEM_AUS_NAME(name)
%
%   name      : char/string, CAN-Signalname
%   subsystem : char, eines der Subsysteme oder 'sonstige'
%
%   Changelog:
%     2026-07-15  Erststand.

    %% Konfiguration
    % Reihenfolge = Prioritaet: erstes passendes Praefix gewinnt.
    % Jede Zeile: { subsystem , {praefixe...} }
    regeln = {
        'fahrdynamik',      {'INS_','DL_Accel','DL_Yaw','DL_speed','DL_steering','slip_compare','tqv_rot_spd','speed_can','steering_wheel'}
        'fahrwerk',         {'rocker_','gas_strut'}
        'bremse',           {'pbrake','brake_','bspd','ebs_preasure','pBrake'}
        'antrieb',          {'unitek_','drive_','tqTarget','tq_vehicle','tqv_','tmot','tinverter','powerLimit','recuLimit','vcu_recu'}
        'fahrereingabe',    {'apps','driver_id','drs_','start_btn','r2ds'}
        'akku_hv',          {'ams_','ts_','tsal','air_','precharge','imd_','hv_current'}
        'akku_lv',          {'battery_'}
        'energie',          {'IVT_','PDU_'}
        'thermik',          {'ewp','fan','t_ext'}
        'runde',            {'lap','laptime','odometer','marker'}
        'zustand',          {'VCU_','SDC','sc_','Watchdog','kl15','vLogger','LT_','calibr','vehicleId','Reset'}
        'autonom',          {'ACE_','AS','DL_AS','DL_AMI','DVSC','DV_Emergency','EBS_','assi'}
        };

    %% Berechnung
    name = char(name);
    subsystem = 'sonstige';
    for i = 1:size(regeln, 1)
        praefixe = regeln{i, 2};
        if any(cellfun(@(p) startsWith(name, p), praefixe))
            subsystem = regeln{i, 1};
            return;
        end
    end
end
