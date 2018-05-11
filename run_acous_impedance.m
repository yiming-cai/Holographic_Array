%% Documentations
% Data given by Emma
% Note that the dimensions of the matrices are as below:
%   Data are in the time domain. 
%   The format of the two files is a 3D matrix whose dimensions are (285 x 2000 x 855)
%       285 is the number of nodes over the surface.
%       2000 is the number of time steps. The time vector goes from 0 to 0.08 s. 
%       The time step is 4e-5 s.
%       855 is the number of snapshots (corresponding to the number of realizations).

%% Load all the simulation data
load( "p_time_nodes_int.mat" );
load( "p_time_nodes_ext.mat" );
load( "p_time_nodes.mat");

%% Transform the data
% 1st dim: snapshot_id
% 2nd dim: sensor_id
% 3rd dim: sample_id
p_time_nodes_ext = permute( p_time_nodes_ext, [ 3, 1, 2 ] );
p_time_nodes_int = permute( p_time_nodes_int, [ 3, 1, 2 ] );
p_time_nodes = permute( p_time_nodes, [ 3, 1, 2 ] );

%% Do the calculations
[pp, pv] = acous_arr_impedance_ineff( p_time_nodes_ext, p_time_nodes_int, 0.00004 );
load( "surface_data.mat" );

%% save the results to disk
save( 'post_impedance_workspace.mat', '-v7.3' );

