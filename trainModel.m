function [] = trainModel(app)
%Train an ML model on annotated data, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainModel
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
%This function moves the main model training functions out of the GUI's
%main .mlapp code. The modularisation is intended to improve clarity, and
%also to better support cross-validation, and reinforcement learning.
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
%computeMetricsPadded()
%computeMetrics()
%trainRF()                      - local to this .m file
%trainGRU()                     - local to this .m file
%trainBiGRU()                   - local to this .m file
%trainLSTM()                    - local to this .m file
%trainBiLSTM()                  - local to this .m file
%storeMetadata()                - local to this .m file
%computeMetricsWithTestData()   - local to this .m file
%computeClassWeights()          - local to this .m file
    
    getModelSettings(app);

    %obtain changepoint masks if required by loss function
    if strcmp(app.LossfunctionDropDown.Value, "Transition and class weighted")
        genChangepointWeightedMask(app);
    end
    
    %direct to either cross-validation or full training of model
    switch app.TrainingmodeDropDown.Value
        case "Cross-validation"
            crossValidateModel(app);
        case "Final training"
            trainFinalModel(app);
        otherwise
            app.textout.Value = "Training mode not recognised.";
            return;
    end
end


function [] = crossValidateModel(app)
%Perform k-fold cross-validation, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: crossValidateModel
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
%This funciton carries out k-fold cross-validiation to speed up exploration
%of training parameters, and to better understand how the model can
%generalise to the annotated data.
%
%This function combines the test and validation data previously split by
%the genreate training data functions. After concatenating the data, and
%associated labels, the function then uses crossvalind() to split the
%combined data into k separate splits of training and validation data,
%while keeping the test data untouched for later evaluation. As a result
%each example (either whole, segment, or sliding window of a track) is used
%in the validation set exactly once. This ensures that the parameters can
%be tested without bias resulting from the validation set containing a
%small number of unusual examples. This is particularly important because
%the datasets in SMLM tracking, particularly for long tracks, can be small.
%
%This function moves the main model training functions out of the GUI's
%main .mlapp code. The modularisation is intended to improve clarity.
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
%computeMetricsPadded()
%computeMetrics()
%trainRF()                      - local to this .m file
%trainGRU()                     - local to this .m file
%trainBiGRU()                   - local to this .m file
%trainLSTM()                    - local to this .m file
%trainBiLSTM()                  - local to this .m file
%storeMetadata()                - local to this .m file
%computeMetricsWithTestData()   - local to this .m file
%computeClassWeights()          - local to this .m file
    
    k_folds    = app.KfoldsSpinner.Value;
    model_name = app.ModeltypeDropDown.Value;
    
    %concatenate training and validation data, and their classifications
    train_data   = [app.movie_data.results.train_data; app.movie_data.results.val_data];
    train_labels = [app.movie_data.results.train_labels; app.movie_data.results.val_labels];
    
    %get indices to assign each example ot a fold
    indices = crossvalind('Kfold', numel(train_data), k_folds);
    
    metrics = struct('accuracy', [], 'precision', [], 'recall', [], 'f1_score', []);
    
    %train on each fold separately
    h_progress = waitbar(0, 'Cross-Validation', 'Name', 'Cross-Validation progress');
    for ii = 1:k_folds
        waitbar(ii / k_folds, h_progress, sprintf('Processing fold %d of %d. This may take several minutes per fold.', ii, k_folds));
        
        val_idx     = (indices == ii);
        train_idx   = ~val_idx;

        cv_train_data   = train_data(train_idx);
        cv_train_labels = train_labels(train_idx);
        cv_val_data     = train_data(val_idx);
        cv_val_labels   = train_labels(val_idx);
        
        %allow user to switch training visualisation on/off
        if app.WatchallcrossvalidationtrainingCheckBox.Value
            show_training = true;
        else
            show_training = false;
        end
        
        %train model for current fold
        switch model_name
            case "Bidirectional LSTM (BiLSTM)"
                model_type = "BiLSTM";
                trainBiLSTM(app, model_name, model_type, cv_train_data, cv_train_labels, cv_val_data, cv_val_labels, show_training);
            case "Long Short-Term Memory (LSTM)"
                model_type = "LSTM";
                trainLSTM(app, model_name, model_type, cv_train_data, cv_train_labels, cv_val_data, cv_val_labels, show_training);
            case "Bidirectional GRU (BiGRU)"
                model_type = "BiGRU";
                trainBiGRU(app, model_name, model_type, cv_train_data, cv_train_labels, cv_val_data, cv_val_labels, show_training);
            case "Gated Recurrent Unit (GRU)"
                model_type = "GRU";
                trainGRU(app, model_name, model_type, cv_train_data, cv_train_labels, cv_val_data, cv_val_labels, show_training);
            case "Random forest"
                model_type = "RF";
                trainRF(app, model_name);  %note: random forest might need a different handling for cross-validation; resolve in future update
            otherwise
                app.textout.Value = "Model not currently available";
                close(h_progress);
                return;
        end
        
        %compute and store metrics for current fold
        [accuracy, precision, recall, f1_score] = computeMetricsWithTestData(app.movie_data.models.(model_type).model, cv_val_data, cv_val_labels, app.movie_data.results.padding, false);
        metrics.accuracy    = [metrics.accuracy, accuracy];
        metrics.precision   = [metrics.precision, precision];
        metrics.recall      = [metrics.recall, recall];
        metrics.f1_score    = [metrics.f1_score, f1_score];
    end
    
    close(h_progress);
    
    %obtain and display metrics across all folds
    avg_accuracy    = mean(metrics.accuracy);
    avg_precision   = mean(metrics.precision);
    avg_recall      = mean(metrics.recall);
    avg_f1_score    = mean(metrics.f1_score);
    
    std_accuracy    = std(metrics.accuracy);
    std_precision   = std(metrics.precision);
    std_recall      = std(metrics.recall);
    std_f1_score    = std(metrics.f1_score);
    
    app.textout.Value = "Cross-Validation Results:" + newline + ...
        "Accuracy: " + num2str(avg_accuracy) + " (" + num2str(std_accuracy) + ")" + newline + ...
        "Precision: " + num2str(avg_precision) + " (" + num2str(std_precision) + ")" + newline + ...
        "Recall: " + num2str(avg_recall) + " (" + num2str(std_recall) + ")" + newline + ...
        "F1 Score: " + num2str(avg_f1_score) + " (" + num2str(std_f1_score) + ")";
