function [] = reformatToSpans(app)
%Reformats training, validation, and test datasets using the requested
%track sampling method prior to training, Oliver Pambos, 01/02/2024.
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
%This funciton (through its call to the custom local function
%subsampleDataset()) subsamples tracks into a smaller tracks either as
%non-overlapping segments, or randomly-selected subtracks (recommended)
%with positions drawn without replacement from a uniform random number
%generator. This random subsampling is performed in such a way as to ensure
%that the maximum number of subsamples is obtained for a given context
%length, as determined by the number of subtracks that could be obtained by
%a sliding window algorithm using the requested context length moving along
%the shortest track in either the training, validation, or test data. The
%approach provides temporal overlap of subsamples causing events to be
%reframed in different temporal contexts, effectively temporally augmenting
%the input data to enhance the value of small datasets. It ensures an equal
%number of subtracks is obtained for each original track irrespective of
%its length, greatly reducing bias associated with track length in datasets
%with very high variability in track lengths.
%
%Note that the window size (described to the user as "context length") is
%set in the GUI using another tool that ensures that the data is
%pre-scanned to obtain the maximum possible window size, that is
%intentionally hardcoded here to be a maximum of 9 frames shorter than the
%shortest track. This ensures that there are a minimum of 10 contributions
%of each track, and an equal number of contributions from each track
%regardless of track length. There is additionally error checking included
%here to ensure that this is correctly enforced even if the user tries to
%force an inappropriate value.
%
%Note that this function also adds a bool to the results substruct called
%`padding`, which keeps track of whether the data has been padded with
%zeros and contains the masking feature (as the final row). When the models
%are trained on spans of trajectories (segments or random subsampling) the
%padding and masking is no longer necessary, and so it is important to keep
%track of the non-existance of both the padding and the masking feature,
%which will not be present in the model's training. This variable is
%deliberately keps in the results substruct to be local to the training
%data.
%
%Note that the omission of ignored rows at start and end of tracks when
%computing context length is intentional in this function, as these have
%already been cropped by scaleLabelledFeatures()'s call to
%cropTracjectories().
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
%subsampleDataset()     - local to this .m file

    context_len = app.ContextLengthSpinner.Value;
    
    %separate whole tracks case to avoid unnecessary calculations
    if strcmp(app.TracksamplingDropDown.Value, "Whole tracks")
        return;
    end
    
    %find shortest track in train, val, or test data
    min_track_len = min(cellfun(@(x) min([find(x(end, :) == 0, 1, 'first') - 1, size(x, 2)]), app.movie_data.results.train_data));  %find returns empty mat if no padding, and min then returns full len of track if alternative is empty mat
    if isfield(app.movie_data.results, 'val_data')
        min_track_len = min(min_track_len, min(cellfun(@(x) min([find(x(end, :) == 0, 1, 'first') - 1, size(x, 2)]), app.movie_data.results.val_data)));
    end
    if isfield(app.movie_data.results, 'test_data')
        min_track_len = min(min_track_len, min(cellfun(@(x) min([find(x(end, :) == 0, 1, 'first') - 1, size(x, 2)]), app.movie_data.results.test_data)));
    end
    
    overlap = true;
    switch app.TracksamplingDropDown.Value
        case "Random subsampling (recommended)"
            overlap = true;
            
            %check context_len is valid
            if context_len > (min_track_len - 9)
                app.ContextLengthSpinner.Value = (min_track_len - 9);
                app.textout.Value = "You have requested a context length of " + context_len + " frames, which is too long for the loaded data, the longest length possible is " + (min_track_len - 9) + " (9 frames shorter than the shortest track in the dataset); the associated entry field has been updated with this value. Please select [Generate training data] again when you are ready.";
                warndlg("Requested context length of " + context_len + " frames is too long, the longest length possible is " + (min_track_len - 9) + "; the associated entry field has been updated with this value. Please select [Generate training data] again when you are ready.", "Invalid context length");
                return;
            end
            
        case "Non-overapping segments"
            overlap = false;
            
            %check context_len is valid
            if context_len > min_track_len
                app.ContextLengthSpinner.Value = min_track_len;
                app.textout.Value = "You have requested a context length of " + context_len + " frames, which is too long for the loaded data, the longest length possible is " + min_track_len + " (the shortest track in the dataset); the associated entry field has been updated with this value. Please select [Generate training data] again when you are ready.";
                warndlg("Requested context length of " + context_len + " frames is too long, the longest length possible is " + min_track_len + "; the associated entry field has been updated with this value. Please select [Generate training data] again when you are ready.", "Invalid context length");
                return;
            end
            
        otherwise
            app.textout.Value = "Unknown subsampling method in reformatToSpans()";
            return;
    end
    
    %reformat training data
    original_data   = app.movie_data.results.train_data;
    original_labels = app.movie_data.results.train_labels;
    
    %compute number of windows to randomly subsample from each track
    N_windows = min_track_len - context_len + 1;
    
    [windowed_data, windowed_labels] = subsampleDataset(original_data, original_labels, context_len, overlap, N_windows);
    
    app.movie_data.results.train_data   = windowed_data;
    app.movie_data.results.train_labels = windowed_labels;
    
    %reformat validation data
    if isfield(app.movie_data.results, "val_data") && isfield(app.movie_data.results, "val_labels")
        original_data   = app.movie_data.results.val_data;
        original_labels = app.movie_data.results.val_labels;
        
        [windowed_data, windowed_labels] = subsampleDataset(original_data, original_labels, context_len, overlap, N_windows);
        
        app.movie_data.results.val_data     = windowed_data;
        app.movie_data.results.val_labels   = windowed_labels;
    end
    
    %reformat test data
    if isfield(app.movie_data.results, "test_data") && isfield(app.movie_data.results, "test_labels")
        original_data   = app.movie_data.results.test_data;
        original_labels = app.movie_data.results.test_labels;
        
        [windowed_data, windowed_labels] = subsampleDataset(original_data, original_labels, context_len, overlap, N_windows);
        
        app.movie_data.results.test_data    = windowed_data;
        app.movie_data.results.test_labels  = windowed_labels;
    end
    
