function [MI_scores] = computeMIScoresFeatureVsClass(feature_data, class_data, feature_list, column_titles, N_bins)
%Compute mutual information scores between features and classes, Oliver
%Pambos, 12/12/2024.
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
%
%Inputs
%------
%feature_data   (mat)   concatenated NxM matrix of all data in dataset,
%                           where N is the number of localisations, and M
%                           is the number of features (including those not
%                           used)
%class_data     (vec)   column vector with N entries, holds the known class
%                           for each entry in feature_data
%feature_list   (cell)  cell array of char arrays, where each cell contains
%                           the name of a feature selected by the user
%column_titles  (cell)  cell array of char arrays, containing the column
%                           titles for all features in dataset; used for
%                           lookup of column number
%N_bins         (int)   number of bins to use in discretising features
%
%Output
%------
%MI_scores      (vec)   vector containing mutual information between the
%                           known classes and the features in feature_list
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findColumnIdx()
%calcMutualInfoFeatureVsClass() - local to this .m file
    
    %pre-allocate
    MI_scores = zeros(1, numel(feature_list));
    
    %loop over features, computing MI scores
    for ii = 1:numel(feature_list)
        %obtain data for feature
        feature_idx         = findColumnIdx(column_titles, feature_list{ii});
        curr_feature_data   = feature_data(:, feature_idx);
        
        %compute MI between the feature and the class labels
        MI_scores(ii) = calcMutualInfoFeatureVsClass(curr_feature_data, class_data, N_bins);
    end
end


function [MI] = calcMutualInfoFeatureVsClass(feature_data, class_data, N_bins)
%Compute mutual information between a feature and the known class labels,
%Oliver Pambos, 12/12/2024.
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
%MI is calculate by constructing joint_prob, a 2D matrix in which each row
%is a bin in the binned feature data, and each column is a class.
%
%Note that in the case of computing a subset of features, the feature list
%and associated feature_data matrix have already been cropped to include
%only these features.
%
%Inputs
%------
%feature_data   (mat)   concatenated NxM matrix of the subset of M features
%                           to be computed; N is number of localisations;
%                           this matrix is concatenated from all tracks
%class_data     (vec)   column vector with N entries, holds the known class
%                           for each entry in feature_data
%N_bins         (int)   number of bins to use in discretising features
%
%Output
%------
%MI_scores      (vec)   vector containing mutual information between the
%                           known classes and the features supplied as
%                           columns in feature_data
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %bin feature data
    bin_edges           = unique(quantile(feature_data, linspace(0, 1, N_bins + 1)));
    discrete_feature    = discretize(feature_data, bin_edges);
    
    %compute joint and marginal probabilities - see notes in header
    joint_prob      = histcounts2(discrete_feature, class_data, (1:N_bins + 1) - 0.5, (min(class_data):max(class_data) + 1) - 0.5, 'Normalization', 'probability');
    prob_feature    = sum(joint_prob, 2);
    prob_class      = sum(joint_prob, 1);
    
    %compute mutual information
    MI = 0;
    for ii = 1:N_bins
        for jj = 1:numel(prob_class)
            if joint_prob(ii, jj) > 0
                MI = MI + joint_prob(ii, jj) * log2(joint_prob(ii, jj) / (prob_feature(ii) * prob_class(jj)));
            end
        end
    end
end