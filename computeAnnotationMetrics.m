function [] = computeAnnotationMetrics(app, structs_to_use)
%Computes the metrics for annotations, Oliver Pambos, 17/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeAnnotationMetrics
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
%This function computes the class, and the macro-averaged metrics for,
%   accuracy
%   precision
%   recall
%   f1 score
%
%The current implementation of this function treats the human annotations
%as the ground truth. A future version will replace this with a pop-up
%which will prompt the user to select which dataset to use as ground truth,
%as this flexibility was available in earlier external code. This will also
%require later modification to enable comparison between annotations of the
%same model type in different files as was previously capable with external
%analysis code. This is necessary as current implementation only enables
%one annotation source for each model type (the results struct only
%contains one BiLSTM annotation, one GRU model annotation, etc.).
%
%This function has been generalised to replace compareLabels.m when called
%from the ClassifywithmodelButtonPushed callback to prevent repetition in
%the code, and also to produce clearer display and macro-averaged metrics
%for arbitrary number of classes. This necessitates the optional input
%structs_to_use, which skips the checking of user input checkbox selection
%in this scenario.
%
%The call to cropTracjectories() in labelWithSlidingWindow.m is currently
%disabled pending a future update of this function, which correctly aligns
%the cropped trajectories with the ground truth reference labels. This
%offset occurs when tracks are cropped due to the engineered features used
%(e.g. it is not possible to annotate the first loc if step size is a
%feature as there is no information of the step size from the previous
%frame). This update will not rely on the stored row vector 'removed_rows',
%but rather perform direct comparison to frame numbers. This may introduce
%complexity as this function computes metrics for the annotations from
%multiple sources in the same function call, and each set of annotations
%may contain different removed rows based on the engineered features used.
%
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findCommonAnnotatedTracks()
%findCommonTracks()
    
    %use a map between user selectable text and actual struct names
    annotation_map = containers.Map(...
    {'Ground truth annotations', 'Human annotations', 'LSTM annotations', 'Bidirectional LSTM annotations', 'Random forest annotations', 'GRU annotations', 'Bidirectional GRU annotations'}, ...
    {'GroundTruth',              'VisuallyLabelled',  'LSTMLabelled',     'BiLSTMLabelled',                 'RFLabelled',                'GRULabelled',     'BiGRULabelled'});
    
    %if f'n called from [Compute metrics] tab, work out which annotation sets to use from GUI checkbox tree; otherwise rely on structs_to_use input
    if nargin < 2
        selected_nodes = app.CompareAnnotationsTree.CheckedNodes;
        selected_annotations = {selected_nodes.Text};
        
        %check data exists for all selected annotations
        structs_to_use = {};
        available_annotations = fieldnames(app.movie_data.results);
        for ii = 1:size(selected_annotations,2)
            struct_name = annotation_map(selected_annotations{ii});
            if ~ismember(struct_name, available_annotations)
                app.textout.Value = sprintf("Annotation dataset %s does not exist", selected_annotations{ii});
                return;
            else
                structs_to_use = cat(1, structs_to_use, struct_name);
            end
        end
    end
    
    %extract labels
    all_labels = struct();
    for ii = 1:size(structs_to_use, 1)
        LabelledMols = app.movie_data.results.(string(structs_to_use(ii))).LabelledMols;
        N = numel(LabelledMols);
        labels = cell(N, 1);
        for jj = 1:N
            mol = LabelledMols{jj}.Mol;
            labels{jj} = struct('CellID', LabelledMols{jj}.CellID, ...
                               'MolID', LabelledMols{jj}.MolID, ...
                               'Labels', mol(:, end));
        end
        all_labels.(string(structs_to_use(ii))) = labels;
    end
    
    %find common tracks among all selected annotations
    annotation_fields = fieldnames(all_labels);
    if isscalar(annotation_fields)
        common_tracks = cell2mat(cellfun(@(x) [x.CellID, x.MolID], all_labels.(annotation_fields{1}), 'UniformOutput', false));
    else
        common_tracks = findCommonAnnotatedTracks(all_labels, annotation_fields);
    end
    
    if isempty(common_tracks)
        disp('No common tracks found.');
        return;
    end
    
    %find indices for each common track in each annotation dataset & write
    %this to the common_tracks matrix
    for ii = 1:size(common_tracks, 1)
        cell_id = common_tracks(ii, 1);
        mol_id  = common_tracks(ii, 2);
        
        %loop through each annotation dataset
        for jj = 1:numel(annotation_fields)
            %extract CellIDs and MolIDs
            cell_ids = cellfun(@(x) x.CellID, all_labels.(annotation_fields{jj}));
            mol_ids = cellfun(@(x) x.MolID, all_labels.(annotation_fields{jj}));
            
            %find the index of the track in the current annotation dataset, and record it
            common_tracks(ii, jj + 2) = find(cell_ids == cell_id & mol_ids == mol_id, 1);
        end
    end
    
    N_classes = numel(app.movie_data.params.class_names);
    conf_matrix = zeros(N_classes);
    
    %loop through each common track
    for ii = 1:size(common_tracks, 1)
        %find corresponding ground truth labels
        gt_labels = all_labels.(annotation_fields{1}){common_tracks(ii,3), 1}.Labels;
        
        %loop over other annotation sources requested by user (each of these are another column in the common_tracks matrix)
        for jj = 4:size(common_tracks, 2) %start from 4 because 1, 2, 3 are cell_id, mol_id, and ground_truth_idx
            pred_labels = all_labels.(annotation_fields{jj-2}){common_tracks(ii,jj), 1}.Labels;
            
            %error checking incase user has run classification before importing ground truth this can lead to -1 not being removed from the original numeric matrix
            %this check will be later removed after adding direct frame number comparisons; this also handles issues from the localisation algorithm picking up additional false localisations in a frame containing a genuine molecule
            if size(gt_labels, 1) ~= size(pred_labels, 1)
                continue;
            end
            
            % << a future update will place here a comparison between frame numbers when tracks have been truncated >>
            % << to ensure that each label is compared only to its corresponding frame in the ground truth dataset >>

            %populate confusion matrix
            for kk = 1:size(gt_labels,1)
                actual_class = gt_labels(kk,1);
                predicted_class = pred_labels(kk,1);
                conf_matrix(actual_class, predicted_class) = conf_matrix(actual_class, predicted_class) + 1;
            end
        end
    end
    
    %plot the confusion matrix
    figure;
    confusionchart(conf_matrix, 'FontSize', 18);
    xlabel('Predicted Class');
    ylabel('Actual Class');
    
    %calc metrics for each class
    [accuracy, precision, recall, f1_score] = deal(zeros(N_classes, 1));
    
    for ii = 1:N_classes
        TP = conf_matrix(ii, ii);
        FP = sum(conf_matrix(:, ii)) - TP;
        FN = sum(conf_matrix(ii, :)) - TP;
        TN = sum(conf_matrix(:)) - (TP + FP + FN);
        
        accuracy(ii)    = (TP + TN) / (TP + FP + FN + TN);
        precision(ii)   = TP / (TP + FP);
        recall(ii)      = TP / (TP + FN);
        f1_score(ii)    = 2 * (precision(ii) * recall(ii)) / (precision(ii) + recall(ii));
    end
    
    %handle NaN values (if class has no positive instances)
    [accuracy(isnan(accuracy)), precision(isnan(precision)), recall(isnan(recall)), f1_score(isnan(f1_score))] = deal(0);
    
    %calculate macro-averaged metrics
    macro_precision = mean(precision);
    macro_recall    = mean(recall);
    macro_f1        = mean(f1_score);
    macro_accuracy  = mean(accuracy);
    
    %display metrics
    conf_matrix_text = sprintf('Confusion Matrix:\n');
    for i = 1:size(conf_matrix, 1)
        conf_matrix_text = [conf_matrix_text, sprintf('%10d', conf_matrix(i, :)), newline];
    end
    
    output_text = sprintf('%s\nClass-wise Metrics:\n', conf_matrix_text);
    for ii = 1:N_classes
        output_text = sprintf('%sClass %d - Accuracy: %.4f, Precision: %.4f, Recall: %.4f, F1 Score: %.4f\n', output_text, ii, accuracy(ii), precision(ii), recall(ii), f1_score(ii));
    end
    
    output_text = sprintf('%s\nMacro-averaged metrics:\nAccuracy: %.4f\nPrecision: %.4f\nRecall: %.4f\nF1 Score: %.4f\n', output_text, macro_accuracy, macro_precision, macro_recall, macro_f1);
    
    app.textout.Value = output_text;
    
    %display metrics also in pop-up window
    msgbox(output_text, 'Macro-Averaged Metrics', 'modal');
end