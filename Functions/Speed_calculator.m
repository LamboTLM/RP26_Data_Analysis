function [V_tire_km_h] = Speed_calculator(Wheel_RPM,Vehicle)
%Speed_calculator Calculates speed in km/h from wheel RPM
%   Load Vehicle data with Gearratios and dynamic rollradius of tyres

[~,~,~,~,~,Gear_Ration,Dyn_Tyr_Rad] = Load_Vehicle(Vehicle);
U_tire=2*Dyn_Tyr_Rad*pi/1000;
V_tire_km_h = ((Wheel_RPM/Gear_Ration) * U_tire)*3.6 / 60; % Speed in km/h

V_tire_km_h=smooth(V_tire_km_h,100);

end