end


function [windowed_data, windowed_labels] = subsampleDataset(original_data, original_labels, context_len, overlap, N_windows)
%Reformat an individual dataset, Oliver Pambos, 01/02/2024.
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
%This function performs subsampling of the dataset, subsampling each track
%into a fixed number of smaller tracks, which can overlap with random
%positions along the track (recommended), or be broken into consecutive
%chunks (not recommended).
%
%This function, where necessary removes the padding zeros, and then removes
%the padding feature in each trajectory.
%
%Random start points for subsampling now replaces the sliding window
%approach to generating training, validation, and test data spans. This
%greatly reduces track length bias from a dataset containing a wide range
%of track lengths, as is the case with real data. It also provides here a
%further opportunity to direclty compute the resulting dataset size as
%there is a fixed number of subsampled tracks regardless of track length,
%enabling substantial improvement in time taken to generate the training
%dataset as the associated cell arrays are now efficiently preallocated at
%the start of this function. Similar pre-allocation can be done for
%non-overlapping segments when time allows.
%
%Inputs
%------
%original_data      (cell)  original data; each entry in the cell array
%                               contains a single full trajectory, in the
%                               form of an NxM numeric matrix, where N is
%                               the number of features (final feature being
%                               the padding mask), and M is the trajectory
%                               length (including padding zeros)
%original_labels    (cell)  original labels; a cell array of the same
%                               dimensions as original data, where each
%                               cell contains a 1xM numeric row vector
%                               which holds the labels for each frame in
%                               the trajectory (including padding zeros)
%context_len        (int)   size of window/span (in frames)
%overlap            (bool)  determines if the trajectory is broken up into
%                               non-overlapping chunks, or whether to use
%                               the sliding window, moving with single
%                               frame increments
%
%Output
%------
%windowed_data      (cell)  the original data now reformatted into smaller
%                               windows (either discrete or overlapping)
%windowed_labels    (cell)  the labels corresponding to windowed_data
%                               reformatted into smaller windows
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %init new cell arrays for windowed data and labels
    if overlap
        %for random subsampling, preallocate
        total_windows   = size(original_data, 1) * N_windows;
        windowed_data   = cell(total_windows, 1);
        windowed_labels = cell(total_windows, 1);
        window_idx = 1;
    else
        %for non-overlapping segments, fall back on concatenation
        windowed_data   = {};
        windowed_labels = {};
    end
    
    %loop over tracks
    for ii = 1:size(original_data, 1)
        %copy the track, remove padding columns, then remove masking feature
        track = original_data{ii};
        track(:, track(end, :) == 0) = [];
        track(end, :) = [];
        
        %handle rare edge-case where there is only one track
        if numel(original_data) > 1 
            labels = original_labels{ii};
        else 
            %covers incredibly irritating edge case in which a dataset (train/val/test) contains only single track example;
            %only runs once, but overall solution still sub-optimal
            labels = horzcat(original_labels{:});
        end
        
        labels = removecats(labels, '0');   %critical; removes the now non-existent '0' class which would otherwise confuse use of the ML model
        
        %generate all possible start indices
        N_available_windows = size(track, 2) - context_len + 1;
        
        %get the start points of every window depending on the mode
        if overlap
            %randomly select start indices without replacement
            selected_starts = randperm(N_available_windows, min(N_windows, N_available_windows));
        else
            %generate non-overlapping segments (step size = context_len)
            selected_starts = 1:context_len:(size(track, 2) - context_len + 1);
        end
        
        %insert subsampled data into cell array
        if overlap
            %extract windows based on random start indices
            for jj = 1:length(selected_starts)
                start_idx = selected_starts(jj);
                windowed_data{window_idx, 1}   = track(:, start_idx:start_idx + context_len - 1);
                windowed_labels{window_idx, 1} = labels(start_idx:start_idx + context_len - 1);
                window_idx = window_idx + 1;
            end
        else
            %concatenate non-overlapping segments
            for jj = 1:length(selected_starts)
                start_idx = selected_starts(jj);
                windowed_data   = [windowed_data; {track(:, start_idx:start_idx + context_len - 1)}];
                windowed_labels = [windowed_labels; {labels(start_idx:start_idx + context_len - 1)}];
            end
        end
    end
end