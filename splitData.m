function [] = splitData(app)
%Shuffles and splits labelled data into training, validation, and test
%datasets with user-defined ratios, Oliver Pambos, 19/04/2023.
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
%This function takes user-definite splitting of training, validation, and
%test dataset, and splits accordingly the human-labelled data currently
%loaded. Note that this processes is performed differently depending upon
%whether the data is to be shuffled at the localisation (used for ensembled
%decision tree models which handle temporal information through feature
%engineering) or molecule level (required for sequence-to-sequence
%classification with neural networks which can handle temporal information
%directly).
%
%Note that many of the operations used to reformat the data for use with
%NNs are unneccesary, and are the result of testing different data
%structures during development; a more streamlined version of this function
%will appear in a future version.
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
%invertScalingTransform() - local to this .m file
    
    ratio_train = app.movie_data.models.temp_params.data_split(1);
    ratio_val   = app.movie_data.models.temp_params.data_split(2);
    
    %handle user error for percentages
    if ratio_train + ratio_val > 1 || ratio_train < 0 || ratio_val < 0
        disp('Error: invalid ratio used in splitData().')
        return;
    end
    
    switch app.movie_data.models.temp_params.shuffling
        case "Localisation"
            %calculate the number of examples for each set
            N_examples  = size(app.movie_data.results.labelled_data, 1);
            N_train     = round(N_examples * ratio_train);
            N_val       = round(N_examples * ratio_val);
            
            %split the data using the categorised indices
            app.movie_data.results.train_data   = app.movie_data.results.labelled_data(1:N_train, :);
            app.movie_data.results.val_data     = app.movie_data.results.labelled_data(N_train+1:N_train+N_val, :);
            app.movie_data.results.test_data    = app.movie_data.results.labelled_data(N_train+N_val+1:end, :);
            
            %copy to reference data for plotting
            app.movie_data.results.ref_labelled_data    = app.movie_data.results.labelled_data;
            app.movie_data.results.ref_train_data       = app.movie_data.results.train_data;
            app.movie_data.results.ref_val_data         = app.movie_data.results.val_data;
            app.movie_data.results.ref_test_data        = app.movie_data.results.test_data;
            
            %rescale the reference data to produce original features (apply inverse transform of feature scaling)
            invertScalingTransform(app);
            
        case "Molecule"
            N_mol = size(app.movie_data.results.FeatureScaledData.LabelledMols, 1);
            
            %calculate the number of mols for each set
            N_train = round(N_mol * ratio_train);
            N_val   = round(N_mol * ratio_val);
            
            %split data into training, validation, and test sets
            app.movie_data.results.train_data   = app.movie_data.results.FeatureScaledData.LabelledMols(1:N_train, 1);
            app.movie_data.results.val_data     = app.movie_data.results.FeatureScaledData.LabelledMols(N_train+1:N_train+N_val, 1);
            app.movie_data.results.test_data    = app.movie_data.results.FeatureScaledData.LabelledMols(N_train+N_val+1:end, 1);
            
            %keep a copy of all cell_ID and mol_IDs of molecules in the test set
            app.movie_data.models.temp_params.test_mols = zeros(size(app.movie_data.results.test_data, 1), 2);
            for ii = 1:size(app.movie_data.results.test_data, 1)
                app.movie_data.models.temp_params.test_mols(ii, 1) = app.movie_data.results.test_data{ii, 1}.CellID;
                app.movie_data.models.temp_params.test_mols(ii, 2) = app.movie_data.results.test_data{ii, 1}.MolID;
                app.movie_data.models.temp_params.test_mols(ii, 3) = app.movie_data.results.test_data{ii, 1}.source_data;
            end
            
            %concatenate all data types to produce reference datasets for fast plotting; note that these reference datasets retain all
            %of the original information, while the data used for training, validation, etc. is reformatted for use in model training
            app.movie_data.results.ref_labelled_data = [];
            for ii = 1:size(app.movie_data.results.FeatureScaledData.LabelledMols,1)
                app.movie_data.results.ref_labelled_data = vertcat(app.movie_data.results.ref_labelled_data, app.movie_data.results.FeatureScaledData.LabelledMols{ii}.Mol);
            end
            app.movie_data.results.ref_train_data = [];
            for ii = 1:size(app.movie_data.results.train_data,1)
                app.movie_data.results.ref_train_data = vertcat(app.movie_data.results.ref_train_data, app.movie_data.results.train_data{ii}.Mol);
            end
            app.movie_data.results.ref_val_data = [];
            for ii = 1:size(app.movie_data.results.val_data,1)
                app.movie_data.results.ref_val_data = vertcat(app.movie_data.results.ref_val_data, app.movie_data.results.val_data{ii}.Mol);
            end
            app.movie_data.results.ref_test_data = [];
            for ii = 1:size(app.movie_data.results.test_data,1)
                app.movie_data.results.ref_test_data = vertcat(app.movie_data.results.ref_test_data, app.movie_data.results.test_data{ii}.Mol);
            end
            
            %rescale the reference data to produce original features (apply inverse transform of feature scaling)
            invertScalingTransform(app);
            
            %------------------------------------------------------------
            %Reformat training data for use with NNs
            %This process is the result of testing different data
            %structures during development, and will be streamlined in a
            %future version
            %-----------------------------------------------------------
            N_features = size(app.movie_data.results.train_data{1}.Mol, 2) - 1;
            
            %calculate max rows for each data set (lengths of trajectories)
            max_rows_train  = max(cellfun(@(x) size(x.Mol, 1), app.movie_data.results.train_data));
            max_rows_val    = max(cellfun(@(x) size(x.Mol, 1), app.movie_data.results.val_data));
            max_rows_test   = max(cellfun(@(x) size(x.Mol, 1), app.movie_data.results.test_data));
            max_rows = max([max_rows_train; max_rows_val; max_rows_test]);
            
            %preallocate 3D matrices with zeros
            train_data_temp = zeros(max_rows, N_features + 2, size(app.movie_data.results.train_data, 1));
            val_data_temp   = zeros(max_rows, N_features + 2, size(app.movie_data.results.val_data, 1));
            test_data_temp  = zeros(max_rows, N_features + 2, size(app.movie_data.results.test_data, 1));
            
            %copy only selected features columns of training, validation, and test data into 3D matrices, concatenate with column containing
            %binary mask of padding (data-containing rows are 1s, padding are 0s), and finally concatenate with visual labels
            for ii = 1:size(app.movie_data.results.train_data, 1)
                mol = app.movie_data.results.train_data{ii}.Mol;
                mol = [mol(:, 1:N_features), ones(size(mol, 1), 1), mol(:, end)];
                train_data_temp(1:size(mol, 1), :, ii) = mol;
            end
            for ii = 1:size(app.movie_data.results.val_data, 1)
                mol = app.movie_data.results.val_data{ii}.Mol;
                mol = [mol(:, 1:N_features), ones(size(mol, 1), 1), mol(:, end)];
                val_data_temp(1:size(mol, 1), :, ii) = mol;
            end
            for ii = 1:size(app.movie_data.results.test_data, 1)
                mol = app.movie_data.results.test_data{ii}.Mol;
                mol = [mol(:, 1:N_features), ones(size(mol, 1), 1), mol(:, end)];
                test_data_temp(1:size(mol, 1), :, ii) = mol;
            end
            
            %overwrite the original data with the 3D matrices
            app.movie_data.results.train_data   = train_data_temp;
            app.movie_data.results.val_data     = val_data_temp;
            app.movie_data.results.test_data    = test_data_temp;
            
            %transpose datasets new format is [features, time, mols]
            app.movie_data.results.train_data   = permute(app.movie_data.results.train_data, [2, 1, 3]);
            app.movie_data.results.val_data     = permute(app.movie_data.results.val_data, [2, 1, 3]);
            app.movie_data.results.test_data    = permute(app.movie_data.results.test_data, [2, 1, 3]);
            
            %separate labels from the data
            app.movie_data.results.train_labels = categorical(squeeze(app.movie_data.results.train_data(end, :, :)));
            app.movie_data.results.train_data(end, :, :) = [];
            
            app.movie_data.results.val_labels = categorical(squeeze(app.movie_data.results.val_data(end, :, :)));
            app.movie_data.results.val_data(end, :, :) = [];
            
            app.movie_data.results.test_labels = categorical(squeeze(app.movie_data.results.test_data(end, :, :)));
            app.movie_data.results.test_data(end, :, :) = [];
            
            %reformat labels to be a cell array of categorical row vectors for each dataset
            app.movie_data.results.train_labels = arrayfun(@(n) app.movie_data.results.train_labels(:,n)', 1:size(app.movie_data.results.train_labels, 2), 'UniformOutput', false);
            app.movie_data.results.val_labels   = arrayfun(@(n) app.movie_data.results.val_labels(:,n)', 1:size(app.movie_data.results.val_labels, 2), 'UniformOutput', false);
            app.movie_data.results.test_labels  = arrayfun(@(n) app.movie_data.results.test_labels(:,n)', 1:size(app.movie_data.results.test_labels, 2), 'UniformOutput', false);
            
            %reformat each dataset to be a cell array of sequences
            app.movie_data.results.train_data   = squeeze(num2cell(app.movie_data.results.train_data, [1 2]));
            app.movie_data.results.val_data     = squeeze(num2cell(app.movie_data.results.val_data, [1 2]));
            app.movie_data.results.test_data    = squeeze(num2cell(app.movie_data.results.test_data, [1 2]));
        otherwise
            
    end
    
end


function [] = invertScalingTransform(app)
%Reverse the scaling transform for feature columns to obtain the original
%data in the reference dataset Oliver Pambos, 28/04/2023.
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
%Reversing the scaling transform of the scaled feature columns is necessary
%to enable efficient plotting of the data inside the GUI.
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
%None
    
    %extract scaling method and feature columns
    method          = app.movie_data.models.temp_params.feature_scaling;
    
    switch method
        case "None"
            %do nothing if no scaling was applied
            
        case "Z-score"
            %reverse Z-score standardisation
            mean_values     = app.movie_data.models.temp_params.feature_means;
            stdev_values    = app.movie_data.models.temp_params.feature_stds;
            
            for ii = 1:size(app.movie_data.results.ref_train_data, 2) - 1
                app.movie_data.results.ref_train_data(:, ii)      = app.movie_data.results.ref_train_data(:, ii) * stdev_values(ii) + mean_values(ii);
                if ~isempty(app.movie_data.results.ref_val_data)
                    app.movie_data.results.ref_val_data(:, ii)    = app.movie_data.results.ref_val_data(:, ii) * stdev_values(ii) + mean_values(ii);
                end
                app.movie_data.results.ref_test_data(:, ii)       = app.movie_data.results.ref_test_data(:, ii) * stdev_values(ii) + mean_values(ii);
                app.movie_data.results.ref_labelled_data(:, ii)   = app.movie_data.results.ref_labelled_data(:, ii) * stdev_values(ii) + mean_values(ii);
            end
            
        case "Normalise (0-1)"
            %reverse min-max normalisation
            min_values = app.movie_data.models.temp_params.feature_mins;
            max_values = app.movie_data.models.temp_params.feature_maxs;
            
            for ii = 1:size(app.movie_data.results.ref_train_data, 2) - 1
                app.movie_data.results.ref_train_data(:, ii)      = (app.movie_data.results.ref_train_data(:, ii) * (max_values(ii) - min_values(ii))) + min_values(ii);
                if ~isempty(app.movie_data.results.ref_val_data)
                    app.movie_data.results.ref_val_data(:, ii)    = (app.movie_data.results.ref_val_data(:, ii) * (max_values(ii) - min_values(ii))) + min_values(ii);
                end
                app.movie_data.results.ref_test_data(:, ii)       = (app.movie_data.results.ref_test_data(:, ii) * (max_values(ii) - min_values(ii))) + min_values(ii);
                app.movie_data.results.ref_labelled_data(:, ii)   = (app.movie_data.results.ref_labelled_data(:, ii) * (max_values(ii) - min_values(ii))) + min_values(ii);
            end
            
        otherwise
            error("Unknown scaling method");
    end
end