end


function [] = trainFinalModel(app)
%Perform a single full training run, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainFinalModel
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
%This function contains code that was moved from the main GUI's code to
%improve modularity and code maintenance.
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
%computeMetricsPadded()
%computeMetrics()
%trainRF()                      - local to this .m file
%trainGRU()                     - local to this .m file
%trainBiGRU()                   - local to this .m file
%trainLSTM()                    - local to this .m file
%trainBiLSTM()                  - local to this .m file
%storeMetadata()                - local to this .m file
%computeMetricsWithTestData()   - local to this .m file
%computeClassWeights()          - local to this .m file
    
    model_name = app.ModeltypeDropDown.Value;
    switch model_name
        case "Random forest"
            model_type = "RF";
            trainRF(app, model_name);
        case "Bidirectional LSTM (BiLSTM)"
            model_type = "BiLSTM";
            trainBiLSTM(app, model_name, model_type, app.movie_data.results.train_data, app.movie_data.results.train_labels, app.movie_data.results.val_data, app.movie_data.results.val_labels, true);
        case "Long Short-Term Memory (LSTM)"
            model_type = "LSTM";
            trainLSTM(app, model_name, model_type, app.movie_data.results.train_data, app.movie_data.results.train_labels, app.movie_data.results.val_data, app.movie_data.results.val_labels, true);
        case "Bidirectional Gated Recurrent Unit (BiGRU)"
            model_type = "BiGRU";
            trainBiGRU(app, model_name, model_type, app.movie_data.results.train_data, app.movie_data.results.train_labels, app.movie_data.results.val_data, app.movie_data.results.val_labels, true);
        case "Gated Recurrent Unit (GRU)"
            model_type = "GRU";
            trainGRU(app, model_name, model_type, app.movie_data.results.train_data, app.movie_data.results.train_labels, app.movie_data.results.val_data, app.movie_data.results.val_labels, true);
    end
    
    %compute and report metrics
    [accuracy, precision, recall, f1_score] = computeMetricsWithTestData(app.movie_data.models.(model_type).model, app.movie_data.results.test_data, app.movie_data.results.test_labels, app.movie_data.results.padding, true);
    app.textout.Value = "Accuracy: " + num2str(accuracy) + newline + "Precision: " + num2str(precision) + newline + "Recall: " + num2str(recall) + newline + "F1 Score: " + num2str(f1_score);
end


