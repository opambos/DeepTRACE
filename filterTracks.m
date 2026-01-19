function [filter_status] = filterTracks(app)
%Filter tracks to ensure there is only one track per cell, Oliver Pambos,
%11/09/2020.
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
%Note that this function currently modifies the contents of
%movie_data.cellROI_data(ii).tracks, renumbering tracks as it goes. If there
%is a need to maintain the original data, then these filtered tracks should
%be written to a new sub-struct.
%
%movie_data.cellROI_data(ii).nMolecules in intentionally not updated after
%filtering to retain the original mol_IDs from LoColi in case this is later
%useful. nMolecules consequently stores the number of molecules originally
%identified by LoColi.
%
%Inputs
%------
%app            (handle)    main GUI handle
%
%Output
%------
%filter_status  (str)       reports the status of the filtering process to
%                               the calling function; this ensures user is
%                               notified adequately, and enables downstream
%                               data preparation processes to be cancelled
%                               inside calling function without having to
%                               return error(). Values are,
%                                   "Failed" - default
%                                   "Cancelled by user" - use opts to
%                                       cancel when localisation data is
%                                       unavailable
%                                   "Filtered by localisations" -
%                                       successful filtering against all
%                                       localisations in same cell
%                                   "Successfully truncated by tracks" -
%                                       overlapping tracks were truncated
%                                   ""
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%removeEmptyCells()     - local to this .m file
%filterByAllLocs()      - local to this .m file
%identifyOverlaps()     - local to this .m file
%identifyShortTracks()  - local to this .m file
%applyMemoryParameter() - local to this .m file
    
    app.textout.Value   = "Track filtering process is in progress. This may take some time to complete.";
    filter_status       = "Failed";
    
    %localise params that require multiple accesses
    track_buffer    = app.movie_data.params.track_buffer;
    min_track_len   = app.movie_data.params.min_track_len;
    mem_param       = app.movie_data.params.mem_param;
    
    %use current state of dropdown boxes to control a switch statement for how the tracks should be filtered
    selection_ID = [app.movie_data.params.filtering_method '_' app.movie_data.params.filter_against];
    
    %if user has asked to filter against localisations and there is no localisation data
    if (strcmp(selection_ID, 'truncate_localisations') || strcmp(selection_ID, 'eliminate_localisations')) && ~isfield(app.movie_data.cellROI_data, "localizationData")
        continue_filtering = questdlg('Localization data is not available for your dataset. Would you like to continue filtering against all tracks instead?', ...
        'Localization Data Not Available', ...
        'Continue', 'Cancel', 'Cancel');
        
        %ask user whether to continue filtering
        switch continue_filtering
            case 'Continue'
                %re-task the code to filter against tracks
                parts = strsplit(selection_ID, '_');
                selection_ID = [parts{1} '_tracks'];
            case 'Cancel'
                filter_status = "Cancelled by user";
                app.textout.Value = 'Track filtering was canceled by user, due to lack of localization data.';
                return;
        end
    end
    
    %record filtering method
    app.movie_data.params.filtering_method  = selection_ID;
    
    switch selection_ID
        case {'truncate_localisations', 'eliminate_localisations'}
            
            app.movie_data = filterByAllLocs(app.movie_data, app.movie_data.params.filter_tolerance);
            filter_status = "Filtered by localisations";
            
        case 'truncate_tracks'
            
            focus(app.DeepTRACEUIFigure);
            f = waitbar(0,'Processing tracks; please wait....','Name','Filtering tracks');
            %identify clashing tracks, and short tracks
            %loop over all cells
            for ii = 1:size(app.movie_data.cellROI_data,1)
                if isempty(app.movie_data.cellROI_data(ii).tracks)
                    continue;
                end

                %identify all tracks that fall within 'buffer' frames of one another,
                %and identify all overlapping frames
                [~, overlaps] = identifyOverlaps(app.movie_data.cellROI_data(ii).tracks, track_buffer);
                
                %delete overlapping frames
                    % idx = find(app.movie_data.cellROI_data(ii).tracks(:,3) == overlaps(kk));
                    % app.movie_data.cellROI_data(ii).tracks(idx,:) = [];
                    app.movie_data.cellROI_data(ii).tracks(ismember(app.movie_data.cellROI_data(ii).tracks(:,3), overlaps), :) = [];
                %apply memory parameter, tracks not meeting this parameter are split
                app.movie_data.cellROI_data(ii).tracks = applyMemoryParameter(app.movie_data.cellROI_data(ii).tracks, mem_param);
                
                %if tracks still exist, detect and delete the short tracks
                if ~isempty(app.movie_data.cellROI_data(ii).tracks)
                    short_tracks = identifyShortTracks(app.movie_data.cellROI_data(ii).tracks, min_track_len);
                    for kk = 1:size(short_tracks, 1)
                        idx = find(app.movie_data.cellROI_data(ii).tracks(:,4) == short_tracks(kk));
                        app.movie_data.cellROI_data(ii).tracks(idx,:) = [];
                    end
                end

                waitbar(ii/size(app.movie_data.cellROI_data,1), f, strcat('Processing cell #', num2str(ii), {' '}, 'of', {' '}, num2str(size(app.movie_data.cellROI_data,1))));
            end
            

            %renumber tracks again with sequential numbers (handles rare track_ID ordering errors arising from split tracks, which causes a downstream issue with engineering the time from start of track feature)
            if ~strcmp(app.movie_data.params.pipeline, "LoColi")
                renumberTracksByCell(app);
            end

            close(f);
            filter_status = "Successfully truncated by tracks";
            
        case 'eliminate_tracks'
            
            f = waitbar(0,'Processing tracks, please wait....','Name','Filtering tracks');
            %identify clashing tracks, and short tracks
            %loop over all cells
            for ii = 1:size(app.movie_data.cellROI_data,1)
                %identify all tracks that fall within 'buffer' frames of one another
                %and identify all overlapping frames
                [track_conflicts, ~] = identifyOverlaps(app.movie_data.cellROI_data(ii).tracks, track_buffer);
                
                    %compile a list of short tracks
                    short_tracks = identifyShortTracks(app.movie_data.cellROI_data(ii).tracks, min_track_len);
                    
                    %combine with short tracks and tidy up
                    del_tracks = cat(1, track_conflicts, short_tracks);
                    del_tracks = unique(del_tracks);
                    
                    for kk = 1:size(del_tracks, 1)
                        idx = find(app.movie_data.cellROI_data(ii).tracks(:,4) == del_tracks(kk));
                        app.movie_data.cellROI_data(ii).tracks(idx,:) = [];
                    end
                    
                waitbar(ii/size(app.movie_data.cellROI_data,1), f, strcat('Processing cell #', num2str(ii), {' '}, 'of', {' '}, num2str(size(app.movie_data.cellROI_data,1))));
            end
            close(f);
            filter_status = "Successfully eliminated by tracks";

        case {'keep all_tracks', 'keep all_localisations'}
            %currently do nothing
        otherwise
    end
