function [] = engineerCellCoords(app, h_progress)
%Feature engineering of the cellcular coordinates for all cells,
%23/05/2024.
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
%This function obtains cellular spatial coordinates for every tracked
%localisation in the dataset through repeated calls to
%convertToCellCoords(), as part of the feature engineering process. This
%engineered feature is considered obligatory as it is necessary for
%downstream analysis such as heatmaps, projections, and visualisation of
%the flow of states.
%
%Cell mesh manipulations are performed once for each cell in this handling
%function to minimise repetition within convertToCellCoords().
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
%convertToCellCoords()
    
    waitbar(0, h_progress, 'Computing cell coordinates');
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    for ii = 1:N_cells
        N_locs = size(app.movie_data.cellROI_data(ii).tracks, 1);
        
        if N_cells == 1
            waitbar(ii/N_cells, h_progress, sprintf('Computing cell coordinates, as only one cell is present, progress will be in batches of 1,000 localisations: 0/%d', N_locs));
        else
            waitbar(ii/N_cells, h_progress, sprintf('Computing coordinates for cell %d of %d', ii, N_cells));
        end
        
        if isempty(app.movie_data.cellROI_data(ii).tracks)
            continue;
        end
        
        %ensure heavily nested access to tracks is only performed once for each cell
        curr_tracks_x = app.movie_data.cellROI_data(ii).tracks(:,1);
        curr_tracks_y = app.movie_data.cellROI_data(ii).tracks(:,2);
        curr_mesh = app.movie_data.cellROI_data(ii).mesh;
        
        %obtain the midline
        midline = curr_mesh(1, 1:2);
        midline = [midline; (curr_mesh(2:end-1, 1) + curr_mesh(2:end-1, 3))/2, (curr_mesh(2:end-1,2) + curr_mesh(2:end-1,4))/2];
        midline = [midline; curr_mesh(end, 1:2)];
        
        %compute its total contour length
        contour_len = 0;
        for jj = 1:size(midline, 1) - 1
            contour_len = contour_len + pdist([midline(jj,:); midline(jj+1,:)]);
        end
        
        %obtain left and right hittest regions of the cell mesh
        mesh_left   = [midline(2:end-1,:); flipud(curr_mesh(:, 1:2))];
        mesh_right  = [curr_mesh(:, 3:4); flipud(midline(2:end-1,:))];
        
        %pre-allocate matrix to hold all coordinate data for current track [longitude, latitude, longitude_abs, latitude_abs]
        track_coord_data = zeros(N_locs, 4);
        
        %get cellular coordinates for entire track
        for jj = 1:N_locs
            %if there is only one cell (as is case of some simulation types) then update in batches of 1k locs; note the short-circuit logical AND operation here, there is no need to refactor with nested conditional statement
            if N_cells == 1 && mod(jj, 1000) == 0
                waitbar(jj/N_locs, h_progress, sprintf('Computing cell coords for localisation: %d/%d', jj, N_locs));
            end
            [track_coord_data(jj,1), track_coord_data(jj,2), track_coord_data(jj,3), track_coord_data(jj,4), ~] = ...
                convertToCellCoords(curr_tracks_x(jj), curr_tracks_y(jj), curr_mesh, mesh_left, mesh_right, midline, contour_len);
        end
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, track_coord_data];
    end
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, {'Longitude', 'Latitude', 'Longitude (absolute)', 'Latitude (absolute)'}];
end