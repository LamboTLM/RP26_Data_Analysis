function [Unpacked_data] = Unpack_data(Data,Groupnumber,variabel_name)
%UNPACK_DATA Unpacks data from mf4 files for use ini Matlab
%   Load the

Unpacked_data=Data(Groupnumber);
Unpacked_data=Unpacked_data{1};

Unpacked_data = Unpacked_data(:, variabel_name);

end