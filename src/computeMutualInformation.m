function [] = computeMutualInformation(app, method)
%Compute mutual information between each feature and assigned class, and
%between feature pairs, 12/12/2024.
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
%This function computes the mutual information between all requested
%feature pairs, and the mutual information between each requested feature
%and the known class. When computing MI for feature vs class, it is able to
%compute the scores for all data, as well as restricted to
%changepoint-proximal and changepoint-distal regions. For the latter, it
%visualises the scores with an hbar plot for both masked regions
%simultaneously. For all feature vs class results the feature are ranked in
%decending order of MI score. For the masked scores the ranking is
%performed as the sum of the scores in proximal and distal regions. All
%requested feature pair scores are displayed as a heatmap.
%
%This function is able to operate on the currently-loaded file, or on
%combinations of external files and internal data. It is able to use either
%the loaded ground truth or human annotations for class comparisons where
%required.
%
%Due to the extremely varied distributions produced by all features, and
%the unknown distribution of arbitrary features that may be provided by the
%user, adaptive binning is used to space bin edges non-linearly to ensure
%the data is well sampled even in cases for example in which a feature
%contains an extremely long-tailed distribution. The number of bins is
%hardcoded to 25, such a bin typically contains ~4% of data for the
%feature; this was found to work well with the type of data present in SMLM
%tracking data experiments.
%
%Inputs
%------
%app    (handle)    main GUI handle
%method (str)       determines whether to perform feature ranking via MI or
%                       to compute MI between feature pairs, options are,
%                           'pairwise': compute MI between all requested
%                               feature pairs
%                           'ranked': rank features by mutual information
%                               with known class for each localisation
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%concatTracks()
%computeMIScoresFeatureVsClass()
%splitCPRegions()                   - local to this .m file
%plotMIRanked()                     - local to this .m file
%plotMIScoresProximalDistal()       - local to this .m file
%computeFeaturePairwiseMI()         - local to this .m file
%plotPairwiseMIHeatmap()            - local to this .m file
    
    %bins used to discretise data
    N_bins = 25;
    cp_range = app.FeatureImportanceChangepointmasksizeSpinner.Value;
    
    %obtain list of features to use
    switch app.FeatureImportanceFeaturesubsetDropDown.Value
        case "All features"
            feature_list = app.movie_data.params.column_titles.tracks(:, 1:end-1);
        case "Selected features"
            feature_list = app.MLfeatures.CheckedNodes;
            if isempty(feature_list)
                app.textout.Value = "You have not selected any features! Please select features to analyze from the [Features] list.";
                warndlg("You have not selected any features! Please select features to analyze from the [Features] list.", "No features selected!");
                return;
            end
            feature_list = {feature_list.Text};
        otherwise
            app.textout.Value = "Invalid option selected in [Feature subset] dropdown. Please select either 'All features' or 'Selected features'.";
            warndlg("Invalid option selected in [Feature subset] dropdown. Please select either 'All features' or 'Selected features'.", "Invalid selection!");
            return;
    end
    
    %get source data
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
            warndlg("The selected dataset is invalid or unavailable.", "No data available!");
            return;
    end
    if isempty(track_data)
        app.textout.Value = "The selected dataset contains no annotated data. Please load the appropriate file or perform human annotation.";
        warndlg("The selected dataset contains no annotated data. Please load the appropriate file or perform human annotation.", "No annotated data!");
        return;
    end
    
    [feature_data, class_data] = concatTracks(track_data);
    
    switch method
        case 'ranked'
            %separate changepoint-proximal and distal data
            [feature_data_cp, class_data_cp, feature_data_distal, class_data_distal] = splitCPRegions(track_data, cp_range);
            
            %compute MI for all data, changepoint-proximal and distal data
            MI_scores_all_data  = computeMIScoresFeatureVsClass(feature_data, class_data, feature_list, app.movie_data.params.column_titles.tracks, N_bins);
            MI_scores_cp        = computeMIScoresFeatureVsClass(feature_data_cp, class_data_cp, feature_list, app.movie_data.params.column_titles.tracks, N_bins);
            MI_scores_distal    = computeMIScoresFeatureVsClass(feature_data_distal, class_data_distal, feature_list, app.movie_data.params.column_titles.tracks, N_bins);
            
            %plot MI for all data
            plotMIRanked(feature_list, MI_scores_all_data);
            
            %plot changepoint-proximal and distal MI scores
            plotMIScoresProximalDistal(feature_list, MI_scores_cp, MI_scores_distal);
        
        case 'pairwise'
            %compute and plot pairwise MI between features
            computeFeaturePairwiseMI(feature_data, feature_list, app.movie_data.params.column_titles.tracks, N_bins);
            
        otherwise
            return;
    end
