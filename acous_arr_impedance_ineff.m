% s_a and s_b are the unprocessed signals from the acoustic array
% Each is a 3D matrix with the following dimension definition:
% 1st dim: snapshot_id -> o longer theta but snapshot
% 2nd dim: sensor_id: 1 - 512
% 3rd dim: sample_id
% delta_t should be the time between each sample input
function [pp,pv,zs] = acous_arr_impedance_ineff( s_a, s_b, delta_t )

    %% DEFINE SOME CONSTANTS HERE
    % define some constant variables, which might need to be changed
    
    dist_surface = 0.005; % distance between the surface and sensor in meter (?)  
    dist_sensor = 2 * dist_surface; % distance between the sensors
    density = 1.25; % density of the medium, which is air
    speed_sound = 343; % speed of sound in air
    z_ref = density * speed_sound; % impedance value reference
    
    %% CHECK THE MATRIX SIZES
    % check if the two matrices have the same size
    [count_snapshot, count_sensor, count_sample] = size(s_a);
    [count_snapshot_b, count_sensor_b, count_sample_b] = size(s_b);
    if count_snapshot ~= count_snapshot_b ...
            || count_sensor ~= count_sensor_b ...
            || count_sample ~= count_sample_b 
        
        fprintf("The size of input matrices do not match\n");
        pp = 0; pv = 0;
        return;
    end
    
    %% PLOT A TIME DOMAIN GRAPH HERE FOR SANTIY CHECK
    
    %% CONVERT TO THE FREQUENCY DOMAIN
    tic;
    
    %%% might need to partition into several parts first
    %%% so that there is enough memory to be allocated
    %s_a = gpuArray(s_a);
    %s_b = gpuArray(s_b);
    
    % find the frequency values of the results of fft
    % the omega should be in the range of 0 to 1/delta_t or 1/delta_t/2
    f_delta = 1 / (delta_t * count_sample);
    fs = 1 / delta_t;
    raw_count_omega = count_sample ;
    raw_omega_vec = 2 * pi * linspace(0, fs - f_delta, raw_count_omega );

    % truncate the vectors
    count_omega = uint32( raw_count_omega/2 );
    omega_vec = raw_omega_vec( 1 : count_omega );
    
    % perform the fft on the third dimension, which is the time domain
    % right now the dimension is defined as:
    % 1st dim: snapshot
    % 2nd dim: sensor
    % 3rd dim: omega
    % note: fft is natively supported by the parallel computing toolkit
    %%% possibly change the count_sample to be a power of 2
    %%% we will need to extract only the first spectrum (first half)
    p_a = fft(s_a, count_sample, 3);
    p_b = fft(s_b, count_sample, 3);
    
    % for now, let p_s = average of p_a and p_b
    p_s = (p_a + p_b) / 2;
    
    % v_s = 1/(+-i*omega) * (p_b - p_a)/ ( density * dist )
    %%% suppress the for loop 
    % some useful functions: repmat permute reshape 
    
    omega_mat = repmat( raw_omega_vec, count_snapshot, 1 ,count_sensor );
    omega_mat = permute( omega_mat, [1, 3, 2] );
    v_s = ( (p_b - p_a) ./ ( density * dist_sensor ) ) ./ (1i * omega_mat);
     
    time_fft = toc;
    fprintf("time to find p_s and v_s: " + time_fft + "sec\n");
    
    %% PLOT A FREQUENCY DOMAIN GRAPH HERE FOR SANITY CHECK
    
    
    %% SAVE THE DATA 
    
    % try to reverse fft v_s and p_s to check the results
    save( 'surface_data','v_s','p_s', 'omega_vec','raw_omega_vec','-v7.3' );
    
    %% Truncate the data and throw away unnecessary negative parts
    p_s = p_s(:,:,1:count_omega);
    v_s = v_s(:,:,1:count_omega);
    
    %% FIND THE PP AND PV MATRICES
    
    tic;
    
    % initialize new arrays for the output
    pp =  zeros( count_sensor, count_sensor, count_omega ) ;
    pv =  zeros( count_sensor, count_sensor, count_omega ) ;
    
    %pp = gpuArray(pp);
    %pv = gpuArray(pv);
    
    % right now it is O( count_omega * count_snapshot * count_sensor^2 )
    for idx_omega = 1:count_omega
        
        for idx_snapshot = 1:count_snapshot
            
            % make it count_sensorx1 * 1xcount_sensor to generate the desired matrix
            % NOTE: this part is taking about 25% of the time
            p_i = transpose( p_s( idx_snapshot, :, idx_omega ) );
            p_j = p_i';
            v_j = transpose( v_s( idx_snapshot, :, idx_omega ) )';
            
            % pp = <p_i, p_j*>, ps = <p_i, v_j*> for each omega
            % NOTE: this part is taking about 70% of the time
            pp( :, :, idx_omega) = pp( :, :, idx_omega) + p_i * p_j;
            pv( :, :, idx_omega) = pv( :, :, idx_omega) + p_i * v_j;
        end
        
        if mod( idx_omega, 5 ) == 0
            fprintf ("Current Progress: %.2f percent\n", float(idx_omega)/float(count_omega)*100);
        end
    end
    
    pp = pp ./ count_snapshot;
    pv = pv ./ count_snapshot;
    
    time_conjugate = toc;
    fprintf("time to find <p,p*> and <p,v*>: " + time_conjugate + "sec\n");
    
    % we need a full rank, but pv is not a full rank matrix
    % Things to try: singular value decomposition -> A=USV <-- U,V are the
    % vector of eigenvectors, while S is the eigenvalue vector
    % The number of eigenvalues correspond to the rank of the matrix
    % zs = pp * inv(pv);
    
    % zs = pp ./ pv;
    
    return;
end

