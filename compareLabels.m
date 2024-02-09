function [accuracy, precision, recall, f1_score] = compareLabels(app)
%Compare labels between a human-labelled dataset and the same dataset
%labelled with an ML model, Oliver Pambos, 10/01/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: compareLabels
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD, UK
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%LEGAL DISCLAIMER
%THIS CODE IS INTENDED FOR USE ONLY BY INDIVIDUALS WHO HAVE RECEIVED
%EXPLICIT AUTHORIZATION FROM THE AUTHOR, OLIVER JAMES PAMBOS. ANY FORM OF
%COPYING, REDISTRIBUTION, OR UNAUTHORIZED USE OF THIS CODE, IN WHOLE OR IN
%PART, IS PROHIBITED. BY USING THIS CODE, USERS SIGNIFY THAT THEY HAVE
%READ, UNDERSTOOD, AND AGREED TO BE BOUND BY THE TERMS OF SERVICE PRESENTED
%UPON SOFTWARE LAUNCH, INCLUDING THE REQUIREMENT FOR CO-AUTHORSHIP ON ANY
%RELATED PUBLICATIONS. THIS APPLIES TO ALL LEVELS OF USE, INCLUDING PARTIAL
%USE OR MODIFICATION OF THE CODE OR ANY OF ITS EXTERNAL FUNCTIONS.
%
%USERS ARE RESPONSIBLE FOR ENSURING FULL UNDERSTANDING AND COMPLIANCE WITH
%THESE TERMS, INCLUDING OBTAINING AGREEMENT FROM THE APPROPRIATE
%PUBLICATION DECISION-MAKERS WITHIN THEIR ORGANIZATION OR INSTITUTION.
%
%NOTE: UPON PUBLIC RELEASE OF THIS SOFTWARE, THESE TERMS MAY BE SUBJECT TO
%CHANGE. HOWEVER, USERS OF THIS PRE-RELEASE VERSION ARE STILL BOUND BY THE
%CO-AUTHORSHIP AGREEMENT FOR ANY USE MADE PRIOR TO THE PUBLIC RELEASE. THE
%RELEASED VERSION WILL BE AVAILABLE FROM A DESIGNATED ONLINE REPOSITORY
%WITH POTENTIALLY DIFFERENT USAGE CONDITIONS.
%
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
        case "Long Short-Term Memory"
            ML_labelled = app.movie_data.results.LSTMLabelled.LabelledMols;
        case "GRU"
            ML_labelled = app.movie_data.results.GRULabelled.LabelledMols;
        otherwise
            % << exception handling here >>
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
