function [] = setMaxContextLen(app)
%Computes, and pre-fills the input for context length using the maximum
%value for the chosen track sampling method, 10/01/2025.
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
%Computes the maximum available context length for the track sampling
%method selected by the user, and then pre-fills the associated GUI input.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %check for human GUI error
    if isempty(app.SourcedataDropDown.Value) || ~any(strcmp(app.SourcedataDropDown.Value, ...
            {'Human annotations', 'Ground truth', 'Human annotations (multiple experiments)', 'Ground truth (multiple simulations)'}))
        warndlg("Please select a valid data source before setting the window size.", "Invalid data source");
        app.textout.Value = "Error: No valid source selected. Please choose a valid data source from the [Source data] dropdown menu.";
        return;
    end
    if strcmp(app.TracksamplingDropDown.Value, "Whole tracks")
        app.textout.Value = "This parameter is irrelevant when subsampling method is set to `Whole tracks`";
        warndlg("This parameter is irrelevant when subsampling method is set to `Whole tracks`", "Parameter irrelevant!");
        return;
    end
    
    %obtain truncation values
    ignore_start = app.IgnorerowsfromstartSpinner.Value;
    ignore_end   = app.IgnorerowsfromendSpinner.Value;
    
    %obtain data
    dataset = {};
    switch app.SourcedataDropDown.Value
        case 'Human annotations'
            dataset = app.movie_data.results.VisuallyLabelled.LabelledMols;
            
        case 'Ground truth'
            dataset = app.movie_data.results.GroundTruth.LabelledMols;
            
        case {'Human annotations (multiple experiments)', 'Ground truth (multiple simulations)'}
            %user chooses files
            popup = SelectTrainingFilesPopUp(app);
            uiwait(popup.SelectTrainingDataUIFigure);
            
            if ~isfield(app.movie_data.params, "train_data_source") || isempty(app.movie_data.params.train_data_source) || ...
                    ~size(app.movie_data.params.train_data_source, 1) > 0
                warndlg("User did not provide valid source files containing annotated tracks; if you wish to train only on currently loaded annotation please select this from the training data source dropdown.", "Suitable files were not provided.");
                app.textout.Value = "Error: No files selected for window size estimation.";
                return;
            end

            %transfer current data if requested
            include_currently_loaded = strcmp(app.movie_data.params.train_data_source{1, 1}, '[Currently loaded annotations]');
            start_idx = 1;
            if include_currently_loaded
                if strcmp(app.SourcedataDropDown.Value, 'Human annotations (multiple experiments)')
                    dataset = app.movie_data.results.VisuallyLabelled.LabelledMols;
                else
                    dataset = app.movie_data.results.GroundTruth.LabelledMols;
                end
                %start loading external files
                start_idx = 2;
            end
            
            %load data from external files
            for jj = start_idx:size(app.movie_data.params.train_data_source, 1)
                curr_pathname = app.movie_data.params.train_data_source{jj};
                
                data = load(curr_pathname);
                
                %handle both human annotations and ground truth
                if strcmp(app.SourcedataDropDown.Value, 'Human annotations (multiple experiments)')
                    source_data = data.movie_data.results.VisuallyLabelled.LabelledMols;
                else
                    source_data = data.movie_data.results.GroundTruth.LabelledMols;
                end
                
                if isempty(source_data)
                    warning('No valid track data found in file: %s', curr_pathname);
                    continue;
                end
                
                %append external data
                dataset = [dataset; source_data];
            end
            
        otherwise
            warndlg("Unknown data source selected.", "Invalid Source");
            return;
    end
    
    %check data exists
    if isempty(dataset)
        warndlg("No valid tracks found in the selected dataset.", "No Tracks Available");
        app.textout.Value = "Error: No tracks available in the selected dataset.";
        return;
    end

    %init shortest track
    min_track_len = inf;
    
    %find shortest track length after truncation
    for ii = 1:numel(dataset)
        %extract track - more computationally efficient than accessing twice from cell array
        Mol = dataset{ii}.Mol;
        
        if isempty(Mol)
            continue;
        end
        
        %if truncated len is new record, record it
        truncated_len = max(0, size(Mol, 1) - (ignore_start + ignore_end));
        if truncated_len > 0
            min_track_len = min(min_track_len, truncated_len);
        end
    end
    
    if min_track_len == inf
        warndlg("No valid tracks found after truncation. Check your data source and truncation settings.", "No Valid Tracks");
        app.textout.Value = "Error: No valid tracks found after applying truncation settings.";
        return;
    end
    
    %calc max allowed window size based on subsampline method
    switch app.TracksamplingDropDown.Value
        case "Random subsampling (recommended)"
            max_window_size = max(1, min_track_len - 9);
        case "Non-overapping segments"
            max_window_size = min_track_len;
        otherwise
    end
    
    %update GUI
    app.ContextLengthSpinner.Value = max_window_size;
    app.textout.Value = sprintf("Set window size to %d (shortest track: %d frames, minus 9)", max_window_size, min_track_len);
end