end


function [feature_data_proximal, class_data_proximal, feature_data_distal, class_data_distal] = splitCPRegions(track_data, cp_range)
%Split tracks into changepoint-proximal and changepoint-distal regions, and
%return as concatenated matrices, 12/12/2024.
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
%This function is extremely inefficient, and needs to be replaced with
%pre-allocation.
%
%Inputs
%------
%track_data (cell)  cell array of tracks, where each cell contains a struct
%                       with a matrix named '.Mol' of dimensions Ax(B+1)
%                       where A is the number of localisations and B is the
%                       number of features; the final column containing the
%                       assigned class ID
%cp_range   (int)   number of localisations before and after each
%                       changepoint to use to construct the changepoint
%                       proximal mask.
%
%Output
%------
%feature_data_proximal        (mat)   NxM matrix of all tracked localisations in
%                               changepoint-proximal regions, where N is
%                               the number of localistions, and M is the
%                               number of features
%class_data_proximal         (vec)   Nx1 column vector of class IDs for all
%                               changepoint-proximal localisations
%feature_data_distal    (mat)   NxM matrix of all tracked localisations in
%                               changepoint-distal regions, where N is
%                               the number of localistions, and M is the
%                               number of features
%class_data_distal     (vec)   Nx1 column vector of class IDs for all
%                               changepoint-distal localisations
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    feature_data_proximal     = [];
    class_data_proximal      = [];
    feature_data_distal = [];
    class_data_distal  = [];
    
    %loop over all tracks
    for ii = 1:numel(track_data)
        curr_track      = track_data{ii, 1}.Mol;
        feature_data    = curr_track(:, 1:end-1);
        class_data      = curr_track(:, end);
        
        %construct changepoint-proximal and distal masks using diff
        changepoints    = find(diff(class_data) ~= 0);
        cp_mask         = false(size(class_data));
        for idx = changepoints'
            range = max(1, idx - cp_range + 1) : min(length(class_data), idx + cp_range);
            cp_mask(range) = true;
        end
        distal_mask = ~cp_mask;
        
        %concat changepoint-proximal, and changepoint-distal from current track, onto global data
        feature_data_proximal   = [feature_data_proximal; feature_data(cp_mask, :)];
        class_data_proximal     = [class_data_proximal; class_data(cp_mask)];
        feature_data_distal     = [feature_data_distal; feature_data(distal_mask, :)];
        class_data_distal       = [class_data_distal; class_data(distal_mask)];
    end
end


