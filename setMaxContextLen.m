function [] = setMaxContextLen(app)
%Computes, and pre-fills the input for context length using the maximum
%value for the chosen track sampling method, Oliver Pambos, 10/01/2025.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: setMaxSlidingWin
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD, UK
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%LEGAL DISCLAIMER
%THIS CODE IS INTENDED FOR USE ONLY BY INDIVIDUALS WHO HAVE RECEIVED
%EXPLICIT AUTHORIZATION FROM THE AUTHOR, OLIVER JAMES PAMBOS. ANY FORM OF
%COPYING, REDISTRIBUTION, OR UNAUTHORIZED USE OF THIS CODE, IN WHOLE OR IN
%PART, IS PROHIBITED. BY USING THIS CODE, USERS SIGNIFY THAT THEY HAVE
%READ, UNDERSTOOD, AND AGREED TO BE BOUND BY THE TERMS OF SERVICE PRESENTED
%UPON SOFTWARE LAUNCH, INCLUDING THE REQUIREMENT FOR CO-AUTHORSHIP ON ANY
%RELATED PUBLICATIONS. THIS APPLIES TO ALL LEVELS OF USE, INCLUDING PARTIAL
%USE OR MODIFICATION OF THE CODE OR ANY OF ITS EXTERNAL FUNCTIONS.
%
%USERS ARE RESPONSIBLE FOR ENSURING FULL UNDERSTANDING AND COMPLIANCE WITH
%THESE TERMS, INCLUDING OBTAINING AGREEMENT FROM THE APPROPRIATE
%PUBLICATION DECISION-MAKERS WITHIN THEIR ORGANIZATION OR INSTITUTION.
%
%NOTE: UPON PUBLIC RELEASE OF THIS SOFTWARE, THESE TERMS MAY BE SUBJECT TO
%CHANGE. HOWEVER, USERS OF THIS PRE-RELEASE VERSION ARE STILL BOUND BY THE
%CO-AUTHORSHIP AGREEMENT FOR ANY USE MADE PRIOR TO THE PUBLIC RELEASE. THE
%RELEASED VERSION WILL BE AVAILABLE FROM A DESIGNATED ONLINE REPOSITORY
%WITH POTENTIALLY DIFFERENT USAGE CONDITIONS.
%
%
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
            uiwait(popup.UIFigure);
            
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