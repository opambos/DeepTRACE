function [] = genChangepointWeightedMask(app)
%Identifies all changepoints in the training data, and generates a mask for
%weighting the cost function using these regions, Oliver Pambos,
%30/05/2024.
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
%This function generates a 1D binary mask for every track in the training
%data which is 1 in close proximity to each changepoint, and 0 elsewhere.
%This mask is subsequently used for downstream processes such as the
%changepoint-weighted loss function. The output masks are stored in,
%   app.movie_data.results.train_changepoint_masks
%
%Mask size in the current implementation is hardcoded, but this will change
%with a future update to provide user selection from the GUI during
%runtime.
%
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
%None
    
    %mask size
    N = 3;
    
    %generate the empty masks for each track
    changepoint_masks = cell(size(app.movie_data.results.train_labels, 1), 1);
    for ii = 1:size(changepoint_masks, 1)
        changepoint_masks{ii} = zeros(1, size(app.movie_data.results.train_labels{ii, 1}, 2));
    end
    
    %loop over annotated tracks
    for ii = 1:size(app.movie_data.results.train_labels, 1)
        %obtain changepoints
        changepoints = find(diff(double(app.movie_data.results.train_labels{ii, 1})) ~= 0);
        
        %generate the mask
        for jj = 1:length(changepoints)
            %ensure start idx >= 1 & end idx <= size of track
            idx_start = max(1, changepoints(jj) - N + 1);
            idx_end   = min(size(app.movie_data.results.train_labels{ii, 1}, 2), changepoints(jj) + N);
            
            %assign region around changepoint to be 1
            changepoint_masks{ii}(idx_start:idx_end) = 1;
        end
    end
    
    app.movie_data.results.train_changepoint_masks = changepoint_masks;
end