function [] = plotMIRanked(feature_list, MI_scores)
%Display features ranked by mutual information with class score,
%12/12/2024.
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
%feature_list   (cell)  cell array of char arrays, where each cell contains
%                           the name of a feature selected by the user
%MI_scores      (vec)   vector containing mutual information between the
%                           known classes and the features in feature_list
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %rank features
    [sorted_scores, sorted_idx] = sort(MI_scores, 'descend');
    ranked_features             = feature_list(sorted_idx);
    y_positions                 = 1:numel(ranked_features);
    
    %display horizontal bar chart of ranking
    figure('Name', 'Feature importance ranked by mutual information', 'Color', 'w', 'MenuBar', 'none');
    barh(y_positions, sorted_scores, 'FaceColor', [0.3, 0.7, 0.9]);
    set(gca, 'YDir', 'reverse');    %reverse y-axis; best features at top
    yticks(y_positions);
    yticklabels({});                %suppress tick labels
    xlabel('Mutual Information');
    title('Feature importance ranked by feature-class mutual information across full dataset');
    xlim([0, max(sorted_scores) * 1.1]);
    set(gca, 'FontSize', 16);
    
    %display feature names as text annotations over data
    x_offset = 0.02 * max(sorted_scores);   %move away from y-axis
    for ii = 1:numel(ranked_features)
        text(x_offset, y_positions(ii), ranked_features{ii}, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Color', 'k', 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
    end
end


function [] = plotMIScoresProximalDistal(feature_list, MI_scores_proximal, MI_scores_distal)
%Plots the mutual information shared between each feature and known classes
%in changepoint proximal and changpoint distal regions on the same plot,
%12/12/2024.
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
%This function plots the MI feature-class scores on the same plot, with
%changepoint-proximal going negative, and changepoint-distal positive. The
%features are ranked by the sum of their proximal and distal scores.
%
%Inputs
%------
%feature_list       (cell)  cell array of char arrays, where each cell
%                               contains the name of a feature selected by
%                               the user
%MI_scores_proximal (vec)   vector containing mutual information score
%                               between features and known classes in
%                               changepoint-proximal regions
%MI_scores_distal   (vec)   vector containing mutual information score
%                               between features and known classes in
%                               changepoint-distal regions
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %combine changepoint-proximal and distal MI scores, then rank by total
    [~, sorted_idx] = sort(MI_scores_proximal + MI_scores_distal, 'descend');
    ranked_features = feature_list(sorted_idx);
    
    %combine scores with proximal as negative and distal as positive
    combined_scores = [MI_scores_proximal(sorted_idx) * -1; MI_scores_distal(sorted_idx)]';
    
    %display ranked results
    figure('Name', 'MI scores in changepoint-proximal and changepoint-distal regions', 'Color', 'w', 'MenuBar', 'none');
    barh(categorical(ranked_features, ranked_features), combined_scores, 'stacked');
    set(gca, 'YDir', 'reverse');    %invert y-axis to rank highest features at top
    xlabel('Feature-class mutual information');
    ylabel('Features');
    title('Mutual information shared between features and classes');
    legend({'Changepoint-proximal', 'Changepoint-distal'}, 'Location', 'best');
    set(gca, 'FontSize', 16);
end


function [] = computeFeaturePairwiseMI(feature_data, feature_list, feature_names, N_bins)
%Compute pairwise mutual information between all requested features,
%14/12/2024.
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
%Note that this f'n also currently plots the pairwise feature heatmap by
%calling the plotting function plotPairwiseMIHeatmap().
%
%Inputs
%------
%feature_data   (mat)   concatenated NxM matrix of the subset of M
%                               features to be computed; N is number of
%                               localisations; this matrix is concatenated
%                               from all tracks
%feature_list   (cell)  cell array of char arrays, where each cell contains
%                               the name of a feature selected by the user
%feature_names  (cell)  cell array of char arrays, containing the
%                               complete list of feature names in the
%                               source data
%N_bins         (int)   number of bins to use in discretising features
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%plotPairwiseMIHeatmap()    - local to this .m file
    
    if isempty(feature_list) || isempty(feature_data)
        error('Feature list or combined features matrix is empty.');
    end
    
    N_features  = numel(feature_list);
    MI_matrix   = zeros(N_features, N_features);
    
    %bin all features into cell array
    discrete_features = cell(1, N_features);
    for ii = 1:N_features
        feature_idx = findColumnIdx(feature_names, feature_list{ii});
        if isempty(feature_idx)
            error('Feature "%s" not found in feature_names.', feature_list{ii});
        end
        curr_feature_data = feature_data(:, feature_idx);
        bin_edges = unique(quantile(curr_feature_data, linspace(0, 1, N_bins + 1)));
        discrete_features{ii} = discretize(curr_feature_data, bin_edges);
    end
    
    %compute MI score for each feature pair
    for ii = 1:N_features
        %compute only upper triangle (matrix is symmetric)
        for jj = ii:N_features
            discrete_feature_1 = discrete_features{ii};
            discrete_feature_2 = discrete_features{jj};
            
            %joint and marginal probs
            joint_prob = histcounts2(discrete_feature_1, discrete_feature_2, ...
                                     (1:N_bins + 1) - 0.5, ...
                                     (1:N_bins + 1) - 0.5, ...
                                     'Normalization', 'probability');
            prob_feature_1 = sum(joint_prob, 2);
            prob_feature_2 = sum(joint_prob, 1);
            
            %compute MI score
            MI = 0;
            for k = 1:N_bins
                for l = 1:N_bins
                    if joint_prob(k, l) > 0
                        MI = MI + joint_prob(k, l) * log2(joint_prob(k, l) / (prob_feature_1(k) * prob_feature_2(l)));
                    end
                end
            end
            
            %store result
            MI_matrix(ii, jj) = MI;
            MI_matrix(jj, ii) = MI; %symmetric value
        end
    end
    
    %plot heatmap
    plotPairwiseMIHeatmap(MI_matrix, feature_list);
end


function [] = plotPairwiseMIHeatmap(MI_mat, feature_list)
%Plot heatmap of all pairwise mutual information between all requested
%features, 14/12/2024.
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
%MI_mat         (mat)   square matrix of size N, where N is the number of
%                           features; each element contains the mutual
%                           information score for the feature pair
%feature_list   (cell)  cell array of char arrays, where each cell
%                           contains the name of a feature associated with
%                           the coloumn and row entries of MI_mat
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    figure('Name', 'Pairwise feature mutual information heatmap', 'Color', 'w', 'MenuBar', 'none');
    h_heatmap = heatmap(feature_list, feature_list, MI_mat);
    h_heatmap.ColorLimits = [0, max(MI_mat(:))];
    h_heatmap.FontSize = 16;
    h_heatmap.Title = 'Pairwise mutual information heatmap for all features';
end