function [accuracy, recall, f1_score] = compareLabels(app)
%Compare labels between a human-labelled dataset and the same dataset
%labelled with an ML model, Oliver Pambos, 10/01/2024.
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
%Note that this function is currently hardcoded only for use with the GRU
%model as this model type is currently in active development. This function
%will be later updated to handle all model types.
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
    
    N_GRU   = length(app.movie_data.results.GRULabelled.LabelledMols);
    N_human = length(app.movie_data.results.VisuallyLabelled.LabelledMols);
    
    %loop through GRU labelled molecules
    for ii = 1:N_GRU
        gru_mol     = app.movie_data.results.GRULabelled.LabelledMols{ii, 1};
        gru_cell_id = gru_mol.CellID;
        gru_mol_id  = gru_mol.MolID;
        gru_labels  = gru_mol.Mol(:, end);
        
        %search for matching human-generated label
        for jj = 1:N_human
            human_mol = app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1};
            if gru_cell_id == human_mol.CellID && gru_mol_id == human_mol.MolID
                human_labels = human_mol.Mol(:, end);
                
                %ensure the labels are of the same length
                N_labels = min(length(gru_labels), length(human_labels));
                
                %compare labels
                for kk = 1:N_labels
                    if gru_labels(kk) == human_labels(kk)
                        if gru_labels(kk) == 1
                            true_positives = true_positives + 1;
                        else
                            true_negatives = true_negatives + 1;
                        end
                    else
                        if gru_labels(kk) == 1
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
    accuracy = (true_positives + true_negatives) / (true_positives + true_negatives + false_positives + false_negatives);
    recall = true_positives / (true_positives + false_negatives);
    precision = true_positives / (true_positives + false_positives);
    f1_score = 2 * (precision * recall) / (precision + recall);

    app.textout.Value = "Accuracy = " + num2str(accuracy) + newline + "Recall = " + num2str(recall) + newline + "F1 score = " + f1_score;
    
    %create confusion matrix
    confusion_matrix = [true_negatives, false_positives; false_negatives, true_positives];
    confusionchart(confusion_matrix);
end
