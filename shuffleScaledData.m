function [] = shuffleScaledData(app)
%Shuffle the feature-scaled data, Oliver Pambos, 28/04/2023.
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
%Shuffles the feature-scaled data prior to splitting the training data into
%training, validation, and test sets. This approach varies depending upon
%the type of model that this will be used to train. For ensemble decision
%trees where individual steps are considered as independent examples the
%trajectories are concatenated into a single matrix prior to shuffling and
%splitting; this is possible becauase the temporal information is encoded
%in new features; this method is the localisation-wise shuffling.
%For all other models the temporal information in each molecular trajectory
%is handled natively by the model, and shuffling is performed
%molecule-by-molecule.
%
%Note that the option to knock out zeros was used earlier in development,
%and is now redundant, to be removed in a future version.
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
%compileLabelledData()
%splitData()
    
    %get the user-selected method for feature scaling used to train model, and record in model params
    method = app.ShufflingmethodDropDown.Value;
    app.movie_data.models.temp_params.shuffling = method;
    
    switch method
        case "Localisation"
            %shuffle data localisation-wise; this is used for training ensemble decision trees
            
            %pre-allocation required in future version
            concat_data = [];
            
            %loop over all molecules in file
            for ii = 1:size(app.movie_data.results.FeatureScaledData.LabelledMols, 1)
                
                %concatenate all molecules that have a classification label for every localisation
                if ~any(app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:,end) == -1)
                    mol = app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol;
                    concat_data = cat(1, concat_data, mol);
                end
                
            end
            
            %if user requests, remove any rows with zeros in any of the feature columns; this now redundant, and will be removed in a future version
            if app.KnockoutzerosCheckBox.Value
                rows_to_remove = any(concat_data(:, 1:end-1) == 0, 2);
                concat_data(rows_to_remove, :) = [];
                app.movie_data.models.temp_params.knocked_out = 0;  %keep track of values knocked out of dataset
            end
            
            %perform shuffle
            N_examples      = size(concat_data, 1);
            permuted_idx    = randperm(N_examples);
            app.movie_data.results.labelled_data = concat_data(permuted_idx, :);
            
        case "Molecule"
            %shuffle data molecule-by-molecule; this is used to train more complex models such as neural nets that natively handle temporal dependencies
            
            N_mol = size(app.movie_data.results.FeatureScaledData.LabelledMols, 1); 
            
            %shuffle
            random_order = randperm(N_mol); 
            shuffled_matrices = cell(N_mol, 1); 
            
            %loop through matrices, reorder, then overwrite original mols with shuffled mols
            for ii = 1:N_mol
                shuffled_matrices{ii, 1} = app.movie_data.results.FeatureScaledData.LabelledMols{random_order(ii), 1};
            
            end
            app.movie_data.results.FeatureScaledData.LabelledMols = shuffled_matrices;
            
        otherwise
            
    end
end