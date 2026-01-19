function [] = getFeatureStats(app, overwrite)
%Compute global feature stats across tracks data, Oliver Pambos,
%28/06/2025.
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
%Provide rapid access to feature stats for a wide range of different track
%analysis tasks.
%
%Inputs
%------
%app        (handle)    main GUI handle
%overwrite  (bool)      boolean to determine whether to overwrite existing
%                           feature stats
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %ignore if ranges already exist
    if (isfield(app.movie_data,"params") && isfield(app.movie_data.params,"feature_stats") && overwrite == false) || ~isfield(app.movie_data.params, "column_titles") || isempty(app.movie_data.cellROI_data)
        return
    end
    
    %init vars
    N_features  = numel(app.movie_data.params.column_titles);   %this also captures the class label
    global_min  =  inf(1, N_features);
    global_max  = -inf(1, N_features);
    sum_feat    =  zeros(1,N_features);
    sum_sqrt    =  zeros(1,N_features);
    total_rows  =  0;
    
    for ii = 1:numel(app.movie_data.cellROI_data)
        tracks      = app.movie_data.cellROI_data(ii).tracks;
        
        %skip empty cells
        if isempty(tracks)
            continue;
        end
        
        global_min   = min(global_min, min(tracks,[],1), 'omitnan');
        global_max   = max(global_max, max(tracks,[],1), 'omitnan');
        
        sum_feat   = sum_feat + sum(tracks,   1,'omitnan');
        sum_sqrt    = sum_sqrt  + sum(tracks.^2,1,'omitnan');
        total_rows = total_rows + size(tracks,1);
    end
    
    %compute mean and stdev globally
    mu    = sum_feat ./ total_rows;
    var   = max(sum_sqrt./total_rows - mu.^2, 0);
    sigma = sqrt(var);
    
    %store stats back in main struct
    app.movie_data.params.feature_stats = [global_min; global_max; mu; sigma];
end