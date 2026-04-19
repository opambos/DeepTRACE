function [] = renumberTracksByCell(app)
%Renumber tracks by cell, 17/05/2024.
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
%Most pipelines define track IDs that are unique globally across the FOV,
%and many are removed during various filtering processes resulting in track
%IDs that appear to jump by hundred or thousands of tracks. This can be
%confusing to the user. Given that [cell_ID mol_ID] are unique across the
%set of all tracks, and are consistently used throughout the app, here we
%reassign all track IDs with an ID local to each cell.
%
%Note that this function may be better called from or after filterTracks
%during data preparation; in a later version this function may move locally
%to that function, or be separated to make it accessible in both scopes.
%
%Update: this code has been moved to a discrete function to provide access
%inside the filterTracks.m scope, enabling re-numbering of tracks following
%the filtering by tracks process.
%
%Inputs
%------
%app        (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findColumnIdx()
    
    %loop over all cells
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        if ~isempty(app.movie_data.cellROI_data(ii,1).tracks)
            %identify the track_id column
            col = findColumnIdx(app.movie_data.params.column_titles.tracks, "MolID");
            
            %extract unique values and their original indices
            [~, ~, ic] = unique(app.movie_data.cellROI_data(ii,1).tracks(:, col), 'stable');
            
            %replace track IDs with their mapped consecutive integers
            app.movie_data.cellROI_data(ii,1).tracks(:, col) = ic;
        end
    end
end