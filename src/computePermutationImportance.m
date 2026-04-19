function [] = computePermutationImportance(app)
%Compute the permutation importance for the set of requested features,
%20/12/2024.
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
%This function evaluates the drop in performance of a pre-trained model by
%evaluating its accuracy (currently the only implemented metric) on a test
%dataset. It then permutes (randomly shuffles) all values for a feature
%across all localisations and tracks so that the values are no longer
%associated with the correct known class. It repeats this a user-defined
%number of times for the feature, obtaining the mean and standard deviation
%of the drop in the metric for that feature. The process is then repeated
%for all requested features, and the features are then ranked according
%this permutation importance. The results are displayed on a bar chart and
%in the textout GUI display.
%
%The function can use either human annotation or ground truth data if this
%is available.
%
%Note that this is currently using the sliding window classifiction method
%only.
%
%Input
%-----
%app        (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeConsensus()
%computePerformance()               - local to this .m file
%computePerformanceChangepoint()    - local to this .m file
%obtainCPMasks()                    - local to this .m file
%computeAccuracy()                  - local to this .m file
    
    if ~isprop(app, 'movie_data') || ~isfield(app.movie_data, 'models') || ~isfield(app.movie_data.models, 'current_model')
        app.textout.Value = "No currently loaded model is available; please load a model from the .";
        warndlg("The selected dataset is invalid or unavailable.", "No data available!");
        return;
    end
    model_type = app.movie_data.models.current_model;
    
    %obtain data
    switch app.PermutationImportanceSourcedataDropDown.Value
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
    
    data_source = app.PermutationImportanceDatasubsetDropDown.Value;
    cp_range    = app.PermutationImportanceChangepointrangeSpinner.Value;
    
    %obtain features
    feature_names   = app.movie_data.models.(model_type).feature_names;
    feature_cols    = zeros(1, numel(feature_names));
    for ii = 1:numel(feature_names)
        idx = find(ismember(app.movie_data.params.column_titles.tracks, feature_names{ii}));
        if ~isempty(idx)
            feature_cols(ii) = idx;
        else
            app.textout.Value = "Feature '" + feature_names{ii} + "' used by the model was missing in the loaded data. Exiting. Please check that the data you are annotating contains this feature";
            warndlg("Feature '" + feature_names{ii} + "' used by the model was missing in the loaded data. Exiting.", ...
                    "Error", "modal");
            return;
        end
    end
    
    %reformat cell array to DLArray
    [data_dlarray, source_track] = reformatToDLArray(track_data, app.movie_data.models.(model_type).max_len, feature_cols);
    
    %apply feature scaling
    scaled_data_dlarray = data_dlarray;
    switch app.movie_data.models.(model_type).feature_scaling
        case "None"
            %<< do nothing >>
        case "Z-score"
            %standardize each feature using Z-score
            for jj = 1:numel(feature_cols)
                mean_val = app.movie_data.models.(model_type).feature_means(jj);
                std_val = app.movie_data.models.(model_type).feature_stds(jj);
                scaled_data_dlarray(jj, :, :) = (scaled_data_dlarray(jj, :, :) - mean_val) / std_val;
            end
        case "Normalise (0-1)"
            %normalize each feature using min-max normalization
            for jj = 1:numel(feature_cols)
                min_val = app.movie_data.models.(model_type).feature_mins(jj);
                max_val = app.movie_data.models.(model_type).feature_maxs(jj);
                scaled_data_dlarray(jj, :, :) = (scaled_data_dlarray(jj, :, :) - min_val) / (max_val - min_val);
            end
        otherwise
            error('Unknown feature scaling method.');
    end
    
    %obtain the baseline reference performance of the model without permutation
    probabilities   = softmax(predict(app.movie_data.models.(model_type).model, scaled_data_dlarray));
    switch data_source
        case "All data"
            baseline_score = computePerformance(probabilities, source_track, track_data, data_source, cp_range);
        case "Changepoint mask"
            [baseline_score_proximal, baseline_score_distal] = computePerformanceChangepoint(probabilities, source_track, track_data, cp_range);
    end
    
    %init score matrices
    N_features  = numel(feature_cols);
    N_repeats   = app.PermutationImportanceRepeatsperfeatureSpinner.Value;
    if strcmp(data_source, "Changepoint mask")
        scores_proximal = zeros(N_features, N_repeats);
        scores_distal   = zeros(N_features, N_repeats);
    else
        scores_all = zeros(N_features, N_repeats);
    end
    
    %init waitbar
    h           = waitbar(0, 'Computing permutation importance...');
    set(h, 'Name', 'Permutation Importance Progress', 'NumberTitle', 'off');
    total_iter  = N_features * N_repeats;
    curr_iter   = 0;
    
    %for each feature, permute and evaluate drop in performance
    for ii = 1:N_features
        for rr = 1:N_repeats
            %update waitbar
            curr_iter = curr_iter + 1;
            waitbar(curr_iter / total_iter, h, "Permuting feature " + ii + "/" + N_features + ", repeat " + rr + "/" + N_repeats + "; (" + round(100*curr_iter/total_iter) + "% complete)");
            
            %shuffle data for current feature
            shuffled_data_dlarray = scaled_data_dlarray;
            flattened_data = reshape(shuffled_data_dlarray(ii, :, :), [], 1);
            shuffled_flattened_data = flattened_data(randperm(numel(flattened_data)));
            shuffled_data_dlarray(ii, :, :) = reshape(shuffled_flattened_data, size(scaled_data_dlarray(ii, :, :)));
    
            %classify with shuffled data
            probabilities_shuffled = softmax(predict(app.movie_data.models.(model_type).model, shuffled_data_dlarray));
            
            %compute permuted performance
            [shuffled_score_all, shuffled_score_proximal, shuffled_score_distal] = computePerformance(probabilities_shuffled, source_track, track_data, data_source, cp_range);
            
            %store scores
            if strcmp(data_source, "All data")
                scores_all(ii, rr) = baseline_score - shuffled_score_all;
            elseif strcmp(data_source, "Changepoint mask")
                scores_proximal(ii, rr) = baseline_score_proximal - shuffled_score_proximal;
                scores_distal(ii, rr)   = baseline_score_distal - shuffled_score_distal;
            end
        end
    end

    close(h);
    
    %collect results into matrix, and sort by importance (all data) or total importance (proximal + distal)
    if strcmp(data_source, "All data")
        result_matrix = [mean(scores_all, 2), std(scores_all, 0, 2)];
        
        [~, sorted_idx]         = sort(result_matrix(:, 1), 'ascend');
        result_matrix           = result_matrix(sorted_idx, :);
        feature_names_sorted    = feature_names(sorted_idx);
    else
        mean_importance_proximal    = mean(scores_proximal, 2);
        std_importance_proximal     = std(scores_proximal, 0, 2);
        mean_importance_distal      = mean(scores_distal, 2);
        std_importance_distal       = std(scores_distal, 0, 2);
        
        %cols: (1) mean_proximal, (2) std_proximal, (3) mean_distal, (4) std_distal, (5) total importance
        result_matrix = [mean_importance_proximal, std_importance_proximal, ...
                         mean_importance_distal, std_importance_distal, ...
                         abs(mean_importance_proximal) + abs(mean_importance_distal)];
        
        [~, sorted_idx]         = sort(result_matrix(:, 5), 'ascend');
        result_matrix           = result_matrix(sorted_idx, :);
        feature_names_sorted    = feature_names(sorted_idx);
    end
    
    %==========================================
    %Visualize results with horizontal bar plot
    %==========================================
    figure; hold on; box on;
    if strcmp(data_source, "All data")
        barh(result_matrix(:, 1), 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
        errorbar(result_matrix(:, 1), 1:N_features, result_matrix(:, 2), 'horizontal', 'k', 'LineStyle', 'none');
        xlabel('Permutation importance (drop in performance)');
        
    else
        %identify features with negative importance (these will be displayed as absolute value with symbol to simplify plot)
        neg_indices_proximal    = result_matrix(:, 1) < 0;
        neg_indices_distal      = result_matrix(:, 3) < 0;
        
        %get y positions to align bars (proximal and distal for each feature)
        y_pos       = categorical(feature_names_sorted, feature_names_sorted);
        bar_width   = 0.4;
        
        %plot proximal (left), and distal (right); stdev error bars
        barh(y_pos, -abs(result_matrix(:, 1)), bar_width, 'FaceColor', [0.6 0.8 1], 'EdgeColor', 'k');
        barh(y_pos, abs(result_matrix(:, 3)), bar_width, 'FaceColor', [1 0.6 0.6], 'EdgeColor', 'k');
        for ii = 1:N_features
            errorbar(-abs(result_matrix(ii, 1)), y_pos(ii), -abs(result_matrix(ii, 2)), 'horizontal', 'k', 'LineStyle', 'none');
            errorbar(abs(result_matrix(ii, 3)), y_pos(ii), abs(result_matrix(ii, 4)), 'horizontal', 'k', 'LineStyle', 'none');
        end
        
        %place symbol next to any bar forced as absolute value, so user knows it should be negative
        symbol = '†';
        for ii = 1:N_features
            if neg_indices_proximal(ii)
                text(-abs(result_matrix(ii, 1)) - 0.1 * max(abs(result_matrix(:, 1))), y_pos(ii), symbol, 'HorizontalAlignment', 'left', 'FontSize', 12, 'FontWeight', 'bold');
            end
            if neg_indices_distal(ii)
                text(abs(result_matrix(ii, 3)) + 0.1 * max(abs(result_matrix(:, 3))), y_pos(ii), symbol, 'HorizontalAlignment', 'right', 'FontSize', 12, 'FontWeight', 'bold');
            end
        end
        
        xlabel('Permutation importance (drop in performance)');
        legend({'Changepoint-proximal (left)', 'Changepoint-distal (right)', '† Negative importance displayed as absolute value for clarity'}, 'Location', 'best');
    end
    hold off;
    set(gca, 'YTickLabel', feature_names_sorted');
    set(gca, 'FontSize', 16);
    title('Feature permutation importance');
    
    %====================================
    %Display results as text in GUI panel
    %====================================
    switch data_source
        case "All data"
            app.textout.Value = "Permutation importance computed using " + data_source + " dataset.";
            
        case "Changepoint mask"
            % Prepare data for uitable
            table_data = [feature_names_sorted(:), num2cell(result_matrix(:, [1, 3, 5]))];
            column_names = {'Feature Name', 'Proximal Importance', 'Distal Importance', 'Total Importance'};
            
            % Create a pop-up figure for the table
            fig = uifigure('Name', 'Permutation Importance Results', 'Position', [100 100 800 400]);
            uitable(fig, 'Data', table_data, 'ColumnName', column_names, ...
                    'RowName', [], 'Position', [25 25 750 350]);
            
            % Update textout with a brief summary
            app.textout.Value = "Permutation importance computed using " + data_source + " dataset. Results displayed in pop-up table.";
    end

end


function [score_all, score_proximal, score_distal] = computePerformance(probabilities, source_track, track_data, data_source, cp_range)
%Evaluate performance of a model on shuffled or unshuffled data,
%20/12/2024.
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
%Input
%-----
%probabilities      (vec)   model output probabilities
%source_track       (vec)   Mx1 column vector of ints which identify
%                               the original track to which each of the
%                               M windows (i.e. each slice of
%                               data_dlarray) correspond to; this
%                               enables annotations to be written back
%                               correctly to each track.
%data_source        (str)   source of data, options are,
%                               "All data"
%                               "Changepoint-proximal"
%                               "Changepoint-distal"
%track_data         (cell)  cell array where each cell contains a struct
%                               with a matrix named '.Mol' which holds the
%                               track data for a single track
%cp_range           (int)   range of changepoint-proximal region, set by
%                               user in GUI
%
%Output
%------
%score_all      (float) performance metric (e.g. accuracy)
%score_proximal (float) performance metric (e.g. accuracy) in the
%                           changepoint-proximal region, if relevant
%score_distal   (float) performance metric (e.g. accuracy) in the
%                           changepoint-distal region, if relevant
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeConsensus()
%applyChangepointMaskToTrack()  - local to this .m file
%computeAccuracy()              - local to this .m file
    
    %evaluate consensus predictions from sliding windows
    [tracks_cell_array] = computeConsensus(track_data, probabilities, source_track);
    predicted_labels    = cellfun(@(x) x.Mol(:, end), tracks_cell_array, 'UniformOutput', false);
    ground_truth_labels = cellfun(@(x) x.Mol(:, end), track_data, 'UniformOutput', false);
    
    score_all = NaN;
    score_proximal = NaN;
    score_distal = NaN;
    
    switch data_source
        case "All data"
            track_mask  = cellfun(@(x) true(size(x)), ground_truth_labels, 'UniformOutput', false); %mask == true for every datapoint
            score_all   = computeAccuracy(ground_truth_labels, predicted_labels, track_mask);
            
        case "Changepoint mask"
            %obtain masks for proximal and distal regions, and compute scores
            [track_mask_proximal, track_mask_distal] = cellfun(@(x) obtainCPMasks(x, cp_range), ground_truth_labels, 'UniformOutput', false);
            
            score_proximal  = computeAccuracy(ground_truth_labels, predicted_labels, track_mask_proximal);
            score_distal    = computeAccuracy(ground_truth_labels, predicted_labels, track_mask_distal);
    end
end


function [score_proximal, score_distal] = computePerformanceChangepoint(probabilities, source_track, track_data, cp_range)
%Compute performance in changepoint proximal and distal regions,
%20/12/2024.
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
%Input
%-----
%probabilities      (vec)   model output probabilities
%source_track       (vec)   Mx1 column vector of ints which identify
%                               the original track to which each of the
%                               M windows (i.e. each slice of
%                               data_dlarray) correspond to; this
%                               enables annotations to be written back
%                               correctly to each track.
%track_data         (cell)  cell array where each cell contains a struct
%                               with a matrix named '.Mol' which holds the
%                               track data for a single track
%cp_range           (int)   range of changepoint-proximal region, set by
%                               user in GUI
%
%Output
%------
%score_proximal (float) performance metric (e.g. accuracy) in the
%                           changepoint-proximal region, if relevant
%score_distal   (float) performance metric (e.g. accuracy) in the
%                           changepoint-distal region, if relevant
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeConsensus()
%obtainCPMasks()    - local to this .m file
%computeAccuracy()  - local to this .m file
    
    %evaluate consensus predictions from sliding windows
    [tracks_cell_array] = computeConsensus(track_data, probabilities, source_track);
    predicted_labels    = cellfun(@(x) x.Mol(:, end), tracks_cell_array, 'UniformOutput', false);
    ground_truth_labels = cellfun(@(x) x.Mol(:, end), track_data, 'UniformOutput', false);
    
    %apply masks for proximal and distal regions in all tracks
    [track_mask_proximal, track_mask_distal] = cellfun(@(x) obtainCPMasks(x, cp_range), ground_truth_labels, 'UniformOutput', false);

    %compute scores
    score_proximal  = computeAccuracy(ground_truth_labels, predicted_labels, track_mask_proximal);
    score_distal    = computeAccuracy(ground_truth_labels, predicted_labels, track_mask_distal);
end


function [mask_proximal, mask_distal] = obtainCPMasks(class_data, cp_range)
%Obtain the changepoint masks for a single track, 20/12/2024.
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
%Input
%-----
%class_data     (vec)   column vector of known classes for the track
%cp_range       (int)   number of localisations either side of changepoint
%                           to be considered changepoint-proximal
%
%Output
%------
%mask_proximal  (vec) column vector of bool representing the cp mask for
%                           changepoint-proximal regions of the input track
%                           defined by the known classes in class_data
%mask_distal    (vec) column vector of bool representing the cp mask for
%                           changepoint-distal regions of the input track
%                           defined by the known classes in class_data
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %init empty proximal mask
    mask_proximal = false(size(class_data));
    
    %find changepoints with diff, and construct mask
    changepoints = find(diff(class_data) ~= 0);
    for idx = changepoints'
        range = max(1, idx - cp_range + 1) : min(length(class_data), idx + cp_range);
        mask_proximal(range) = true;
    end
    
    %invert proximal mask to get the distal mask
    mask_distal = ~mask_proximal;
end


function [accuracy] = computeAccuracy(ground_truth_labels, predicted_labels, track_mask)
%Compute accuracy of annotated tracks, 20/12/2024.
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
%Accuracy metric returned is the proportion of all localisations, in the
%masked regions of the tracks, for which the predictions of the class agree
%with the ground truth, as a fraction of the total number of masked
%localisations.
%
%Input
%-----
%ground_truth_labels    (cell)  cell array where each cell contains a
%                                   vector of ground truth class IDs for a
%                                   track
%predicted_labels       (cell)  cell array where each cell contains a
%                                   vector of predicted class IDs for the
%                                   corresponding track
%track_mask             (cell)  cell array of logical vectors indicating
%                                   which localisations in each track are
%                                   masked for accuracy computation
%
%Output
%------
%accuracy   (float) fraction of correctly predicted localisations in masked
%                       regions across all valid tracks
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %extract non-empty tracks
    valid_tracks = cellfun(@(x) ~isempty(x), ground_truth_labels);
    
    %consider only masked regions of tracks
    ground_truth_labels = ground_truth_labels(valid_tracks);
    predicted_labels    = predicted_labels(valid_tracks);
    track_mask          = track_mask(valid_tracks);
    
    %error handling
    if isempty(ground_truth_labels) || isempty(predicted_labels)
        accuracy = NaN;
        return;
    end
    
    %compute accuracy based on masked regions
    total_correct = 0;
    total_count   = 0;
    for jj = 1:numel(ground_truth_labels)
        masked_indices = track_mask{jj};
        total_correct = total_correct + sum(ground_truth_labels{jj}(masked_indices) == predicted_labels{jj}(masked_indices));
        total_count = total_count + sum(masked_indices);
    end
    accuracy = total_correct / total_count;
end