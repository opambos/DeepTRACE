function [] = computeLocPoleDists(app, h_progress)
%Compute distance to membrane for every frame of every tracked molecule,
%22/05/2021.
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
%This was separated from computeLocMemDists() on 22/05/2024 to enable users
%to separately select feature engineering for distance to membrane, and
%distance to pole.
%
%Input
%-----
%movie_data (struct)    main data struct, inherited originally from LoColi
%
%Output
%------
%movie_data (struct)    main data struct, inherited originally from LoColi, now containing distance to membrane
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    
    %loop over every cell
    for ii = 1:N_cells
        curr_mesh = app.movie_data.cellROI_data(ii).mesh;
        curr_tracks = app.movie_data.cellROI_data(ii).tracks;

        N_cols = size(curr_tracks, 2);
        waitbar(ii/N_cells, h_progress, sprintf('Computing pole distances for cell %d of %d', ii, N_cells));
        %loop over all tracked localisations
        for jj = 1:size(curr_tracks, 1)
            %compute distance to nearest pole for every localisation
            poledists = [ pdist([curr_tracks(jj,1:2); curr_mesh(1,1:2)]);...
                          pdist([curr_tracks(jj,1:2); curr_mesh(end,1:2)]) ];
            curr_tracks(jj, N_cols+1) = min(poledists) .* px_scale;
        end
        
       app.movie_data.cellROI_data(ii).tracks = curr_tracks;
    end
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Distance to pole'];
end