function [loss] = changepointWeightedLoss(YPred, YTrue, class_weights)
%Custom loss function using heavier weights for datapoints around regions
%of changepoints, as well as class weighting, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: changepointWeightedLoss
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
%Computes the class-weighted and transition-proximal weighted loss. This
%function calculates the weighted cross-entropy loss for sequence data,
%where weights are assigned based on class importance and proximity to
%transition points (change points). Transition points are identified by
%changes in the ground truth annotations. This helps the model to focus
%more on critical transition areas, improving classification performance on
%such segments.
%
%Inputs
%------
%YPred          (dlarray)   CxWxT dlarray containing predicted
%                               probabilities for each window; dimensions
%                               are,
%                                   C: class
%                                   W: window number
%                                   T: timepoint in window
%YTrue          (dlarray)   CxWxT dlarray containing the annotations being
%                               used as ground truth; this is essentially a
%                               one-hot encoding for ground truth class
%class_weights  (vec)       1xC row vector of class weights (currently
%                               these are based entirely on dataset-wide
%                               class frequency)
%
%Output
%------
%loss           (float)     total weighted cross-entropy loss summed over
%                               all classes, windows, and timepoints;
%                               computed using both class weights and
%                               changepoint proximity mask weights
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%genChangepointMasksInLossFn()  - local to this .m file
    
    %define epsilon as smallest value for class predictions to avoid numerical instability
    epsilon = 1e-10;
    
    %changepoint additional weighting - this will be later replaced with user input
    cp_weight = 2;
    
    %clip predicted probabilities to avoid instability from log(0)
    YPred = max(YPred, dlarray(epsilon));
    
    [C, B, T] = size(YPred);

    %generate changepoint masks
    changepoint_masks = dlarray(genChangepointMasks(YTrue));
    
    %reformat class weights to match dimensions
    class_weights_expanded = dlarray(reshape(class_weights, [C, 1, 1]));
    class_weights_expanded = repmat(class_weights_expanded, [1, B, T]);

    %compute weights
    weights = (1 + cp_weight * changepoint_masks);
    weights = reshape(weights, [1, B, T]);
    weights = repmat(weights, [C, 1, 1]);
    weights = weights .* class_weights_expanded;
    
    %compute cross-entropy loss
    loss_per_class = -YTrue .* log(YPred);
    
    %apply weights, and compute total loss
    weighted_loss_per_class = loss_per_class .* weights;
    loss = sum(weighted_loss_per_class, 'all');
end


function [changepoint_masks] = genChangepointMasks(YTrue)
%Computes a changepoint mask for all windows for a batch, Oliver Pambos,
%13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genChangepointMasksInLossFn
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
%Generates a changepoint mask for the current batch of windows in the
%training set by processing the one-hot encoding of the ground truth
%annotations.
%
%Note that the distance (temporal) from each changepoint that defines
%inclusion in the mask is currently hardcoded. This will be updated with a
%user GUI control in a future update.
%
%Inputs
%------
%YTrue              (dlarray)   CxBxT dlarray containing the annotations
%                                   being used as ground truth for the
%                                   current batch; this is a one-hot
%                                   encoding for ground truth class
%
%Output
%------
%changepoint_masks  (mat)       BxT matrix binary mask for the current
%                                   batch for which 1 represents a
%                                   changepoint-proximal localisation, and
%                                   0 represents all other localisations,
%                                   each row represents a window of the
%                                   current batch, and each column
%                                   represents a timepoint within that
%                                   window. The dimensions are,
%                                       B: number of windows in current
%                                           batch
%                                       T: number of timepoints in each
%                                           window
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %distance from changepoint for inclusion in mask (will be replaced with input variable in future update)
    N = 3;
    
    [~, batchSize, timeSteps] = size(YTrue);
    changepoint_masks = zeros(batchSize, timeSteps);
    
    %loop over each window (sequence) in the batch
    for b = 1:batchSize
        temp_labels = squeeze(YTrue(:, b, :));
        temp_labels = extractdata(temp_labels);
        
        %convert sequence to row vector of states (one-hot encoding not useful for this task), and find changepoints
        [~, state_sequence] = max(temp_labels, [], 1);
        changepoints = find(diff(state_sequence) ~= 0);
        
        %generate mask
        for jj = 1:length(changepoints)
            idx_start = max(1, changepoints(jj) - N + 1);
            idx_end   = min(timeSteps, changepoints(jj) + N);
            
            changepoint_masks(b, idx_start:idx_end) = 1;
        end
    end
end


function [] = storeMetadata(app, model_type, model_name)
%Store metadata and variables used for feature scaling and training with
%model, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainRF
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
%This function writes the metadata associated with the the model, and its
%training to the associated model substruct of the results struct. This was
%moved from the main .mlapp file for improved readability and modularity.
%
%Inputs
%------
%app        (handle)    main GUI handle
%model_name (str)       human-readable text description of the model
%model_type (str)       struct name for the model in found in the results struct
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    app.movie_data.models.(model_type) = app.movie_data.models.temp_params;
    app.movie_data.models.(model_type).model_name = model_name;
    [app.movie_data.models.(model_type).model_type, app.movie_data.models.current_model] = deal(model_type);
    app.movie_data.models.(model_type).class_names = app.movie_data.params.class_names;
    app.movie_data.models.(model_type).feature_names = app.movie_data.params.column_titles.tracks([app.movie_data.models.temp_params.feature_cols]);
    app.movie_data.models.(model_type).user = app.UserEditField.Value;
    app.movie_data.models.(model_type).timestamp = string(datetime);
    app.movie_data.models.(model_type).max_len = size(app.movie_data.results.train_data{1,1}, 2);
end


