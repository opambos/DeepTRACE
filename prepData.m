function [] = prepData(app)
%Load and modify the LoColi data struct, Oliver Pambos, 16/11/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: prepData
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
%This function performs a number of actions,
%   1. loads the LoColi data
%   2. sets up a new parameter sub-struct
%   3. launches all of the automatic pre-processing functions that can run
%       including,
%           identifies, orders, and indexes the video files
%           generates overlays and ROIs for all cells
%           filtering of valid trajectories
%           launches the feature engineering process
%           generates the reference column titles
%           initialises all class labels to -1 in preparation for labelling
%           extracts all available information from meta data (e.g. frame rate)
%
%Note that a future version will handle cases where FITS meta data is not
%available.
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
%getFITSMeta()
%genAllOverlays()
%computeLocMemDists()
%convertLoColiToKinetics()
%computeStepAngles()
%computeStepAnglesRelToCell()
%getFileExtension()             - local to this .m file
%promptUserForMissingParams()   - local to this .m file
    
    %obtain fluorescence videos and ask user to confirm chronological order
    app.textout.Value = "Please provide fluorescence video files.";
    [file, path, filterIndex] = uigetfile({'*.fits;*.FITS;*.tif;*.TIF;*.tiff;*.TIFF', 'Fluorescence video files (*.fits, *.FITS, *.tif, *.TIF, *.tiff, *.TIFF)'}, 'Select raw video files:', 'MultiSelect', 'on');
    if filterIndex == 0
        disp('User did not select a file.');
        return;
    end
    
    app.textout.Value = "please re-order the fluorescence video files into chronological order.";
    
    %confirm chronological order of videos
    if iscell(file)
        app.movie_data.params.ffFile = confirmVideoOrder(file);
    else
        app.movie_data.params.ffFile = file;
    end
    app.movie_data.params.ffPath = path;    %intentionally not assigning this to app handles at call to uigetfile in case user presses cancel
    
    %check the file extensions are consistent; if so get the extension
    [file_ext, consistent] = getFileExtension(app.movie_data.params.ffFile);
    
    %return if filenames are inconsistent
    if ~consistent
        errordlg('File extension of selected fluorescence videos are inconsistent. Exiting data preparation. Please try again.', 'Inconsistent file extensions');
        app.textout.Value = "File extensions of the selected fluorescence video files are inconsistent; data has not been prepared for analysis.";
        return;
    end
    
    %handle the other tiff extension
    if lower(file_ext) == ".tiff"
        file_ext = ".tif";
    end
    
    N_videos = size(app.movie_data.params.ffFile, 2);
    
    %load video files
    switch lower(file_ext)
        case ".fits"
            %obtain frame rate from KCT value in FITS file header
            if iscell(app.movie_data.params.ffFile)
                app.movie_data.params.frame_rate = 1/str2num(getFITSMeta(string(app.movie_data.params.ffFile(1)), app.movie_data.params.ffPath, 'KCT'));
            else
                app.movie_data.params.frame_rate = 1/str2num(getFITSMeta(string(app.movie_data.params.ffFile), app.movie_data.params.ffPath, 'KCT'));
            end
            
            %build frame offset index for all FITS files
            app.movie_data.params.frame_offsets(1) = 0;
            if iscell(app.movie_data.params.ffFile)
                h_offset_waitbar = waitbar(0, "Computing temporal offsets for video files....");
                set(h_offset_waitbar, 'WindowStyle', 'modal');
                frames_per_file = zeros(1, N_videos);
                for ii = 1:N_videos
                    waitbar(ii/N_videos, h_offset_waitbar, sprintf('Computing temporal offsets for video file C %d/%d', ii, N_videos));
                    frames_per_file(ii) = str2double(getFITSMeta(string(app.movie_data.params.ffFile(ii)), app.movie_data.params.ffPath, 'NAXIS3'));
                end
                app.movie_data.params.frames_per_file = frames_per_file;
                app.movie_data.params.frame_offsets = [0, cumsum(frames_per_file(1:end-1))];
                
                close(h_offset_waitbar)
            end
            
        case ".tif"
            % << future handling of TIF metadata using imfinfo() >>
            
            %build frame offset index for all TIF files
            app.movie_data.params.frame_offsets(1) = 0;
            app.movie_data.params.frames_per_file = zeros(N_videos, 1);
            
            %if there are multiple files
            if iscell(app.movie_data.params.ffFile)
                h_offset_waitbar = waitbar(0, "Computing temporal offsets for video files....");
                set(h_offset_waitbar, 'WindowStyle', 'modal');
                for ii = 1:N_videos
                    waitbar(ii/N_videos, h_offset_waitbar, sprintf('Computing temporal offsets for video file %d/%d', ii, N_videos));
                    info = imfinfo(fullfile(app.movie_data.params.ffPath, app.movie_data.params.ffFile{ii}));
                    app.movie_data.params.frames_per_file(ii) = size(info,1); %number of frames in the current TIF file
                    
                    %for the first file, the offset is already set to 0
                    if ii > 1
                        %update frame offsets for subsequent files
                        app.movie_data.params.frame_offsets(ii) = app.movie_data.params.frame_offsets(ii-1) + app.movie_data.params.frames_per_file(ii-1);
                    end
                end
                close(h_offset_waitbar);
            else
                info = imfinfo(fullfile(app.movie_data.params.ffPath, app.movie_data.params.ffFile));
                app.movie_data.params.frames_per_file = numel(info);
            end
            
        otherwise
            app.textout.Value = "File type of fluorescence video is unknown; data has not been prepared for analysis.";
            return;
    end
    
    %prompt for any missing parameters
    app.movie_data.params = promptUserForMissingParams(app.movie_data.params);
    
    %filter tracks
    filter_status = filterTracks(app);
    
    %notify user of filtering outcome; only proceed if successful
    if strcmp(filter_status, "Cancelled by user")
        app.textout.Value = "Track filtering was canceled by user, due to lack of localization data.";
        return;
    elseif strcmp(filter_status, "Filtered by localisations")
        app.textout.Value = "Tracks were filtered against all localisations associated with their parent cell.";
    elseif strcmp(filter_status, "Successfully truncated by tracks")
        app.textout.Value = "Tracks were filtered by truncation against all tracks associated with their parent cell.";
    elseif strcmp(filter_status, "Successfully eliminated by tracks")
        app.textout.Value = "Tracks were filtered by elimination against all tracks associated with their parent cell.";
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
    
    %generate all inverted brightfield overlays
    waitbar(2/2, file_ext, 'Generating overlays');
    app.movie_data = genAllOverlays(app.movie_data, app.movie_data.params.ill_border, 8);
    close(file_ext);
    
    if strcmp(app.movie_data.params.pipeline, "LoColi")
        %add all StormTracker data to the tracks matrix
        app.movie_data = convertLoColiToKinetics(app.movie_data);
    end
    
    %perform feature engineering, and add class label column
    engineerFeatures(app);
    
    %flag to record data preparation complete
    app.movie_data.params.data_prepared = true;
    
    app.textout.Value = "Data preparation is complete." + newline + ...
        "Please proceed to either the [Human annotation] tab to manual annotate data, " + ...
        "or the [ML classification] tab to annotate data using an appropriate pre-trained model, " + ...
        "or the [Load/Save] tab to import ground truth data.";
    
    focus(app.InVivoKineticsUIFigure);
