function [accuracy, mean_precision, mean_recall, mean_f1_score, confusion_mat] = computeMetricsPadded(model, data, labels, show_plot)
%Compute the metrics for padded datasets, and generate confusion matrix,
%03/02/2024.
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
%Generates metrics (accuracy, precision, recall, and f1 score) for all
%classes, and returns accuracy, and the mean value for precision, recall,
%and f1 score. The function also generates in a new figure window a visual
%confusion matrix showing predicted vs true class.
%
%Note that this function operates on the cell array style of test data that
%is used by this system for NN-based models (i.e. not the type used for
%ensemble decision trees in which operate on a single numeric matrix). This
%function is a replica of computeMetrics() adjusted for datasets which
%contain padded trajectories which is used in the case of full trajectory
%sequence-to-sequence classification; future versions may merge these into
%a single function.
%
%Input
%-----
%model  (mdl)   model used for classification
%data   (cell)  cell array of test data; each cell contains an NxM numeric
%                   matrix containing N features and M frames; this input
%                   data contains padding with zeros
%labels (cell)  cell array of test data annotations (labels); each cell
%                   contains a row vector of the same width as matrices
%                   held in `data`
%
%Output
%------
%accuracy       (float) overall accuracy across all classes
%mean_precision (float) mean precision across all classes
%mean_recall    (float) mean recall across all classes
%mean_f1_score  (float) mean f1 score across all classes
%confusion_mat  (mat)   confusion matrix of predicted vs true classes
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    %obtain number of possible classes (not just those present in the dataset)
    all_classes     = categories([labels{:}]);
    N_classes       = length(all_classes);
    confusion_mat   = zeros(N_classes, N_classes);

    %number of non-padded observations
    N_nonpadded = 0;

    %loop over all data trajectories
    for ii = 1:numel(data)
        %predict labels
        predicted_labels = classify(model, data{ii});
        actual_labels    = labels{ii};

        %identify non-padded rows
        nonpadded_idx = data{ii}(end, :) == 1;

        %update confusion matrix for non-padded points
        for jj = 1:length(predicted_labels)
            %only consider non-padded data
            if nonpadded_idx(jj)
                actual_class_idx    = find(all_classes == string(actual_labels(jj)));
                predicted_class_idx = find(all_classes == string(predicted_labels(jj)));
                confusion_mat(actual_class_idx, predicted_class_idx) = confusion_mat(actual_class_idx, predicted_class_idx) + 1;
                N_nonpadded = N_nonpadded + 1;
            end
        end
    end
    
    %remove the padding class
    confusion_mat   = confusion_mat(2:end, 2:end);
    N_classes       = N_classes - 1;
    all_classes     = all_classes(2:end);
    
    %store metrics for each class
    precision   = zeros(N_classes, 1);
    recall      = zeros(N_classes, 1);
    f1_score    = zeros(N_classes, 1);

    %loop over classes, compiling metrics
    for ii = 1:N_classes
        tp = confusion_mat(ii, ii);
        fp = sum(confusion_mat(:, ii)) - tp;
        fn = sum(confusion_mat(ii, :)) - tp;
        
        precision(ii)   = tp / (tp + fp);
        recall(ii)      = tp / (tp + fn);
        f1_score(ii)    = 2 * (precision(ii) * recall(ii)) / (precision(ii) + recall(ii));

        %handle division by zero
        if isnan(precision(ii))
            precision(ii) = 0;
        end
        if isnan(recall(ii))
            recall(ii) = 0;
        end
        if isnan(f1_score(ii))
            f1_score(ii) = 0;
        end
    end

    %calculate mean metrics
    mean_precision  = mean(precision, 'omitnan');
    mean_recall     = mean(recall, 'omitnan');
    mean_f1_score   = mean(f1_score, 'omitnan');

    %calculate overall accuracy
    accuracy = sum(diag(confusion_mat)) / N_nonpadded;
    
    if show_plot
        %generate visual confusion matrix
        confusion_chart = confusionchart(confusion_mat, all_classes, 'FontSize', 18);
        confusion_chart.Title = 'Confusion Matrix';
    end
end