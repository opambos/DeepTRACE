function [] = cropTrajectories(app, dataset, ignore_start, ignore_end)
%Crop trajectories to ensure only valid data from all selected features is
%retained, Oliver Pambos, 13/01/2024.
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
%There are many known features that may not be available at the start or
%end of a trajectory. For example, the feature 'step size' represents the
%Euclidean distance between localisations and therefore contains no
%information encoded in the first frame; the first row of every trajectory
%is therefore ignored from both the training and later classified data.
%Similarly, the feature 'following step size' will have an empty entry at
%the end of the trajectory. Inluding these features would severely
%complicate training. I have previously attemped other approaches to this
%problem, including imputation. This function however simply crops these
%regions from the dataset althogether.
%
%These rows which interfere with the ML model are identified earlier in the
%analysis procedure during a call to identifyExcludedSteps, and are
%optionally overridden by the user. These identified rows are removed by
%this function immediately prior to training. This function also stores in
%the models.temp_params substruct a two-element row vector which records
%the number of rows cropped from the start and end of the trajectories
%during training. This information is written to the ML temp_params struct
%to be subsequently stored with the trained model when saving to file.
%
%Input
%-----
%app            (handle)    main GUI handle
%removed_rows   (vec)       row vector containing which rows to remove
%dataset        (str)       which dataset to crop
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    switch dataset
        case "feature_scaled"
            %remove the relevant rows
            for ii = 1:numel(app.movie_data.results.FeatureScaledData.LabelledMols)
                app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol = app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(ignore_start+1 : end-ignore_end, :);
            end
            
        case "GRU_labelled"
            %remove the relevant rows
            for ii = 1:numel(app.movie_data.results.GRULabelled.LabelledMols)
                app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol = app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(ignore_start+1 : end-ignore_end, :);
            end
            
        case "LSTM_labelled"
            %remove the relevant rows
            for ii = 1:numel(app.movie_data.results.LSTMLabelled.LabelledMols)
                app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol = app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(ignore_start+1 : end-ignore_end, :);
            end
            
        case "BiGRU_labelled"
            %remove the relevant rows
            for ii = 1:numel(app.movie_data.results.BiGRULabelled.LabelledMols)
                app.movie_data.results.BiGRULabelled.LabelledMols{ii, 1}.Mol = app.movie_data.results.BiGRULabelled.LabelledMols{ii, 1}.Mol(ignore_start+1 : end-ignore_end, :);
            end
            
        case "BiLSTM_labelled"
            %remove the relevant rows
            for ii = 1:numel(app.movie_data.results.BiLSTMLabelled.LabelledMols)
                app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol = app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(ignore_start+1 : end-ignore_end, :);
            end
            
        otherwise
            
    end
    
    %keep a record of this operation with the trained model
    app.movie_data.models.temp_params.removed_rows = [ignore_start ignore_end];
end