end


function [file_ext, consistent] = getFileExtension(ffFile)
%Extracts video file extension, and identifies inconsistency when multiple
%are present, Oliver Pambos 28/02/2024
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getFileExtension
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
%
%Inputs
%------
%file_ext   (str)   file extension including `.` char
%consistent (bool)  true if all file extensions are identical; else false
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    consistent  = true;
    
    %if multiple files are present
    if iscell(ffFile)
        [~, ~, file_ext] = fileparts(ffFile{1});
        
        %check remaining filenames for consistency
        for ii = 2:numel(ffFile)
            [~, ~, current_ext] = fileparts(ffFile{ii});
            if ~strcmpi(file_ext, current_ext)
                consistent = false;
                break;
            end
        end
    else
        [~, ~, file_ext] = fileparts(ffFile);
    end
end


function params = promptUserForMissingParams(params)
%Prompts the user to manually enter all necessary parameters that could not
%be read from metadata or tracking file, Oliver Pambos, 28/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: promptUserForMissingParams
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
%This implementation is tailored for numeric data input. Parameters holding
%string literals are accommodated by first testing conversion on a dummy
%copy using MATLAB's str2double() function. The result of this conversion
%determines whether to perform conversion. This approach eliminates the
%need for a lookup table of possible parameters
%string inputs in future, input parsing will be necessary to
%identifyoverovo
%non-numeric characters in the input. This allows for flexible handling of
%various input types without relying on hardcoded values or a lookup table
%of formats for all possible parameters. This eliminates hardcoding, more
%elegantly handles user input of unknown parameters, and ensures ease of
%modification and inclusion of new parameters without hardcoded rules.
%However it does rely on the user entering numeric or string values when
%prompted.
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
    
    missing_fields = {};
    missing_descriptions = {};
    missing_defaults = {};
    
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
        dlgtitle = "Input Required Parameters";
        dims = [1 35];
        answers = inputdlg(missing_descriptions, dlgtitle, dims, missing_defaults);
        
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


