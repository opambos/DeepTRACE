function [] = prepData(app)
%Prepare DeepTRACE data struct from loaded data, 16/11/2020.
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
%This function performs a number of data preparation tasks through calls to
%other functions within the DeepTRACE codebase,
%   Identifies, orders, and indexes video files
%   Computes frame offsets in multi-video experiments
%   Sets up the parameter substruct
%   Extracts information from metadata
%   Obtains frame rates from user if it cannot be extracted from meta data
%   Loads and formats LoColi data, if this is input pipeline
%   Generates overlays and ROIs for all cells
%   Track filtering of valid trajectories based on user requirements
%   Launches the feature engineering process
%   Generates the reference column titles
%   Initialises all class labels to -1 in preparation for labelling
%   Prompts user for any missing data not obtained automatically
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
%confirmVideoOrder()
%genAllOverlays()
%convertLoColiToKinetics()
%engineerFeatures()
%filterTracks()
%promptUserForMissingParams()   - local to this .m file
    
    %obtain video files, frame rate, and frame offsets if not already present
    if ~isfield(app.movie_data.params, "ffFile") || isempty(app.movie_data.params.ffFile)
        %obtain fluorescence videos and ask user to confirm chronological order
        app.textout.Value = "Please provide fluorescence video files.";
        [file, path, filterIndex] = uigetfile({'*.fits;*.FITS;*.tif;*.TIF;*.tiff;*.TIFF', 'Fluorescence video files (*.fits, *.FITS, *.tif, *.TIF, *.tiff, *.TIFF)'}, 'Select raw video files:', 'MultiSelect', 'on');
        if filterIndex == 0
            disp('User did not select a file.');
            return;
        end
        
        app.textout.Value = "Please re-order the fluorescence video files into chronological order.";
        
        %confirm chronological order of videos
        if iscell(file)
            app.movie_data.params.ffFile = confirmVideoOrder(file);
        else
            app.movie_data.params.ffFile = file;
        end
        app.movie_data.params.ffPath = path;    %intentionally not assigning this to app handles at call to uigetfile in case user presses cancel
        
        %compute frame offsets for fluorescence videos
        [frame_rate, frames_per_file, frame_offsets, success] = computeFrameOffsets(app.movie_data.params.ffPath, app.movie_data.params.ffFile);
        
        %if frame rate was not obtained from metadata, prompt user directly
        if isempty(frame_rate) || isnan(frame_rate)
            frame_rate = str2double(inputdlg('Enter frame rate in Hz:', 'Frame rate (Hz)', [1 50]));
        end
        if isnan(frame_rate)
            errordlg("Frame rate was not obtained from metadata or user. Please try again.", "Error: unknown frame rate");
            app.textout.Value = "Frame rate was not obtained from metadata or user. Please try again.";
            return;
        end
        
        %check it worked
        if ~success
            errordlg('Frame offsets could not be obtained for the provided video files. Exiting data preparation. Please try again.', 'Video loading error');
            app.textout.Value = "Frame offsets could not be obtained for the provided video files. Data has not been prepared for analysis. Please try again.";
            return;
        end
        
        %store outputs in params (required by downstream code)
        app.movie_data.params.frame_rate      = frame_rate;
        app.movie_data.params.frames_per_file = frames_per_file;
        app.movie_data.params.frame_offsets   = frame_offsets;
    end
    
    %prompt for any missing parameters
    app.movie_data.params = promptUserForMissingParams(app.movie_data.params);
    
    %filter tracks
    filter_status = filterTracks(app);
    
    %notify user of filtering outcome; only proceed if successful
    if strcmp(filter_status, "Cancelled by user")
        app.textout.Value = "Track filtering was canceled by user, due to lack of localisation data.";
        return;
    elseif strcmp(filter_status, "Filtered by localisations")
        app.textout.Value = "Tracks were filtered against all localisations associated with their parent cell.";
    elseif strcmp(filter_status, "Successfully truncated by tracks")
        app.textout.Value = "Tracks were filtered by truncation against all tracks associated with their parent cell.";
    elseif strcmp(filter_status, "Successfully eliminated by tracks")
        app.textout.Value = "Tracks were filtered by elimination against all tracks associated with their parent cell.";
    elseif strcmp(filter_status, "Completed track elimination by length only.")
        app.textout.Value = "Tracks filtering was skipped at the request of the user.";
    else
        app.textout.Value = "Track filtering failed due to an known error. Please try again.";
        warning("Track filtering failed due to an known error. Please try again");
        errordlg("Track filtering failed due to an known error. Please try again", "Track filtering failed");
        return;
    end
    
    %register all filtered track IDs
    file_ext = waitbar(0,'Registering tracks','Name','Preparing data: registering filtered tracks');
    waitbar(1/2, file_ext, 'Registering filtered tracks');
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
            app.movie_data.cellROI_data(ii).filtered_track_IDs = unique(app.movie_data.cellROI_data(ii).tracks(:,4));
        end
    end
    
    %generate all reference image (typically inverted brightfield) overlays
    waitbar(2/2, file_ext, 'Generating overlays');
    app.movie_data = genAllOverlays(app.movie_data, app.movie_data.params.ill_border, 8);
    close(file_ext);
    
    if strcmp(app.movie_data.params.pipeline, "LoColi")
        %add all LoColi-embedded StormTracker data to the tracks matrix
        app.movie_data = convertLoColiToKinetics(app.movie_data);
    end
    
    %perform feature engineering, and add class label column
    engineerFeatures(app);
    
    %flag recording data preparation complete
    app.movie_data.params.data_prepared = true;
    
    app.textout.Value = "Data preparation is complete." + newline + ...
        "Please proceed to either the [Human annotation] tab to manual annotate data, " + ...
        "or the [ML classification] tab to annotate data using an appropriate pre-trained model, " + ...
        "or [File] > [Load ground truth] to import ground truth data.";
    
    focus(app.DeepTRACEUIFigure);
