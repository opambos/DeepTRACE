function [] = importResAnDi2(app)
%Imports ResAnDi2 classifications, and integrates them into existing
%results, Oliver Pambos, 28/06/2025.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%condenseStateSequence()
    
    %hardcoded maximum length of ResAnDi2 input sequence - safe as
    %published model has a rigidly-defined input size; if changes are made
    %to the model, this must be updated
    ResAnDi2_lim = 200;
    
    %user identifies file
    app.textout.Value = "Please select a ResAnDi2 results file to import. This typically has the name fov_0.txt";
    [file_name, file_path] = uigetfile('*.txt', 'Select a ResAnDi2-formatted file to import.');
    if isequal(file_name,0)
        app.textout.Value = "User did not provide a results file.";
        return
    end
    filename = fullfile(file_path, file_name);
    
    %open file and copy over data to cell array
    h_file      = fopen(filename,'r');
    raw_lines   = textscan(h_file,'%s','Delimiter','\n'); fclose(h_file);
    raw_lines   = raw_lines{1};
    
    %assemble array of tracks
    N_tracks    = numel(raw_lines);
    arr_tracks  = cell(N_tracks,1);
    for ii = 1:N_tracks
        arr_tracks{ii} = str2double( split(raw_lines{ii},',') );
    end
    
    %init empty (NaN) matrix of tracks, then fill it in with tracks
    max_len      = max(cellfun(@numel, arr_tracks));
    track_matrix = NaN(N_tracks, max_len);
    for ii = 1:N_tracks
        track_matrix(ii,1:numel(arr_tracks{ii})) = arr_tracks{ii};
    end
    
    %ask user whether to use boundaries from ResAnDi2 or manual thresholds
    segment_method = questdlg('Would you like DeepTRACE to extract states directly from ResAnDi2, or use manual tresholding (recommended)?',...
        'ResAnDi2 import', 'Use ResAnDi2 states', 'Set manual threshold(s)', 'Set manual threshold(s)');
    N_tracks = numel(arr_tracks);
    curr_time = datestr(now, 'dd/mm/yy-HH:MM:SS');
    
    %assign subtrack states and boundaries
    switch segment_method
        case 'Use ResAnDi2 states'
            %method 1: use the boundaries provided by ResAnDi2
            
            for ii = 1:N_tracks
                vec          = arr_tracks{ii};
                track_len    = min(vec(end), ResAnDi2_lim);
                N_subtracks = (numel(vec)-1)/4;
                
                %pre-allocate –1 for unused padded region
                curr_labels  = -1*ones(track_len,1);
                
                %loop over segments
                lo_idx = 1;
                for jj = 1:N_subtracks
                    %get state and ending changepoint
                    state  = vec(4*(jj-1)+4);
                    cp     = vec(4*(jj-1)+5) + 1;
                    
                    %assign labels for segment
                    hi_idx = min(cp, track_len);
                    curr_labels(lo_idx:hi_idx) = state;
                    lo_idx = hi_idx + 1;
                    
                    if lo_idx > track_len
                        break;
                    end
                end
                
                %write labels back into results struct
                app.movie_data.results.ResAnDi.LabelledMols{ii}.Mol(1:numel(curr_labels), end) = curr_labels;
                
                %write state sequence and annotation time into results struct
                app.movie_data.results.ResAnDi.LabelledMols{ii}.EventSequence   = condenseStateSequence(curr_labels);
                app.movie_data.results.ResAnDi.LabelledMols{ii}.DateClassified  = curr_time;
            end
            
        case 'Set manual threshold(s)'
            %method 2: display histogram to user, and prompt them to provide boundaries (this is the perferred method)
            
            %display a histogram of ResAnDi2-scaled diffusion coefficients to identify threshold to separate states
            k_cols   = 2 : 4 : size(track_matrix, 2);   %collect every 4th col starting at col 2
            k_vals   = track_matrix(:, k_cols);
            k_vec = k_vals(~isnan(k_vals));
            
            %display histogram
            h_thresh_hist = figure('Name','ResAnDi2 – K histogram');
            histogram(k_vec, 'BinMethod','auto');
            xlabel('k value'); ylabel('count');
            title({'Distribution of normalised diffusion coefficients interpreted by ResAnDi2', ...
                'Please take note of the diffusion coefficient(s) that effectively separate the states', ...
                'For binary classification (Slow, Fast), select 0.5'});
            
            %user provides set of diffusion thresholds to separate states
            thresh_str = inputdlg('Enter threshold values (comma / space-separated):','ResAnDi2 – Thresholds',1,{''});
            thresh_str = thresh_str{1};
            thresholds  = sort( str2double( regexp(thresh_str,'[\d\.\+\-Ee]+','match') ) ).';
            
            %close the histogram
            close(h_thresh_hist);

            %re-insert annotations into ResAnDi2 results struct
            for ii = 1:N_tracks
                track_len   = min(arr_tracks{ii}(end), ResAnDi2_lim);
                curr_labels = zeros(track_len, 1);
                N_subtracks = (size(arr_tracks{ii}, 1) - 1) / 4;
                lo          = 1;
                
                %loop over all subtracks in curr track
                for jj = 1:N_subtracks
                    %get current D*
                    k = arr_tracks{ii}((4 * (jj - 1)) + 2);
                    %bin it into a state using the thresholds
                    curr_state = discretize(k, [-inf, thresholds, inf]);
                    
                    if N_subtracks == 1
                        %if there's only one subtrack just assign single state
                        curr_labels = ones(track_len, 1) .* curr_state;
                    else
                        %get end of subtrack
                        hi = arr_tracks{ii}((4 * (jj - 1)) + 5);
                        
                        %if end of track, fill to end, otherwise fill subtrack and prep next subtrack lower bound
                        if hi >= track_len      %note it is critical that it be >= not == as ResAnDi2 uses 200 as a magic value to indicate 'end of track', not 199 even with it indexing frames from zero
                            curr_labels(lo:end, 1) = curr_state;
                        else
                            curr_labels(lo:hi+1, 1) = curr_state;
                            lo = hi + 2;
                        end
                    end
                end
                %write labels back into results struct - intentionally leaving unannotated frames from ResAnDi2 input length limit here as -1 to enable track inspector comparison
                app.movie_data.results.ResAnDi.LabelledMols{ii}.Mol(1:size(curr_labels, 1), end) = curr_labels;
        
                %write state sequence and annotation time into results struct
                app.movie_data.results.ResAnDi.LabelledMols{ii}.EventSequence   = condenseStateSequence(curr_labels);
                app.movie_data.results.ResAnDi.LabelledMols{ii}.DateClassified  = curr_time;
            end
        otherwise
            app.textout.Value = "Import cancelled.";
            return;
    end
    
    app.textout.Value = "Classifications from ResAnDi2 have been imported successfully.";
end