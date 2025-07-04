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
%   Jaccard index
%
%in addition to changepoint errors.
%
%Metrics/stats are written to the app.movie_data.stats substruct.
%
%The current implementation of this function treats the human annotations
%as the ground truth in the absence of pre-loaded ground truth data. A
%future version will replace this with a pop-up which will prompt the
%user to select which dataset to use as ground truth, as this
%flexibility was available in earlier external code. This will also
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
%This function now accommodates optional track cropping, using GUI inputs
%in the [Compute metrics] sub-tab when computing metrics.
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
%computeCPErrorsSingleTrack()
    
    %use a map between user selectable text and actual struct names
    annotation_map = containers.Map(...
    {'Ground truth annotations', 'Human annotations', 'LSTM annotations', 'Bidirectional LSTM annotations', 'Random forest annotations', 'GRU annotations', 'Bidirectional GRU annotations', 'ResAnDi2 annotations'}, ...
    {'GroundTruth',              'VisuallyLabelled',  'LSTMLabelled',     'BiLSTMLabelled',                 'RFLabelled',                'GRULabelled',     'BiGRULabelled',                 'ResAnDi'});
    
    %define number of frames to ignore from the stats at the start and end of each track
    ignore_start_count  = app.IgnoreframeatstartoftrackSpinner.Value;
    ignore_end_count    = app.IgnoreatendoftrackSpinner.Value;
    min_cp_sep          = app.MinimumchangepointseparationSpinner.Value;
    max_cp_error        = app.MaxchangepointerrorSpinner.Value;
    
    %if f'n called from [Compute metrics] tab, work out which annotation sets to use from GUI checkbox tree; otherwise rely on structs_to_use input
    if nargin < 2
        selected_nodes = app.CompareAnnotationsTree.CheckedNodes;
        if isempty(selected_nodes)
            warndlg("Please select the annotation source and ground truth in the [Plot track annotation] sub-tab of of the Annotation Inspector.", "Cannot compute metrics.");
            return;
        end
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
    
    %initialize cp error list
    all_cp_errors = [];
    all_cp_transitions = [];
    total_unpaired_cps = 0;
    
    %loop through each common track
    for ii = 1:size(common_tracks, 1)
        %find corresponding ground truth labels
        gt_labels = all_labels.(annotation_fields{1}){common_tracks(ii,3), 1}.Labels;
        
        %loop over other annotation sources requested by user (each of these are another column in the common_tracks matrix)
        for jj = 4:size(common_tracks, 2) %start from 4 because 1, 2, 3 are cell_id, mol_id, and ground_truth_idx
            pred_labels = all_labels.(annotation_fields{jj-2}){common_tracks(ii,jj), 1}.Labels;
            
            %apply cropping: ignore user-requested frames from ends of each track
            if length(gt_labels) > (ignore_start_count + ignore_end_count) && length(pred_labels) > (ignore_start_count + ignore_end_count)
                gt_labels_cropped = gt_labels((ignore_start_count + 1):(end - ignore_end_count));
                pred_labels_cropped = pred_labels((ignore_start_count + 1):(end - ignore_end_count));
            else
                %if the track is too short after cropping, skip track, this should never be executed under any normal scenario
                continue;
            end
            
            %error checking incase user has run classification before importing ground truth this can lead to -1 not being removed from the original numeric matrix
            %this check will be later removed after adding direct frame number comparisons; this also handles issues from the localisation algorithm picking up additional false localisations in a frame containing a genuine molecule
            if size(gt_labels, 1) ~= size(pred_labels, 1)
                continue;
            end
            
            % << a future update will place here a comparison between frame numbers when tracks have been truncated >>
            % << to ensure that each label is compared only to its corresponding frame in the ground truth dataset >>
            
            %populate confusion matrix
            for kk = 1:size(gt_labels_cropped, 1)
                actual_class = gt_labels_cropped(kk, 1);
                predicted_class = pred_labels_cropped(kk, 1);
                conf_matrix(actual_class, predicted_class) = conf_matrix(actual_class, predicted_class) + 1;
            end
            
            %compute cp errors, and append to the list
            [cp_errors, state_transitions, N_unpaired_cps] = computeCPErrorsSingleTrack(gt_labels_cropped, pred_labels_cropped, max_cp_error, min_cp_sep);
            all_cp_errors = [all_cp_errors; cp_errors];
            all_cp_transitions = [all_cp_transitions; state_transitions];
            total_unpaired_cps = total_unpaired_cps + N_unpaired_cps;
        end
    end
    
    %plot the confusion matrix
    figure;
    confusionchart(conf_matrix, 'FontSize', 18);
    xlabel('Predicted Class');
    ylabel('Actual Class');
    
    %calc metrics for each class
    [accuracy, precision, recall, f1_score, jaccard_index] = deal(zeros(N_classes, 1));
    
    for ii = 1:N_classes
        TP = conf_matrix(ii, ii);
        FP = sum(conf_matrix(:, ii)) - TP;
        FN = sum(conf_matrix(ii, :)) - TP;
        TN = sum(conf_matrix(:)) - (TP + FP + FN);
        
        accuracy(ii)    = (TP + TN) / (TP + FP + FN + TN);
        precision(ii)   = TP / (TP + FP);
        recall(ii)      = TP / (TP + FN);
        f1_score(ii)    = 2 * (precision(ii) * recall(ii)) / (precision(ii) + recall(ii));
        jaccard_index(ii) = TP / (TP + FP + FN);
    end
    
    %handle NaN values (if class has no positive instances)
    [accuracy(isnan(accuracy)), precision(isnan(precision)), recall(isnan(recall)), f1_score(isnan(f1_score)), jaccard_index(isnan(jaccard_index))] = deal(0);
    
    %calculate macro-averaged metrics
    macro_precision = mean(precision);
    macro_recall    = mean(recall);
    macro_f1        = mean(f1_score);
    macro_accuracy  = mean(accuracy);
    macro_jaccard   = mean(jaccard_index);
    
    %calculate cp error statistics
    avg_cp_error = mean(abs(all_cp_errors));
    
    %write the changepoint stats to the model struct, enabling later display of statistics
    if size(all_cp_transitions, 1) == size(all_cp_errors, 1)
        app.movie_data.stats.changepoint_errors = [all_cp_transitions, all_cp_errors];
    else
        warndlg("Warning: error in annotation metrics, changepoint errors are not paired with class transitions", "Error in annotation metrics")
    end
    app.movie_data.stats.total_unpaired_changepoints    = total_unpaired_cps;
    app.movie_data.stats.total_paired_changepoints      = size(all_cp_errors, 1);
    app.movie_data.stats.mean_changepoint_error         = avg_cp_error;
    app.movie_data.stats.RMSE_changepoint_error         = sqrt(mean(all_cp_errors.^2)); %this only accounts for paired changepoints
    
    %display metrics
    conf_matrix_text = sprintf('Confusion Matrix:\n');
    for ii = 1:size(conf_matrix, 1)
        conf_matrix_text = [conf_matrix_text, sprintf('%10d', conf_matrix(ii, :)), newline];
    end
    
    output_text = sprintf('%s\nClass-wise Metrics:\n', conf_matrix_text);
    for ii = 1:N_classes
        output_text = sprintf('%sClass %d - Accuracy: %.4f, Precision: %.4f, Recall: %.4f, F1 Score: %.4f, Jaccard index: %.4f\n', output_text, ii, accuracy(ii), precision(ii), recall(ii), f1_score(ii), jaccard_index(ii));
    end
    
    %display cp error statistics including unpaired changepoints
    output_text = sprintf('%s\nCP Error Metrics:\nAverage CP Error: %.4f\nTotal Unpaired Change Points: %d\n', output_text, avg_cp_error, total_unpaired_cps);
    
    %display metrics; if training has just occurred, also report on the annotation time
    if nargin < 2
        output_text = sprintf('%s\nMacro-averaged metrics:\nAccuracy: %.4f\nPrecision: %.4f\nRecall: %.4f\nF1 Score: %.4f\nJaccard Index: %.4f\n', output_text, macro_accuracy, macro_precision, macro_recall, macro_f1, macro_jaccard);
    else
        annotation_time_text = "Completed classification and segmentation of entire dataset. Classification took " + num2str(app.movie_data.results.(structs_to_use{end, 1}).annotation_time) +...
            " seconds, followed by consensus voting.";
        
        output_text = sprintf('%s\n\n%s\nMacro-averaged metrics:\nAccuracy: %.4f\nPrecision: %.4f\nRecall: %.4f\nF1 Score: %.4f\nJaccard Index: %.4f\n', annotation_time_text, output_text, macro_accuracy, macro_precision, macro_recall, macro_f1, macro_jaccard);
    end
    
    app.textout.Value = output_text;
    
    %construct a custom figure to display metrics in case this is overwritten in textout display
    h = figure('Name', 'Annotation Metrics', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', 'Position', [100, 100, 820, 600], 'Resize', 'off');
    uicontrol('Style', 'edit', 'Max', 2, 'Min', 0, 'Parent', h, 'Position', [10, 10, 800, 580], 'String', output_text, ...
              'HorizontalAlignment', 'left', 'FontSize', 14, 'Enable', 'on');
end