function [accuracy, precision, recall, f1_score] = computeMetricsWithTestData(model, test_data, test_labels, padding, show_plot)
%Compute metrics of the model after training by evaluation of the hold-out
%test data, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeMetricsWithTestData
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
%This funciton was moved from the main GUI .mlapp file to make the code
%more modular and readable prior to public release.
%
%Inputs
%------
%model          (mdl)   trained model
%test_data      (cell)  hold-out test data as a cell array, with each cell
%                           containing an individual example in the format
%                           of a NxM matrix of N features and M timepoints
%test_labels    (cell)  class labels of accepted ground truth (which can be
%                           human annotations) for hold-out test data
%                           example; each cell contains an individual
%                           example of format 1xM vector with M timepoints
%padding        (bool)  true (1) if padded, false (1) if not
%
%Output
%------
%accuracy       (float) mean accuracy across all classes
%precision      (float) mean precision across all classes
%recall         (float) mean recall across all classes
%f1_score       (float) mean f1 score across all classes
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeMetricsPadded()
%computeMetrics()
    
    if padding
        [accuracy, precision, recall, f1_score, ~] = computeMetricsPadded(model, test_data, test_labels, show_plot);
    else
        [accuracy, precision, recall, f1_score, ~] = computeMetrics(model, test_data, test_labels, show_plot);
    end
end


function [classes, class_weights] = computeClassWeights(app)
%Balance class weights by the inverse of the frequency with which they
%occur, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeClassWeights
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
%Computes class weights from the inverse of their relative frequency across
%the training data.
%
%Inputs
%------
%app            (handle)    main GUI handle
%
%Output
%------
%classes        (cell)      cell array of classes, in this case stored as
%                               strings of the integers, which are used as
%                               look-up IDs for the real class names found
%                               in app.movie_data.params.class_names
%class_weights  (vec)       row vector of relative class weights (there are
%                               not required to be normalised)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %concat train labels into single matrix
    train_labels_concat = vertcat(app.movie_data.results.train_labels{:});
    
    %get classes (categoricals in matlab store all possible categories, even if not all categories actually appear in data)
    unique_classes  = categories(train_labels_concat);
    N_classes       = numel(unique_classes);
    
    %count frequency of each class across all annotations in training set
    class_counts = zeros(1, N_classes);
    for ii = 1:N_classes
        class_counts(ii) = sum(sum(train_labels_concat == unique_classes{ii}));
    end
    
    %compute class weights by inverse of class frequencies, and then normalise
    class_weights = 1 ./ class_counts;
    class_weights = class_weights / sum(class_weights) * N_classes;
    
    %define classes for classification layer
    classes = unique_classes;
end


function [options] = getTrainingOptions(val_data, val_labels, show_plot, max_epochs, batch_size, learn_rate)
%Returns the training options for use with the trainnet function, Oliver
%Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getTrainingOptions
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
%Returns training options. This function was introduced to minimise
%repetitions of training option definitions in multiple training functions.
%
%Inputs
%------
%app        (handle)    main GUI handle
%
%Output
%------
%options    (obj)       object containing training options
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if show_plot
        plot_option = 'training-progress';
    else
        plot_option = 'none';
    end
    
    options = trainingOptions('adam', ...
        'MaxEpochs', max_epochs, ...
        'MiniBatchSize', batch_size, ...
        'InitialLearnRate', learn_rate, ...
        'Verbose', 0, ...
        'Plots', plot_option, ...
        'Metrics', 'accuracy', ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropPeriod', 1, ...
        'LearnRateDropFactor', 0.5, ...
        'ValidationData', {val_data, val_labels}, ...
        'ValidationFrequency', 30, ...
        'ValidationPatience', 5, ...
        'Shuffle', 'every-epoch', ...
        'OutputNetwork', 'best-validation-loss');
end


function [train_data, train_labels, val_data, val_labels] = transposeTrainValData(train_data, train_labels, val_data, val_labels)
%Transpose the data and labels in cell arrays of training and validation
%datasets to prepare data for use with trainnet(), Oliver Pambos,
%13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: transposeTrainValData
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
%Inputs
%------
%train_data     (cell)  Nx1 cell array of training data examples, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%train_labels   (cell)  Nx1 cell array of training labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%val_data       (cell)  Mx1 cell array of validation data examples, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%val_labels     (cell)  Mx1 cell array of validation labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%
%Output
%------
%train_data     (cell)  training data reformatted so that each example is
%                           transposed to give dimensions of TxF
%train_labels   (cell)  training labels reformatted so that each example is
%                           transposed to give dimensions of Tx1
%val_data       (cell)  validation data reformatted so that each example is
%                           transposed to give dimensions of TxF
%val_labels     (cell)  validation labels reformatted so that each example
%                           is transposed to give dimensions of Tx1
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    for ii = 1:size(train_data, 1)
        train_data{ii} = transpose(train_data{ii});
        train_labels{ii} = transpose(train_labels{ii});
    end
    for ii = 1:size(val_data, 1)
        val_data{ii} = transpose(val_data{ii});
        val_labels{ii} = transpose(val_labels{ii});
    end
end


