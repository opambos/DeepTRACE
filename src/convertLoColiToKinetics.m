function [movie_data] = convertLoColiToKinetics(movie_data)
%Processes LoColi struct to incorporate the StormTracker data discarded by
%LoColi into the tracks matrices, 25/04/2023.
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
%Modifies the data struct to re-incorporate data from the StormTracker
%localisation data into the tracks matrix for each cell. LoColi is a
%non-public data pipeline local to the Kapanidis lab, Oxford. This software
%performs SMLM tracking of a localised data file, and discards from the
%tracks matrices useful features related to the Gaussian fitting process
%used by the localistion algorithm, however this data is retained inside 
%'.localizationData'. This function searches for that data and
%re-incorporates it into the tracks matrices.
%
%Input
%-----
%movie_data (struct)    main struct from LoColi
%
%Output
%------
%movie_data (struct)    main struct from LoColi with modifications for use
%                           in kinetics software
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%appendLocsToTracks() - local to this .m file
    
    h_convert_waitbar = waitbar(0, "Preparing to translate data from LoColi to DeepTRACE format....");
    %set(h_convert_waitbar, 'WindowStyle', 'modal');
    
    N_cells = size(movie_data.cellROI_data, 1);
    N_extra_cols = max(0, size(movie_data.cellROI_data(1).localizationData, 2) - 11);

    single_cell = false;
    if N_cells == 1
        single_cell = true;
    end
    %loop over all cells
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_convert_waitbar, sprintf('Translating data from LoColi to DeepTRACE format for cell %d/%d', ii, N_cells));
        %check track data exists, then append the relevant data to each row in tracks file
        if ~isempty(movie_data.cellROI_data(ii).tracks)
            movie_data.cellROI_data(ii).tracks = appendLocsToTracks(movie_data.cellROI_data(ii).tracks, movie_data.cellROI_data(ii).localizationData, single_cell, h_convert_waitbar, N_extra_cols);
        end
    end
    
    close(h_convert_waitbar);
    
    %get names for the additional columns outside of LoColi/stormtracker Gaussian fit standard
    arbitrary_features = {};
    if N_extra_cols > 0
        prompt = sprintf("Enter %d comma-separated name(s) for the additional features in localizationData:", N_extra_cols);
        user_input = inputdlg(prompt, 'Additional Feature Names', [1 60]);
    
        if isempty(user_input) || isempty(user_input{1})
            error("convertLoColiToKinetics:MissingFeatureNames", "User cancelled or did not enter any names.");
        end
    
        arbitrary_features = strtrim(split(user_input{1}, ','));
    
        if numel(arbitrary_features) ~= N_extra_cols
            error("convertLoColiToKinetics:MismatchedFeatureNames", ...
                  "You entered %d name(s), but %d additional columns were detected.", ...
                  numel(arbitrary_features), N_extra_cols);
        end
    end

    %generate the standard LoColi column titles
    movie_data.params.column_titles.tracks = { 'x (px)',...
                                               'y (px)',...
                                               'Frame',...
                                               'MolID',...
                                               'Brightness from stormtracker',...
                                               'Background',...
                                               'Peak intensity',...
                                               'Standard deviation minor axis',...
                                               'Standard deviation major axis',...
                                               'Theta (angle of elliptical Gauss fit relative to image)',...
                                               'Eccentricity of elliptical Gauss fit',...
                                               'Cell ID'};
    
    if N_extra_cols >= 1
        movie_data.params.arbitrary_feature_cols = 13 : 12+N_extra_cols;
        movie_data.params.arbitrary_features = arbitrary_features';
    else
        movie_data.params.arbitrary_feature_cols    = [];
        movie_data.params.arbitrary_features        = [];
    end
end


function [new_tracks] = appendLocsToTracks(tracks, locs, single_cell, h_convert_waitbar, N_extra_cols)
%Identifies and concatenates removed localisation data to the corresponding
%track, 25/04/2023.
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
%
%Input
%-----
%tracks             (mat)       individual track data
%locs               (mat)       all localisation data in the current cell
%single_cell        (bool)      holds true if there is a single cell (as
%                                   with some simulation types, allowing
%                                   finer updates
%h_convert_waitbar  (handle)    waitbar handle - used here if there is only
%                                   a single cell to provide finer updates
%N_extra_cols       (int)       number of additional arbitrary feature
%                                   columns beyond default number
%
%Output
%------
%new_tracks (mat)   individual track data concatenated with missing
%                       localisation data
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %new matrix to store the appended data
    new_tracks = tracks;

    N_rows = size(tracks, 1);
    N_cols = size(locs, 2);

    %duplicate code here is intentional: single_cell bool test outside loops ensures granular mod()
    %tests are not applied to typical datasets in which progress is displayed per-cell
    if single_cell
        waitbar(0, h_convert_waitbar, sprintf('Integrating localisation fitting data (0/%d)', N_rows));

        %loop over rows in tracks
        for ii = 1:N_rows
            %update waitbar in groups of 1,000 rows
            if mod(ii, 1000) == 0
                waitbar(ii/N_rows, h_convert_waitbar, sprintf('Integrating localisation fitting data (%d/%d)', ii, N_rows));
            end

            %create a logical index for the rows in locs that match the current row in tracks
            locs_rows = (locs(:, 2) == tracks(ii, 1)) & (locs(:, 3) == tracks(ii, 2)) & (locs(:, 1) == tracks(ii, 3));

            %append the contents of columns 4 to end of locs to the current row in new_tracks
            new_tracks(ii, 5:(N_cols + 1)) = locs(locs_rows, 4:end);        %check with no arb, and 1 arb
        end
    else
        %loop over rows in tracks
        for ii = 1:N_rows
            %create a logical index for the rows in locs that match the current row in tracks
            locs_rows = (locs(:, 2) == tracks(ii, 1)) & (locs(:, 3) == tracks(ii, 2)) & (locs(:, 1) == tracks(ii, 3));

            %append the contents of columns 4 to 10 of locs to the current row in new_tracks
            new_tracks(ii, 5:(12 + N_extra_cols)) = locs(locs_rows, 4:end);
        end
    end
end