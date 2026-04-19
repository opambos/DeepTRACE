function [] = computeFeatureCorrelation(app)
%Computes and displays the Pearson correlation pairwise between all feature
%pairs, 16/12/2024.
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
%combineTrackData() - local to this .m file
%computeCorrelationMatrix()
%plotCorrelationHeatmap()
    
    %get feature list
    switch app.FeatureImportanceFeaturesubsetDropDown.Value
        case "All features"
            feature_list = app.movie_data.params.column_titles.tracks(1:end-1);
        case "Selected features"
            feature_list = app.MLfeatures.CheckedNodes;
            if isempty(feature_list)
                uialert(app.DeepTRACEUIFigure, "You have not selected any features! Please select features to analyze from the [Features] list.", "No features selected!", "Icon", "warning")
                return;
            end
            feature_list = {feature_list.Text};
        otherwise
            uialert(app.DeepTRACEUIFigure, "Invalid option selected in [Feature subset] dropdown. Please select either 'All features' or 'Selected features'.", "Invalid selection!", "Icon", "warning")
            return;
    end
    
    %gather source data
    switch app.FeatureImportanceSourcedataDropDown.Value
        case "Ground truth"
            track_data = app.movie_data.results.GroundTruth.LabelledMols;
        case "Human annotations"
            track_data = app.movie_data.results.VisuallyLabelled.LabelledMols;
        case "Human annotations (multiple experiments)"
            track_data = loadAndCombineTracks(app, "VisuallyLabelled");
        case "Ground truth (multiple simulations)"
            track_data = loadAndCombineTracks(app, "GroundTruth");
        otherwise
            app.textout.Value = "The selected dataset is invalid or unavailable.";
            uialert(app.DeepTRACEUIFigure, "The selected dataset is invalid or unavailable.", "No data available!", "Icon", "warning")
            return;
    end
    
    if isempty(track_data)
        uialert(app.DeepTRACEUIFigure, "The selected dataset contains no annotated data. Please load the appropriate file or perform human annotation.", "No annotated data!", "Icon", "warning")
        return;
    end
    
    %concatenate all feature data across all tracks into single mat
    all_feature_data = concatFeatureData(track_data);
    
    %compute and plot correlation matrix
    correlation_matrix = computeCorrelationMatrix(all_feature_data, feature_list, app.movie_data.params.column_titles.tracks);
    plotCorrelationHeatmap(correlation_matrix, feature_list);
end


function [all_feature_data] = concatFeatureData(track_data)
%Concatenate all feature data across all tracks into single matrix,
%16/12/2024.
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
%Inputs
%------
%track_data (cell)  cell array for every track in the dataset; each cell
%                       contains a struct holding a matrix title 'Mol'
%                       which contains the individual track data
%
%Output
%------
%all_feature_data   (mat)   NxM matrix of all concatenated feature data in
%                               the dataset, where N is the total number of
%                               tracked localisations, and M is the number
%                               of features
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    all_feature_data = [];
    for ii = 1:numel(track_data)
        curr_track = track_data{ii, 1}.Mol;
        all_feature_data = [all_feature_data; curr_track(:, 1:end-1)];
    end
end


function [corr_mat] = computeCorrelationMatrix(all_feature_data, feature_list, column_titles)
%Compute Pearson correlation matrix for all requested feature pairs,
%16/12/2024.
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
%Inputs
%------
%features, feature_list, column_titles
%
%Output
%------
%corr_mat   (mat)   square matrix of size N, containing Pearson correlation
%                       for all possible feature pairs of the requested N
%                       features
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %get indices of requested features
    feature_indices = zeros(1, numel(feature_list));
    for ii = 1:numel(feature_list)
        feature_idx = findColumnIdx(column_titles, feature_list{ii});
        if isempty(feature_idx)
            error("Feature '%s' not found in column_titles.", feature_list{ii});
        end
        feature_indices(ii) = feature_idx;
    end
    
    %check indices fall within range
    if any(feature_indices > size(all_feature_data, 2))
        error("One or more feature indices exceed the size of the feature matrix.");
    end
    
    %reduce data to only requested features
    selected_features = all_feature_data(:, feature_indices);
    
    %compute Pearson correlation between requested features
    corr_mat = corr(selected_features, 'Type', 'Pearson');