function [] = trainBiLSTM(app, model_name, model_type, train_data, train_labels, val_data, val_labels, show_plot)
%Train BiLSTM model, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainBiLSTM
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
%This function trains a Bidirectional LSTM model. This was moved from the
%main GUI .mlapp file to make the code more modular and readable prior to
%public release.
%
%Important: note that train_data, train_labels, val_data, and val_labels,
%are passed separately to this function despite the app handles also being
%passed. This is because this function is also able to run in
%cross-validation mode, during which the training and validation data is
%re-sampled. It is important not to attempt to revert this function to
%taking these data directly from the app handles.
%
%Inputs
%------
%app            (handle)    main GUI handle
%model_name     (str)       human-readable text description of the model
%model_type     (str)       struct name for the model in found in the
%                               results struct
%train_data     (cell)      Nx1 cell array of training data examples, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%train_labels   (cell)      Nx1 cell array of training labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%val_data       (cell)      Mx1 cell array of validation data examples, wher
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%val_labels     (cell)      Mx1 cell array of validation labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%show_plot      (bool)      determines whether to display (True), or
%                               suppress (False) visualisation of the
%                               training process, which is useful to
%                               suppress during cross-validation
%
%Output
%------
%None   - results are writted directly into data in app handles
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeClassWeights()  - local to this .m file
    
    app.textout.Value = 'Training bidirectional LSTM model';
    
    %copy over the temporary parameters
    app.movie_data.models.BiLSTM = app.movie_data.models.temp_params;

    %store metadata and variables used for feature scaling and training with model
    storeMetadata(app, model_type, model_name);
    
    if app.movie_data.results.padding == true
        %number of features is N+1 as an additional feature is added for the padded mask
        N_features  = size(app.movie_data.models.BiLSTM.feature_cols, 2) + 1;
        %number of classes is N+1 as an additional class is included for padded region of trajectory
        N_classes   = size(app.movie_data.params.class_names, 1) + 1;
        %keep track of whether model was trained on windowed data
        app.movie_data.models.BiLSTM.windowed = false;
    else
        N_features  = size(app.movie_data.models.BiLSTM.feature_cols, 2);
        N_classes   = size(app.movie_data.params.class_names, 1);
        app.movie_data.models.BiLSTM.windowed = true;
    end
    
    [~, class_weights] = computeClassWeights(app);
    
    layers = [sequenceInputLayer(N_features)
        bilstmLayer(app.movie_data.models.BiLSTM.N_units, 'OutputMode', 'sequence', ...
            'InputWeightsL2Factor', app.movie_data.models.BiLSTM.input_l2_factor, ...
            'RecurrentWeightsL2Factor', app.movie_data.models.BiLSTM.recurrent_l2_factor, ...
            'BiasL2Factor', app.movie_data.models.BiLSTM.bias_l2_factor)
        dropoutLayer(app.movie_data.models.BiLSTM.dropout_rate)
        fullyConnectedLayer(N_classes)
        softmaxLayer];
    
    %generate temporary reformatted versions of train and val datasets
    [train_data_tp, train_labels_tp, val_data_tp, val_labels_tp] = transposeTrainValData(train_data, train_labels, val_data, val_labels);
    
    options = getTrainingOptions(val_data_tp, val_labels_tp, show_plot, app.movie_data.models.BiLSTM.max_epochs, app.movie_data.models.BiLSTM.batch_size, app.movie_data.models.BiLSTM.learn_rate);
    
    %train network with user-requested loss function
    switch app.LossfunctionDropDown.Value
        case "Class weighted"
            lossFcn = @(YPred, YTrue) crossentropy(YPred, YTrue, Weights=class_weights, WeightsFormat='C');
            app.movie_data.models.BiLSTM.model = trainnet(train_data_tp, train_labels_tp, layers, lossFcn, options);
            
        case "Transition and class weighted"
            app.movie_data.models.BiLSTM.model = trainnet(train_data_tp, train_labels_tp, layers, ...
                @(YPred, YTrue) changepointWeightedLoss(YPred, YTrue, class_weights), options);
    end
end


