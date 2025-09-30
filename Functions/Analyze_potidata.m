function [Cd] = Analyze_potidata(Data,Vehicle)
%Analyze_potidata analayzes data measured from linear potentiometers at the
%springs and dampers. Inputs are in milimeter over time
%   Die Funktion Analyze_potidata arbeitet wie folgt:
%   1. Auspacken der Bestehenden daten
%   Auspacken der daten vom Fahrzeug darunter Masse, springstiffness vorne
%   und hinten die Stirnfläche sowie das übersetzungsverhältnis das ganze ist
%   gesteuert durch die Vehicle data function welche die wichtigesten
%   Fahrzeugdaten lädt

%% Laden der Loggingdaten
INS_vel_x_can = extractTimetableFromCell(Data,'INS_vel_x_can');
INS_vel_y_can = extractTimetableFromCell(Data,'INS_vel_y_can');

% INS Beschleunigung
INS_acc_x_can = extractTimetableFromCell(Data,'INS_acc_x_can');
INS_acc_y_can = extractTimetableFromCell(Data,'INS_acc_y_can');
INS_acc_z_can = extractTimetableFromCell(Data,'INS_acc_z_can');

INS_data=synchronize(INS_vel_x_can,INS_vel_y_can,INS_acc_x_can,INS_acc_y_can,INS_acc_z_can);

% Potidaten
rocker_fl_can = extractTimetableFromCell(Data,'rocker_fl_can');
rocker_fr_can = extractTimetableFromCell(Data,'rocker_fr_can');
rocker_rl_can = extractTimetableFromCell(Data,'rocker_rl_can');
rocker_rr_can = extractTimetableFromCell(Data,'rocker_rr_can');

rocker_data=synchronize(rocker_fl_can,rocker_fr_can,rocker_rl_can,rocker_rr_can);

% Motordrehzahlen
unitek_fl_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_fl_speed_motor_ist_can');
unitek_fr_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_fr_speed_motor_ist_can');
unitek_rl_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_rl_speed_motor_ist_can');
unitek_rr_speed_motor_ist_can = extractTimetableFromCell(Data,'unitek_rr_speed_motor_ist_can');

motor_speed_data=synchronize(unitek_fl_speed_motor_ist_can, unitek_fr_speed_motor_ist_can, unitek_rl_speed_motor_ist_can, unitek_rr_speed_motor_ist_can);

Poti_analysy_data=synchronize(INS_data, rocker_data, motor_speed_data,"union","spline");

%% Definieren der Fahrzeugdaten
[~,k_spring_front,k_spring_rear,Aero_A,Aero_P,~,~]=Load_Vehicle(Vehicle);

%% Berechnung der Radlasten
% Berechnen der Radlasten
% Berechnung der Frontachse
F_FR=Poti_analysy_data.rocker_fr_can./k_spring_front;
F_FL=Poti_analysy_data.rocker_fr_can./k_spring_front;
F_A=F_FL+F_FR;

% Berechnung der Heckachse
F_RR=Poti_analysy_data.rocker_rr_can./k_spring_rear;
F_RL=Poti_analysy_data.rocker_rl_can./k_spring_rear;
F_RA=F_RR+F_RL;

% Fahrzeuggesamtkraft
F_GE=F_A+F_RA;

% Berechnung der Geschwindigkeit ohne slip
V_FL = Speed_calculator(Poti_analysy_data.unitek_fl_speed_motor_ist_can,Vehicle);
V_FR = Speed_calculator(Poti_analysy_data.unitek_fr_speed_motor_ist_can,Vehicle);
V_RL = Speed_calculator(Poti_analysy_data.unitek_rl_speed_motor_ist_can,Vehicle);
V_RR = Speed_calculator(Poti_analysy_data.unitek_rr_speed_motor_ist_can,Vehicle);

V_mean=(V_FL+V_FR+V_RL+V_RR)/4;

%Cd Berechnen
Cd(:,2)=(F_GE.*2)./(Aero_P*Aero_A*(V_mean.^2));
Cd(Cd > 5) = 0;
Cd(Cd < -5) = 0;
Cd(:,1)=F_GE(:,1);
plot(Poti_analysy_data.t,Cd);
end