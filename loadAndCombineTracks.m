function [track_data_combined] = loadAndCombineTracks(app, data_source)
%Load and combine tracks from multiple external files, Oliver Pambos,
%14/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: loadAndCombineTracks
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
%This function ensures all loaded files have matching column titles for
%features in the same order, and combines them.
%
%The cell array train_data_source needs to be replace with something more
%appropriate. This is a consequence of using SelectTrainingFilesPopUp().
%
%Inputs
%------
%app          (handle)  main GUI handle
%data_source  (char)    char array of data source to load, options are,
%                           human annotations: 'VisuallyLabelled'
%                           ground truth: 'GroundTruth'
%
%Outputs
%-------
%track_data_combined  (cell)  combined track data across multiple files
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %launch popup for user to select files
    popup = SelectTrainingFilesPopUp(app);
    uiwait(popup.UIFigure);
    
    %check if the user provided valid files
    if ~isfield(app.movie_data.params, "train_data_source") || isempty(app.movie_data.params.train_data_source)
        warndlg("No valid source files were provided. Please select files and try again.", "No files selected");
        track_data_combined = {};
        return;
    end
    
    track_data_combined = {};
    
    %retrieve current column titles
    curr_col_titles = app.movie_data.params.column_titles.tracks;
    
    %loop over all selected files
    for file_idx = 1:size(app.movie_data.params.train_data_source, 1)
        curr_pathname = app.movie_data.params.train_data_source{file_idx};
        if strcmp(curr_pathname, "[Currently loaded annotations]")
            %if file refers to curr loaded data
            switch data_source
                case "VisuallyLabelled"
                    track_data = app.movie_data.results.VisuallyLabelled.LabelledMols;
                case "GroundTruth"
                    track_data = app.movie_data.results.GroundTruth.LabelledMols;
                otherwise
                    error("Invalid data source specified.");
            end
            column_titles_to_check = app.movie_data.params.column_titles.tracks;
        else
            %load data from external file
            data = load(curr_pathname);
            switch data_source
                case "VisuallyLabelled"
                    if isfield(data.movie_data.results, "VisuallyLabelled")
                        track_data = data.movie_data.results.VisuallyLabelled.LabelledMols;
                    else
                        warndlg("The file does not contain human annotated data. Skipping file: " + curr_pathname, "Invalid File");
                        continue;
                    end
                case "GroundTruth"
                    if isfield(data.movie_data.results, "GroundTruth")
                        track_data = data.movie_data.results.GroundTruth.LabelledMols;
                    else
                        warndlg("The file does not contain ground truth data. Skipping file: " + curr_pathname, "Invalid File");
                        continue;
                    end
                otherwise
                    error("Invalid data source specified.");
            end
            column_titles_to_check = data.movie_data.params.column_titles.tracks;
        end
        
        %verify column titles match
        if ~isequal(curr_col_titles, column_titles_to_check)
            app.textout.Value = "Column titles in the loaded file do not match the currently loaded data. Aborting.";
            warndlg("Mismatch in column titles detected. Ensure all files have identical features.", "Column Title Mismatch");
            track_data_combined = {};
            return;
        end
        
        %append the current file's track data to combined cell array
        track_data_combined = [track_data_combined; track_data];
    end
    
    %verify the combined data is not empty
    if isempty(track_data_combined)
        app.textout.Value = "The combined data is empty. Ensure the selected files contain valid data.";
        warndlg("The combined data is empty; ensure the selected files contain valid data.", "No Data");
    end
end