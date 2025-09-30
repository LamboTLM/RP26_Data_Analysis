%% Preskript
clearvars -except Data Channels
clc
close all

%% Dateipfade hinzufügen und Loggingdaten auswählen
addpath("Functions")
addpath("Logging_data")

%% Read Loggingdata (MDF4 Data)
Dateiname="RP25e_2025-09-13_18-03-11-driving.mf4";
disp('Laden der Testdaten '+Dateiname)
Vehicle='RP24e';
FileInfo = mdfInfo(Dateiname);
Channels = mdfChannelInfo(Dateiname);
Data_1     = mdfRead(Dateiname);
comparison_mode='Single';      % (Single,H2H)
Data_2   = Data_1;              % only needed in comparison mode

% Vorhandene Loggingfiles in diesem Ordner
% Der Rest befindet sich unter \\fs-extern.hs-regensburg.de\dynamics\00 Saisonuebergreifend\17 Logging

%% Eingrenzen des Timeframes
switch comparison_mode

    case 'Single'
        Time_frame =[0,20000];
        fahrzeitBereich = timerange(seconds(Time_frame(1)), seconds(Time_frame(2)), 'closed');
        Data=Data_1;

    case 'H2H'
        Time_frame_run1 =[1175,1244];
        fahrzeitBereich_1 = timerange(seconds(Time_frame_run1(1)), seconds(Time_frame_run1(2)), 'closed');

        Time_frame_run_2 =[2079+0.8628,2151+0.8628];
        fahrzeitBereich_2 = timerange(seconds(Time_frame_run_2(1)), seconds(Time_frame_run_2(2)), 'closed');

        fahrzeitBereich={fahrzeitBereich_1, fahrzeitBereich_2};
        Data={Data_1, Data_2};
    
    otherwise
        disp('Unkown Comparison mode');

end

%% Analyze data
% try
%     [Cd] = Analyze_potidata(Data,Vehicle);
% catch
%     disp('Error in Potidata analyzation')
% end

%% Erstellen der Plots
disp('Erstellen der Plots')

switch comparison_mode
    case 'Single'
        [f1, Driverdata_axes]       =       visualizeDriverDataSingle(Data,fahrzeitBereich);
        [f2, VehicleData_axes]      =       visualizeVehicleDataSingle(Data,fahrzeitBereich);
        [f3, DynamicsData_axes]     =       visualizeDynamicsDataSingle(Data,fahrzeitBereich);
        [f4, BatteryData_axes]      =       visualizeBatteryDataSingle(Data,fahrzeitBereich);
        [f5, TemperatureData_axes]  =       visualizeTemperatureDataSingle(Data,fahrzeitBereich);
        [f6, TQVData_axes]          =       visualizeTQVDataSingle(Data,fahrzeitBereich);

    case 'H2H'
        [f1, Driverdata_axes]       =       visualizeDriverDataH2H(Data,fahrzeitBereich);
        [f2, VehicleData_axes]      =       visualizeVehicleDataH2H(Data, fahrzeitBereich);
end

% axes=[Driverdata_axes,VehicleData_axes,DynamicsData_axes,BatteryData_axes,TemperatureData_axes];

% linkaxes (axes, 'x');
% set(axes, 'YLimMode', 'manual'); % Fixiert die Y-Achse

