function [m,k_spring_front,k_spring_rear,Aero_A,Aero_P,Gear_Ration,Dyn_Tyr_Rad] = Load_Vehicle(Vehicle_name)

switch Vehicle_name
    case 'RP24e'
        m=210;                      % Fahrzeugleermasse
        k_spring_front=55;          % Federsteifigkeit vorne
        k_spring_rear=38;           % Federsteifigkeit hinten
        Aero_A=1.09710476931747;    % Stirnfläche in m^2
        Aero_P=1.2041;              % Luftdruck in Bar
        Gear_Ration=10.96;          % Getriebe übersetzung
        Dyn_Tyr_Rad=(16*25.4)/2;    % Dynamischer Rollradius
    case 'RP25e'
        m=341-68;                   % Fahrzeugleermasse
        k_spring_front=55;          % Federsteifigkeit vorne
        k_spring_rear=38;           % Federsteifigkeit hinten
        Aero_A=1;                   % Stirnfläche in m^2
        Aero_P=1;                   % Luftdruck in Bar
        Gear_Ration=10.756;          % Getriebe übersetzung
        Dyn_Tyr_Rad=(16*25.4)/2;    % Dynamischer Rollradius
    otherwise
        disp('Unknown Vehicle name')
end
end