end


function [params] = promptUserForMissingParams(params)
%Prompts the user to manually enter all necessary parameters that could not
%be read from metadata or tracking file, 28/02/2024.
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
%This function handles parameters that cannot be reliably read from
%metadata or tracking output, by prompting the user for manual input. It is
%designed to work with a small number of simple parameters whose types may
%not be known in advance.
%
%The function assumes that user provides either numeric or intended string
%values when prompted, and does not attempt input validation or format
%checking beyond basic conversion. This keeps the interface flexible, and
%avoids hardcoding parameter-specific rules.
%
%Inputs
%------
%params (struct)    app.movie_data.params substruct that holds existing
%                       parameters read from meta data and analysis files
%
%Output
%------
%params (struct)    app.movie_data.params substruct, now including
%                       manually-entered parameters
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %list of required fields and corresponding user-friendly descriptions
    required_fields     = {'frame_rate', 'px_scale'};
    field_descriptions  = {'Frame rate (Hz)', 'Pixel scale (nm / pixel)', 'Class names, separated by `;`'};
    default_vals        = {'5', '0.096'};
    
    missing_fields          = {};
    missing_descriptions    = {};
    missing_defaults        = {};
    
    %check each parameter to determine what's missing
    for ii = 1:length(required_fields)
        if ~isfield(params, required_fields{ii})
            missing_fields{end+1}       = required_fields{ii};
            missing_descriptions{end+1} = sprintf("Enter value for %s:", field_descriptions{ii});
            missing_defaults{end+1}     = default_vals{ii};
        end
    end
    
    %prompt for all/any missing parameters
    if ~isempty(missing_fields)
        answers = inputdlg(missing_descriptions, "Input Required Parameters", [1 35], missing_defaults);
        
        %save new params to struct
        for ii = 1:length(missing_fields)
            if ~isempty(answers) && ~isempty(answers{ii})
                %use MATLAB's string conversion to test whether it converts to a double correctly,
                %if unsuccessful the input must be non-numeric, so write it as a string
                dummy = str2double(answers{ii});
                if isnan(dummy)
                    params.(missing_fields{ii}) = answers{ii};
                else
                    params.(missing_fields{ii}) = str2double(answers{ii});
                end
            else
                %handle user closing window
                error('Input for all fields is required. Operation cancelled.');
            end
        end
    end
end