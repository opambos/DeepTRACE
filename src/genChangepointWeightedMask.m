function [] = genChangepointWeightedMask(app)
%Identifies all changepoints in the training data, and generates a mask for
%weighting the cost function using these regions, 30/05/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
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