function [] = trainLSTM(app, model_name, model_type, train_data, train_labels, val_data, val_labels, show_plot)
%Train an LSTM model, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainLSTM
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
%This function trains an LSTM model. This was moved from the main GUI
%.mlapp file to make the code more modular and readable prior to public
%release.
%
%Important: note that train_data, train_labels, val_data, and val_labels,
%are passed separately to this function despite the app handles also being
%passed. This is because this function is also able to run in
%cross-validation mode, during which the training and validation data is
%re-sampled. It is important not to attempt to revert this function to
%taking these data directly from the app handles.
%
%Inputs
%------
%app            (handle)    main GUI handle
%model_name     (str)       human-readable text description of the model
%model_type     (str)       struct name for the model in found in the
%                               results struct
%train_data     (cell)      Nx1 cell array of training data examples, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%train_labels   (cell)      Nx1 cell array of training labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%val_data       (cell)      Mx1 cell array of validation data examples, wher
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%val_labels     (cell)      Mx1 cell array of validation labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%show_plot      (bool)      determines whether to display (True), or
%                               suppress (False) visualisation of the
%                               training process, which is useful to
%                               suppress during cross-validation
%
%Output
%------
%None   - results are writted directly into data in app handles
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeClassWeights()  - local to this .m file
    
    app.textout.Value = 'Training LSTM model';
    
    %copy over the temporary parameters
    app.movie_data.models.LSTM = app.movie_data.models.temp_params;
    
    %store metadata and variables used for feature scaling and training with model
    storeMetadata(app, model_type, model_name);

    if app.movie_data.results.padding == true
        %number of features is N+1 as an additional feature is added for the padded mask
        N_features  = size(app.movie_data.models.LSTM.feature_cols,2) + 1;
        %number of classes is N+1 as an additional class is included for padded region of trajectory
        N_classes   = size(app.movie_data.params.class_names,1) + 1;
        %keep track of whether model was trained on windowed data
        app.movie_data.models.LSTM.windowed = false;
    else
        N_features  = size(app.movie_data.models.LSTM.feature_cols,2);
        N_classes   = size(app.movie_data.params.class_names,1);
        app.movie_data.models.LSTM.windowed = true;
    end
    
    %get classes, and class weights based on their frequencies
    [~, class_weights] = computeClassWeights(app);

    %define LSTM network architecture, and configure options
    layers = [sequenceInputLayer(N_features)
        lstmLayer(app.movie_data.models.LSTM.N_units, 'OutputMode', 'sequence', ...
            'InputWeightsL2Factor', app.movie_data.models.LSTM.input_l2_factor, ...
            'RecurrentWeightsL2Factor', app.movie_data.models.LSTM.recurrent_l2_factor, ...
            'BiasL2Factor', app.movie_data.models.LSTM.bias_l2_factor)
        dropoutLayer(app.movie_data.models.LSTM.dropout_rate)
        fullyConnectedLayer(N_classes)
        softmaxLayer];
    

    %generate temporary reformatted versions of train and val datasets
    [train_data_tp, train_labels_tp, val_data_tp, val_labels_tp] = transposeTrainValData(train_data, train_labels, val_data, val_labels);
    
    options = getTrainingOptions(val_data_tp, val_labels_tp, show_plot, app.movie_data.models.LSTM.max_epochs, app.movie_data.models.LSTM.batch_size, app.movie_data.models.LSTM.learn_rate);
    
    %train network with user-requested loss function
    switch app.LossfunctionDropDown.Value
        case "Class weighted"
            lossFcn = @(YPred, YTrue) crossentropy(YPred, YTrue, Weights=class_weights, WeightsFormat='C');
            app.movie_data.models.LSTM.model = trainnet(train_data_tp, train_labels_tp, layers, lossFcn, options);
            
        case "Transition and class weighted"
            app.movie_data.models.LSTM.model = trainnet(train_data_tp, train_labels_tp, layers, ...
                @(YPred, YTrue) changepointWeightedLoss(YPred, YTrue, class_weights), options);
    end
end


function [] = trainBiGRU(app, model_name, model_type, train_data, train_labels, val_data, val_labels, show_plot)
%Train a BiGRU model, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainBiGRU
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
%This function trains a bidirectional GRU model. This was moved from the
%main GUI .mlapp file to make the code more modular and readable prior to
%public release.
%
%Important: note that train_data, train_labels, val_data, and val_labels,
%are passed separately to this function despite the app handles also being
%passed. This is because this function is also able to run in
%cross-validation mode, during which the training and validation data is
%re-sampled. It is important not to attempt to revert this function to
%taking these data directly from the app handles.
%
%Inputs
%------
%app            (handle)    main GUI handle
%model_name     (str)       human-readable text description of the model
%model_type     (str)       struct name for the model in found in the
%                               results struct
%train_data     (cell)      Nx1 cell array of training data examples,
%                               where each cell may contain either a
%                               single sliding window or a full track
%                               depeding upon options. Dimensions are
%                               FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%train_labels   (cell)      Nx1 cell array of training labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%val_data       (cell)      Mx1 cell array of validation data examples,
%                               where each cell may contain either a
%                               single sliding window or a full track
%                               depeding upon options. Dimensions are
%                               FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%val_labels     (cell)      Mx1 cell array of validation labels, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are 1xT.
%show_plot      (bool)      determines whether to display (True), or
%                               suppress (False) visualisation of the
%                               training process, which is useful to
%                               suppress during cross-validation
%
%Output
%------
%None   - results are writted directly into data in app handles
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeClassWeights()  - local to this .m file
    
    app.textout.Value = 'Training BiGRU model';
    
    %copy over the temporary parameters
    app.movie_data.models.BiGRU = app.movie_data.models.temp_params;
    
    %store metadata and variables used for feature scaling and training with model
    storeMetadata(app, model_type, model_name);
    
    if app.movie_data.results.padding == true
        %number of features is N+1 as an additional feature is added for the padded mask
        N_features  = size(app.movie_data.models.BiGRU.feature_cols,2) + 1;
        %number of classes is N+1 as an additional class is included for padded region of trajectory
        N_classes   = size(app.movie_data.params.class_names,1) + 1;
        %keep track of whether model was trained on windowed data
        app.movie_data.models.BiGRU.windowed = false;
    else
        N_features  = size(app.movie_data.models.BiGRU.feature_cols,2);
        N_classes   = size(app.movie_data.params.class_names,1);
        app.movie_data.models.BiGRU.windowed = true;
    end
    
    %get classes, and class weights based on their frequencies
    [~, class_weights] = computeClassWeights(app);
    
    %define BiGRU network architecture, and configure options
    layers = [sequenceInputLayer(N_features)
        gruLayer(app.movie_data.models.BiGRU.N_units, 'OutputMode', 'sequence', ...
            'InputWeightsL2Factor', app.movie_data.models.BiGRU.input_l2_factor, ...
            'RecurrentWeightsL2Factor', app.movie_data.models.BiGRU.recurrent_l2_factor, ...
            'BiasL2Factor', app.movie_data.models.BiGRU.bias_l2_factor)
        dropoutLayer(app.movie_data.models.BiGRU.dropout_rate)
        fullyConnectedLayer(N_classes)
        softmaxLayer];
    
    %generate temporary reformatted versions of train and val datasets
    [train_data_tp, train_labels_tp, val_data_tp, val_labels_tp] = transposeTrainValData(train_data, train_labels, val_data, val_labels);
    
    options = getTrainingOptions(val_data_tp, val_labels_tp, show_plot, app.movie_data.models.BiGRU.max_epochs, app.movie_data.models.BiGRU.batch_size, app.movie_data.models.BiGRU.learn_rate);
    
    %train network with user-requested loss function
    switch app.LossfunctionDropDown.Value
        case "Class weighted"
            lossFcn = @(YPred, YTrue) crossentropy(YPred, YTrue, Weights=class_weights, WeightsFormat='C');
            app.movie_data.models.BiGRU.model = trainnet(train_data_tp, train_labels_tp, layers, lossFcn, options);
            
        case "Transition and class weighted"
            app.movie_data.models.BiGRU.model = trainnet(train_data_tp, train_labels_tp, layers, ...
                @(YPred, YTrue) changepointWeightedLoss(YPred, YTrue, class_weights), options);
    end
