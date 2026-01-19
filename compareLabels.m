function [accuracy, precision, recall, f1_score] = compareLabels(app)
%Compare labels between a human-labelled dataset and the same dataset
%labelled with an ML model, Oliver Pambos, 10/01/2024.
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
%Input
%-----
%data       (mat)   NxM matrix containing N examples, and M-1 features
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %initialize counters
    true_positives  = 0;
    false_positives = 0;
    false_negatives = 0;
    true_negatives  = 0;
    
    %copy the data to a new local cell array - performance can be improved
    %for certain dataset sizes by instead placing the switch statement
    %around ML_mol inside main loop - placed here for clarity
    switch app.movie_data.models.current_model
        case "LSTM"
            ML_labelled = app.movie_data.results.LSTMLabelled.LabelledMols;
        case "GRU"
            ML_labelled = app.movie_data.results.GRULabelled.LabelledMols;
        case "BiLSTM"
            ML_labelled = app.movie_data.results.BiLSTMLabelled.LabelledMols;
        case "BiGRU"
            ML_labelled = app.movie_data.results.BiGRULabelled.LabelledMols;
        otherwise
            app.textout.Value = "Performance metrics could not be performed as model was not recognised.";
            return;
    end
    
    N_ML    = length(ML_labelled);
    N_human = length(app.movie_data.results.VisuallyLabelled.LabelledMols);
    
    %loop through ML labelled molecules
    for ii = 1:N_ML
        ML_mol     = ML_labelled{ii, 1};
        ML_cell_id = ML_mol.CellID;
        ML_mol_id  = ML_mol.MolID;
        ML_labels  = ML_mol.Mol(:, end);
        
        %search for matching human-generated label
        for jj = 1:N_human
            human_mol = app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1};
            if ML_cell_id == human_mol.CellID && ML_mol_id == human_mol.MolID
                human_labels = human_mol.Mol(:, end);
                
                %ensure the labels are of the same length
                N_labels = min(length(ML_labels), length(human_labels));
                
                %compare labels
                for kk = 1:N_labels
                    if ML_labels(kk) == human_labels(kk)
                        if ML_labels(kk) == 1
                            true_positives = true_positives + 1;
                        else
                            true_negatives = true_negatives + 1;
                        end
                    else
                        if ML_labels(kk) == 1
                            false_positives = false_positives + 1;
                        else
                            false_negatives = false_negatives + 1;
                        end
                    end
                end
                
                break; %found the matching human label
            end
        end
    end
    
    %calculate metrics
    accuracy    = (true_positives + true_negatives) / (true_positives + true_negatives + false_positives + false_negatives);
    recall      = true_positives / (true_positives + false_negatives);
    precision   = true_positives / (true_positives + false_positives);
    f1_score    = 2 * (precision * recall) / (precision + recall);

    app.textout.Value = "Accuracy = " + num2str(accuracy) + newline + "Precision = " + num2str(precision) + newline + "Recall = " + num2str(recall) + newline + "F1 score = " + f1_score;
    
    %create confusion matrix
    confusion_matrix = [true_negatives, false_positives; false_negatives, true_positives];
    confusionchart(confusion_matrix, 'FontSize', 18);
end