end


function [] = plotCorrelationHeatmap(corr_mat, feature_list)
%Plot heatmap of Pearson correlation matrix, 16/12/2024.
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
%Inputs
%------
%corr_mat       (mat)   square matrix of size N, containing Pearson
%                           correlation for all feature pairs of the
%                           requested N features
%feature_list   (cell)  cell array of char arrays, each holding the names
%                           of the features in the correlation map in the
%                           order in which they appear in corr_mat
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    figure('Name', 'Pairwise feature correlation heatmap', 'Color', 'w');
    
    %define custom colormap: red for -1 (perfect negative correlation); white for 0 (no correlation); navy blue for +1 (perfect positive correlation)
    N_colours       = 256;
    red_to_white    = [linspace(1, 1, N_colours/2)', linspace(0, 1, N_colours/2)', linspace(0, 1, N_colours/2)'];
    white_to_blue   = [linspace(1, 0, N_colours/2)', linspace(1, 0, N_colours/2)', linspace(1, 0.5, N_colours/2)'];
    custom_cmap     = [red_to_white; white_to_blue];
    
    %plot heatmap
    h_corrmap               = heatmap(feature_list, feature_list, corr_mat, 'Colormap', custom_cmap);
    h_corrmap.Title         = 'Pearson Correlation Heatmap';
    h_corrmap.ColorLimits   = [-1, 1]; %ensure colour lims symmetric about zero
end


function [track_data_combined] = loadAndCombineTracks(app, data_source)
%Load and combine tracks from multiple external files into single cell
%array, 16/12/2024.
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
    
    %Launch popup for user to select files
    popup = SelectTrainingFilesPopUp(app);
    uiwait(popup.SelectTrainingDataUIFigure);
    
    %check if the user provided valid files
    if ~isfield(app.movie_data.params, "train_data_source") || isempty(app.movie_data.params.train_data_source)
        uialert(app.DeepTRACEUIFigure, "No valid source files were provided, please try again.", "No files selected", "Icon", "warning")
        track_data_combined = {};
        return;
    end
    
    track_data_combined = {};
    curr_col_titles     = app.movie_data.params.column_titles.tracks;
    
    %loop over selected files, appending to cell array
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
                        uialert(app.DeepTRACEUIFigure, "The file does not contain human annotated data, skipping file: " + curr_pathname, "Invalid File", "Icon", "warning")
                        continue;
                    end
                case "GroundTruth"
                    if isfield(data.movie_data.results, "GroundTruth")
                        track_data = data.movie_data.results.GroundTruth.LabelledMols;
                    else
                        uialert(app.DeepTRACEUIFigure, "The file does not contain ground truth data, skipping file: " + curr_pathname, "Invalid File", "Icon", "warning")
                        continue;
                    end
                otherwise
                    error("Invalid data source specified.");
            end
            column_titles_to_check = data.movie_data.params.column_titles.tracks;
        end
        
        %verify col titles match
        if ~isequal(curr_col_titles, column_titles_to_check)
            uialert(app.DeepTRACEUIFigure, "Mismatch in column titles detected. Ensure all files have identical features.", "Column Title Mismatch", "Icon", "warning")
            track_data_combined = {};
            return;
        end
        
        %append the current file's track data to combined cell array
        track_data_combined = [track_data_combined; track_data];
    end
    
    %verify combined data is not empty
    if isempty(track_data_combined)
        uialert(app.DeepTRACEUIFigure, "The combined data is empty; ensure the selected files contain valid data.", "No Data", "Icon", "warning")
    end
end