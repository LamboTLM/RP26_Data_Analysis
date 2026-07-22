% =========================================================================
%  fahrzeug_parameter  –  Zentraler Fahrzeug-Parametersatz
% -------------------------------------------------------------------------
%  Zweck         : Ein einziger Ort fuer alle Fahrzeugkonstanten. Die Werte
%                  sind Platzhalter (grob) und von dir zu ueberschreiben.
%                  Abgeleitete Groessen (Reifenkraft, Bremsbalance, Fz,
%                  Schwimmwinkel ueber Lenkuebersetzung, SOC) ziehen sich
%                  alles hier heraus.
%  Abhaengigkeiten: keine
%  Autor         : <dein Name>
%  Datum         : 2026-07-15
% =========================================================================

function params = fahrzeug_parameter()
%FAHRZEUG_PARAMETER  Liefert den Parameter-Struct.
%   params = FAHRZEUG_PARAMETER()
%
%   Changelog:
%     2026-07-15  Erststand (Platzhalterwerte).

    %% Fahrzeug / Massen
    params.fahrzeug.masse_gesamt_kg       = 300;    % inkl. Fahrer
    params.fahrzeug.radstand_mm           = 1530;
    params.fahrzeug.spur_vorn_mm          = 1200;
    params.fahrzeug.spur_hinten_mm        = 1180;
    params.fahrzeug.schwerpunkt_hoehe_mm  = 300;
    params.fahrzeug.gewichtsanteil_vorn   = 0.48;   % 0..1

    %% Reifen / Lenkung
    params.reifen.radius_dyn_mm           = 203;    % dynamischer Rollradius
    params.lenkung.uebersetzung           = 4.5;    % Lenkrad -> Reifenwinkel

    %% Antrieb
    params.antrieb.uebersetzung           = 14.0;   % Motor -> Rad
    params.antrieb.raeder_angetrieben     = 4;
    params.antrieb.moment_max_motor_nm    = 21;     % Spitzenmoment je Motor

    %% Bremse
    params.bremse.moment_pro_bar_vorn_nm  = 6.5;    % Druck -> Bremsmoment
    params.bremse.moment_pro_bar_hinten_nm = 5.0;

    %% Fahrwerk
    params.fahrwerk.motion_ratio_vorn     = 1.05;   % Rocker -> Rad
    params.fahrwerk.motion_ratio_hinten   = 1.10;
    params.fahrwerk.federrate_vorn_n_mm   = 130;
    params.fahrwerk.federrate_hinten_n_mm = 140;

    %% Akku (HV)
    params.akku.kapazitaet_kwh            = 6.5;
    params.akku.zellen_reihe              = 144;    % passt zu 144 Zellspannungen
    params.akku.zellen_parallel           = 2;
    params.akku.nennspannung_v            = 533;

    %% Log-Annahmen
    params.log.geschw_in_ms               = 1;      % Faktor speed_can -> m/s
end