end


function [] = trainGRU(app, model_name, model_type, train_data, train_labels, val_data, val_labels, show_plot)
%Train a GRU model, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainGRU
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
%This function trains a GRU model. This was moved from the main GUI .mlapp
%file to make the code more modular and readable prior to public release.
%
%Important: note that train_data, train_labels, val_data, and val_labels,
%are passed separately to this function despite the app handles also being
%passed. This is because this function is also able to run in
%cross-validation mode, during which the training and validation data is
%re-sampled. It is important not to attempt to revert this function to
%taking these data directly from the app handles.
%
%Inputs
%------
%app            (handle)    main GUI handle
%model_name     (str)       human-readable text description of the model
%model_type     (str)       struct name for the model in found in the
%                               results struct
%train_data     (cell)      Nx1 cell array of training data examples, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%train_labels   (cell)      Nx1 cell array of training labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%val_data       (cell)      Mx1 cell array of validation data examples, wher
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%val_labels     (cell)      Mx1 cell array of validation labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%show_plot      (bool)      determines whether to display (True), or
%                               suppress (False) visualisation of the
%                               training process, which is useful to
%                               suppress during cross-validation
%
%Output
%------
%None   - results are writted directly into data in app handles
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeClassWeights()  - local to this .m file
    
    app.textout.Value = 'Training GRU model';
    
    %copy over the temporary parameters
    app.movie_data.models.GRU = app.movie_data.models.temp_params;
    
    %store metadata and variables used for feature scaling and training with model
    storeMetadata(app, model_type, model_name);
        
    if app.movie_data.results.padding == true
        %number of features is N+1 as an additional feature is added for the padded mask
        N_features  = size(app.movie_data.models.GRU.feature_cols,2) + 1;
        %number of classes is N+1 as an additional class is included for padded region of trajectory
        N_classes   = size(app.movie_data.params.class_names,1) + 1;
        %keep track of whether model was trained on windowed data
        app.movie_data.models.GRU.windowed = false;
    else
        N_features  = size(app.movie_data.models.GRU.feature_cols,2);
        N_classes   = size(app.movie_data.params.class_names,1);
        app.movie_data.models.GRU.windowed = true;
    end
    
    %get classes, and class weights based on their frequencies
    [~, class_weights] = computeClassWeights(app);
    
    %define GRU network architecture, and configure options
    layers = [sequenceInputLayer(N_features)
        gruLayer(app.movie_data.models.GRU.N_units, 'OutputMode', 'sequence', ...
            'InputWeightsL2Factor', app.movie_data.models.GRU.input_l2_factor, ...
            'RecurrentWeightsL2Factor', app.movie_data.models.GRU.recurrent_l2_factor, ...
            'BiasL2Factor', app.movie_data.models.GRU.bias_l2_factor)
        dropoutLayer(app.movie_data.models.GRU.dropout_rate)
        fullyConnectedLayer(N_classes)
        softmaxLayer];
    
    %generate temporary reformatted versions of train and val datasets
    [train_data_tp, train_labels_tp, val_data_tp, val_labels_tp] = transposeTrainValData(train_data, train_labels, val_data, val_labels);
    
    options = getTrainingOptions(val_data_tp, val_labels_tp, show_plot, app.movie_data.models.GRU.max_epochs, app.movie_data.models.GRU.batch_size, app.movie_data.models.GRU.learn_rate);
    
    %train network with user-requested loss function
    switch app.LossfunctionDropDown.Value
        case "Class weighted"
            lossFcn = @(YPred, YTrue) crossentropy(YPred, YTrue, Weights=class_weights, WeightsFormat='C');
            app.movie_data.models.GRU.model = trainnet(train_data_tp, train_labels_tp, layers, lossFcn, options);
            
        case "Transition and class weighted"
            app.movie_data.models.GRU.model = trainnet(train_data_tp, train_labels_tp, layers, ...
                @(YPred, YTrue) changepointWeightedLoss(YPred, YTrue, class_weights), options);
    end
