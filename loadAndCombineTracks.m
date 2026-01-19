function [track_data_combined] = loadAndCombineTracks(app, data_source)
%Load and combine tracks from multiple external files, Oliver Pambos,
%14/12/2024.
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