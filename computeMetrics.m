function [accuracy, mean_precision, mean_recall, mean_f1_score, confusion_mat] = computeMetrics(model, data, labels)
%Compute the metrics, and generate confusion matrix, Oliver Pambos,
%03/02/2024.
%%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeMetrics
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
%Generates metrics (accuracy, precision, recall, and f1 score) for all
%classes, and returns accuracy, and the mean value for precision, recall,
%and f1 score. The function also generates in a new figure window a visual
%confusion matrix showing predicted vs true class.
%
%Note that this function operates on the cell array style of test data that
%is used by this system for NN-based models (i.e. not the type used for
%ensemble decision trees in which operate on a single numeric matrix).
%
%Input
%-----
%model  (mdl)   model used for classification
%data   (cell)  cell array of test data; each cell contains an NxM numeric
%                   matrix containing N features and M frames
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
    
    %loop over all spans
    for ii = 1:numel(data)
        %predict labels
        predicted_labels = classify(model, data{ii});
        actual_labels    = labels{ii};
        
        %update confusion matrix
        for jj = 1:length(predicted_labels)
            actual_class_idx    = find(all_classes == string(actual_labels(jj)));
            predicted_class_idx = find(all_classes == string(predicted_labels(jj)));
            confusion_mat(actual_class_idx, predicted_class_idx) = confusion_mat(actual_class_idx, predicted_class_idx) + 1;
        end
    end

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
    accuracy = sum(diag(confusion_mat)) / sum(confusion_mat(:));
    
    %generate visual confusion matrix
    confusion_chart = confusionchart(confusion_mat, all_classes, 'FontSize', 18);
    confusion_chart.Title = 'Confusion Matrix';
    %confusion_chart.RowSummary = 'row-normalized';
    %confusion_chart.ColumnSummary = 'column-normalized';
end