end


function [track_conflicts, overlaps] = identifyOverlaps(tracks_file, track_buffer)
%Compile a list of all tracks overlapping with reference track, Oliver
%Pambos, 11/09/2020.
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
%Note that this subroutine cannot be replaced with a simple comparison of
%frame numbers since the memory parameter means that tracks can contain
%empty frames, and these also need to be incorporated into any downstream
%processing of tracks. The code therefore appears more convoluted than you
%might expect on first viewing, but this is required for robust downstream
%analysis.
%
%Inputs
%------
%tracks_file    (mat)   the contents of app.movie_data.cellROI_data(ii).tracks for a given cell 'ii'
%track_buffer   (int)   frame buffer between tracks
%
%Output
%------
%track_conflicts    (vec)   column vector of the track_IDs which contain at least one data point between frame lim_lo, and frame lim_hi (inclusive)
%overlaps           (vec)   column vector of frame #s of all overlaps - this also includes frames linked via the memory parameter
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    track_conflicts = [];                       %stores a list of tracks that fall within this range
    track_list      = unique(tracks_file(:,4)); %yes I realise the issue here, but this makes it more portable
    overlaps        = [];                       %column vector that stores every frame number of overlap between tracks (even if mem param causes no loc to be present in a frame)
    
    %loop over all track_IDs
    for ii = 1:size(track_list, 1)
        %find limits of screened track
        lim_lo =   min(tracks_file(tracks_file(:,4) == track_list(ii), 3));     %first frame of the frame series to search
        lim_hi =   max(tracks_file(tracks_file(:,4) == track_list(ii), 3));     %last frame of a the frame series to search
        
        %generate a track list that does not include track ii
        reduced_list = track_list(track_list ~= track_list(ii));
        
        %loop over the reduced track list
        for jj = 1:size(reduced_list,1)
            %find limits of next track in reduced list for comparison
            lower   = min(tracks_file(tracks_file(:,4) == reduced_list(jj,1), 3));
            higher  = max(tracks_file(tracks_file(:,4) == reduced_list(jj,1), 3));
            
            %this determines whether there is an overlap - for 'eliminate' filtering method
            if (lim_lo - track_buffer < lower && lim_hi + track_buffer > lower) || (lim_lo - track_buffer < higher && lim_hi + track_buffer > higher)
                track_conflicts = cat(1, track_conflicts, reduced_list(jj));
            end
            
            %identifies the frames #s in which tracks appear
            if (lim_lo <= lower && lim_hi >= higher)                %if track jj is contained entirely within track being interrogated
                overlaps = cat(1,overlaps,[lower:higher]');
            elseif (lim_lo >= lower && lim_hi <= higher)            %if track being interrogated is contained entirely within track jj
                overlaps = cat(1,overlaps,[lim_lo:lim_hi]');
            elseif (lim_lo <= lower && lim_hi >= lower)             %test for partial overlap
                overlaps = cat(1,overlaps,[lower:lim_hi]');
            elseif (lim_lo <= higher && lim_hi >= higher)           %test for other partial overlap
                overlaps = cat(1,overlaps,[lim_lo:higher]');
            end
        end
    end
    
    overlaps        = unique(overlaps);
    track_conflicts = unique(track_conflicts);
end


function [local_del_list] = identifyShortTracks(tracks_file, min_track_len)
%Identify tracks shorter than the minimum track length, Oliver Pambos,
%11/09/2020.
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
%tracks_file    (mat)   the contents of app.movie_data.cellROI_data(ii).tracks for a given cell 'ii'
%min_track_len  (int)   minimum track length, in frames
%
%Output
%------
%local_del_list (vec)   column vector of track_IDs shorter than the minimum track length
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None

    local_del_list  = [];                       %stores a list of tracks that fall within this range
    track_list      = unique(tracks_file(:,4));
    
    %loop over all track_IDs
    for jj = 1:size(track_list, 1)
        if size(tracks_file(tracks_file(:,4) == track_list(jj,1)), 1) < min_track_len
            local_del_list = cat(1, local_del_list, track_list(jj));
        end
    end
end


function [new_tracks] = applyMemoryParameter(tracks, mem_param)
%Apply memory parameter to the tracks in a single cell, Oliver Pambos,
%22/02/22.
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
%tracks     (mat)   tracks data from app.movie_data.cellROI_data(ii).tracks for a given track 'ii'
%mem_param  (int)   memory parameter in number of frames (# frames that can be missed within a given track)
%
%Output
%------
%new_tracks (mat)   tracks data for a cell, which no longer contains tracks
%                   with lengths shorter than the memory parameter; tracks
%                   which have been split have successive parts renumbered
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    track_list  = unique(tracks(:,4));
    new_ID      = max(track_list) + 1;
    new_tracks  = [];   %can be pre-allocated as dimensions are identical to tracks, but for simplicity....
    
    %loop over tracks
    for ii = 1:size(track_list,1)
        curr_track = tracks(tracks(:,4) == track_list(ii,1), :);
        
        %loop over all locs in track, assign new ID if memory parameter is exceeded
        for jj = 2:size(curr_track, 1)
            if curr_track(jj,3) - curr_track(jj-1,3) > mem_param + 1      %+1 as mem_param determines the missing frames, not the gap between frames
                curr_track(jj:end,4) = new_ID;
                new_ID = new_ID + 1;
            end
        end
        new_tracks = cat(1, new_tracks, curr_track);    %should be via replacement of preallocated array, not concatenation
    end
end


function [movie_data] = removeEmptyCells(movie_data)
%Remove the cells that contain no tracks, Oliver Pambos, 21/03/2023.
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
%This function is currently deprecated. It was previously called at the
%start of filterTracks().
%
%Inputs
%------
%movie_data (struct)    main struct derived from LoColi
%
%Output
%------
%movie_data (struct)    main struct derived from LoColi, with empty cells removed
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None

    for ii = size(movie_data.cellROI_data,1) : -1 : 1  %in reverse order so I don't have to store a list of empty cells
        if isempty(movie_data.cellROI_data(ii).tracks)
            movie_data.cellROI_data(ii) = [];
        end
    end
end


function [movie_data] = filterByAllLocs(movie_data, tolerance)
%Filters tracks if there are any other localisations in the cell at the
%same time (very strict), Oliver Pambos, 06/07/2023.
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
%Input
%-----
%movie_data (struct)    main struct derived from LoColi
%tolerance  (int)       maximum number of localisations that can conflict with trajectory before it is filtered
%
%Output
%------
%movie_data (struct)    main struct derived from LoColi, with all cells conflicting with at least 'tolerance' localisations removed
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    f = waitbar(0,'Processing tracks, please wait....','Name','Filtering tracks');
    %loop over cells
    for ii = 1:size(movie_data.cellROI_data,1)
        if ~isempty(movie_data.cellROI_data(ii).tracks)
            %get list of molecule IDs in current cell
            mol_list = unique(movie_data.cellROI_data(ii).tracks(:,4));
            
            %keep a list of trajectories to filter
            filter_list = [];
            
            %loop over trajectories
            for jj = 1:size(mol_list,1)
                %obtain first and last frame in the trajectory
                track_lo = min(movie_data.cellROI_data(ii).tracks(movie_data.cellROI_data(ii).tracks(:,4) == mol_list(jj,1), 3));
                track_hi = max(movie_data.cellROI_data(ii).tracks(movie_data.cellROI_data(ii).tracks(:,4) == mol_list(jj,1), 3));
                
                %obtain reduced localisation list corresponding to the time period of the trajectory; also only taking (frame, x, y)
                loc_subset = movie_data.cellROI_data(ii).localizationData((movie_data.cellROI_data(ii).localizationData(:,1) >= track_lo) &...
                    (movie_data.cellROI_data(ii).localizationData(:,1) <= track_hi), 1:3);
                %reorder to be consistent with trajectory columns (x, y, frame)
                loc_subset = loc_subset(:,[2 3 1]);
                
                %obtain trajectory
                curr_track = (movie_data.cellROI_data(ii).tracks(movie_data.cellROI_data(ii).tracks(:,4) == mol_list(jj), 1:3));
    
                %check if there are any localisations in the cell in this time range that do not correspond to the trajectory
                match = ismember(loc_subset, curr_track, 'rows');
                unmatched_locs = loc_subset(~match, :);
                
                % decide whether to add trajectory to filter list
                if size(unmatched_locs, 1) > tolerance
                    filter_list = [filter_list jj];
                end
            end
            
            %add the short tracks to the filter list - I'm not sure this is ever used
            short_tracks = identifyShortTracks(movie_data.cellROI_data(ii).tracks, movie_data.params.min_track_len);
            filter_list = [filter_list short_tracks'];
            filter_list = unique(filter_list);
            
            %filter trajectories from current cell
            if ~isempty(filter_list)
                for jj = 1:size(filter_list, 2)
                    movie_data.cellROI_data(ii).tracks(movie_data.cellROI_data(ii).tracks(:,4) == filter_list(jj), :) = [];
                end
            end
        end
        waitbar(ii/size(movie_data.cellROI_data,1), f, strcat('Processing cell #', num2str(ii), {' '}, 'of', {' '}, num2str(size(movie_data.cellROI_data,1))));
    end
    close(f);
end