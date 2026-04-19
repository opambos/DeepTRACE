function [] = computeLocMemDists(app, h_progress)
%Compute distance to membrane for every frame of every tracked molecule,
%19/12/2021.
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
%Uses distance-to-membrane code I wrote for a previous project in 2018.
%This function computes the distance of each localistion to the nearest
%point of any line within the associated cell mesh by repeatedly calling
%findPiontToMeshDist(), also developed for the same project in 2018.
%
%Note that the mesh used here is reformattted from a microbeTracker mesh to
%an Nx2 matrix of (x,y) coordinates which links back to its start point.
%Manipulation of this mesh is performed prior to passing to call to
%findPointToMeshDist() such that this matrix manipulation occurs only once
%for each cell/mesh in order to minimise computational overhead.
%
%Input
%-----
%movie_data (struct)    main data struct, inherited originally from LoColi
%
%Output
%------
%movie_data (struct)    main data struct, inherited originally from LoColi,
%                           now containing distance to membrane (in nm)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findPointToMeshDist()
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    
    %loop over every cell
    for ii = 1:N_cells
        if isempty(app.movie_data.cellROI_data(ii).tracks)
            continue;
        end
        
        N_cols = size(app.movie_data.cellROI_data(ii).tracks, 2);
        
        %reformat mesh into Nx2 format looping back to first vertex
        mesh = [app.movie_data.cellROI_data(ii).mesh(:,1:2); flipud(app.movie_data.cellROI_data(ii).mesh(1:end-1,3:4))];

        %ensure heavily nested access to tracks is only performed once for each cell
        curr_tracks_x = app.movie_data.cellROI_data(ii).tracks(:,1);
        curr_tracks_y = app.movie_data.cellROI_data(ii).tracks(:,2);
        px_scale = app.movie_data.params.px_scale;
        
        %pre-allocate new column data to enable efficient single write operation
        temp_col = zeros(size(curr_tracks_x));

        waitbar(ii/N_cells, h_progress, sprintf('Computing membrane distances for cell %d of %d', ii, N_cells));
        %loop over all tracked localisations
        for jj = 1:size(curr_tracks_x, 1)
            %compute distance to nearest membrane for every localisation in nm
             temp_col(jj) = findPointToMeshDist(curr_tracks_x(jj), curr_tracks_y(jj), mesh) .* px_scale;
        end
        app.movie_data.cellROI_data(ii).tracks(:, N_cols+1) = temp_col;
    end
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Distance to nearest membrane (nm)'];
end