end


function [] = trainRF(app, model_name)
%Train a random forest model, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainRF
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
%This function trains a random forest model. This was moved from the main
%GUI .mlapp file to make the code more modular and readable prior to public
%release.
%
%Inputs
%------
%app        (handle)    main GUI handle
%model_name (str)       human-readable text description of the model
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    app.textout.Value = "Training random forest model";
    
    if ~isfield(app.movie_data.models.temp_params, "N_trees")
        app.movie_data.models.temp_params.N_trees = app.movie_data.models.RF.N_trees;
    end
    
    %store metadata and variables used for feature scaling and training with model
    app.movie_data.models.RF                = app.movie_data.models.temp_params;
    app.movie_data.models.RF.model_name     = "Random forest";
    app.movie_data.models.RF.class_names    = app.movie_data.params.class_names;
    app.movie_data.models.RF.feature_names  = app.movie_data.params.column_titles.tracks([app.movie_data.models.temp_params.feature_cols]);
    app.movie_data.models.RF.user           = app.UserEditField.Value;
    app.movie_data.models.RF.timestamp      = string(datetime);
    app.movie_data.models.current_model     = model_name;
    
    %before the new model is trained wipe the metrics of any previous model of this type
    app.movie_data.models.RF.metrics = [];
    
    %gather features class labels, and model inputs (restricting to number of trees for inital testing)
    features    = app.movie_data.results.train_data(:,(1:end-1));
    labels      = app.movie_data.results.train_data(:,end);
    N_trees     = app.movie_data.models.temp_params.N_trees;
    
    tic
    %train the model; future versions likely move this substruct/cell array app.movie_data.models{} to allow multiple models to be loaded simultaneously
    %this will be replaced with a call to fitcensemble in future
    app.movie_data.models.RF.model = TreeBagger(N_trees, features, labels, 'Method', 'classification', 'OOBPredictorImportance','On');
    t = toc;
    app.textout.Value = "Completed training of random forest model in " + num2str(t) + " seconds";
    
    %run on test data to evaluate performance
    X_test = app.movie_data.results.test_data(:, 1:end-1);
    Y_test = app.movie_data.results.test_data(:, end);
    [Y_pred, ~] = predict(app.movie_data.models.RF.model, X_test);
    Y_pred = str2double(Y_pred);
    
    accuracy = sum(Y_pred == Y_test) / numel(Y_test);
    
    C = confusionmat(Y_test, Y_pred);
    confusionchart(C, app.movie_data.models.RF.class_names, 'FontSize', 18);
    
    %initialise vectors for precision, recall, and F1 score
    [precision, recall, f1_score] = deal(zeros(size(app.movie_data.models.RF.class_names, 1), 1));
    
    %loop over classes computing precision, recall and F1 score
    for ii = 1:size(app.movie_data.models.RF.class_names, 1)
        true_positives  = C(ii, ii);
        false_positives = sum(C(:, ii)) - true_positives;
        false_negatives = sum(C(ii, :)) - true_positives;
        
        precision(ii)   = true_positives / (true_positives + false_positives);
        recall(ii)      = true_positives / (true_positives + false_negatives);
        f1_score(ii)    = 2*(precision(ii)*recall(ii)) / (precision(ii) + recall(ii));
    end
    
    %average over all classes
    avg_precision   = mean(precision, 'omitnan');
    avg_recall      = mean(recall, 'omitnan');
    avg_f1_score    = mean(f1_score, 'omitnan');
    
    %display model performance metrics to user
    app.textout.Value = "Metrics from hold out test data"  + newline +...
        "Accuracy: " + num2str(accuracy, "%.4f") + newline +...
        "Precision: " + num2str(avg_precision, "%.4f") + newline +...
        "Recall: " + num2str(avg_recall, "%.4f") + newline +...
        "F1 score: " + num2str(avg_f1_score, "%.4f");

    %store the metrics
    app.movie_data.models.RF.metrics.accuracy   = accuracy;
    app.movie_data.models.RF.metrics.precision  = avg_precision;
    app.movie_data.models.RF.metrics.recall     = avg_recall;
    app.movie_data.models.RF.metrics.recall     = avg_f1_score;
end