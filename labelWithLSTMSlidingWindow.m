function [] = labelWithLSTMSlidingWindow(app)
%Label the entire loaded dataset with a pre-trained LSTM model in sections
%using a sliding window, Oliver Pambos, 02/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: labelWithLSTMSlidingWindow
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
%Moves a sliding window through a trajectory labelling the entire
%trajectory. As the sliding window passes each frame confidence parameters
%for each state from multiple windows are combined to obtain the most
%likely class for each frame, thus labelling the entire trajectory. This
%then repeats for every molecule in the dataset.
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
%cropTrajectories()
%labelSingleTrackSlidingLSTM()   - local to this .m file
    
    %clear any pre-existing LSTM labelled data
    app.movie_data.results.LSTMLabelled = [];
    
    %copy over every track to the empty struct
    count = 1;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs,1)
            %write the LoColi tracks data to the LabelledMols struct
            app.movie_data.results.LSTMLabelled.LabelledMols{count,1}.Mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj), :);
            
            %update the LSTMLabelled results substruct; a cell array of classifications performed by the user
            app.movie_data.results.LSTMLabelled.LabelledMols{count,1}.CellID = ii;
            app.movie_data.results.LSTMLabelled.LabelledMols{count,1}.MolID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj);
            app.movie_data.results.LSTMLabelled.LabelledMols{count,1}.EventSequence = 'pending';
            app.movie_data.results.LSTMLabelled.LabelledMols{count,1}.MoleculeDuration = size(app.movie_data.results.LSTMLabelled.LabelledMols{count,1}.Mol,1) / app.movie_data.params.frame_rate;      %in seconds; note that this current implementation does not factor in memory param; to be later replaced with calculation based on start-finish frame numbers as these are required for input file regardless of source data
            app.movie_data.results.LSTMLabelled.LabelledMols{count,1}.DateClassified = datestr(now, 'dd/mm/yy-HH:MM:SS');
            
            count = count + 1;
        end
    end
    
    %erase non-meaningful rows
    cropTrajectories(app, "LSTM_labelled", app.movie_data.models.LSTM.removed_rows(1,1), app.movie_data.models.LSTM.removed_rows(1,2));
    
    %find in the source data the columns that were used to train the model
    feature_cols = zeros(1, numel(app.movie_data.models.LSTM.feature_names));
    for ii = 1:numel(app.movie_data.models.LSTM.feature_names)
        idx = find(ismember(app.movie_data.params.column_titles.tracks, app.movie_data.models.LSTM.feature_names{ii}));
        
        %if the feature exists record it; otherwise exit and warn the user
        if ~isempty(idx)
            feature_cols(ii) = idx;
        else
            warndlg("The loaded model was trained on a feature (" + app.movie_data.models.LSTM.feature_names{ii} +") which does not exist in the source data. " + ...
                "If you believe this to be a mistake please check carefully, the spelling of column headers", "Unable to classify, feature not available", "modal");
            return;
        end
    end
    
    %initialise a progress bar (optionally set it to update only every five trajectories)
    f = waitbar(0,"Labelling the entire loaded dataset using Long Short-Term Memory (LSTM) model...");
    %update_freq = 5;
    
    tic
    
    %loop over all molecules
    for ii = 1:size(app.movie_data.results.LSTMLabelled.LabelledMols, 1)
        
        %apply feature scaling
        switch app.movie_data.models.LSTM.feature_scaling
            case "None"
                % << do nothing >>
                
            case "Z-score"
                %standardize each feature in the current track using Z-score
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) - app.movie_data.models.LSTM.feature_means(jj)) / app.movie_data.models.LSTM.feature_stds(jj);
                end
                
            case "Normalise (0-1)"
                %normalise each feature in the current track using min-max normalisation
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) - app.movie_data.models.LSTM.feature_mins(jj)) / (app.movie_data.models.LSTM.feature_maxs(jj) - app.movie_data.models.LSTM.feature_mins(jj));
                end
                
            otherwise
            
        end
        
        %extract columns of features to classify
        curr_track = app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols);
        
        %transpose and predict labels with model
        curr_track = curr_track';
        
        %predict labels using LSTM model
        %label_sequence = classify(app.movie_data.models.LSTM.model, curr_track);
        label_sequence = labelSingleTrackSlidingLSTM(curr_track, app.movie_data.models.LSTM.max_len, numel(app.movie_data.models.LSTM.class_names), app.movie_data.models.LSTM.model);
        
        %write labels back into LSTMLabelled results struct
        app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:,end) = double(label_sequence');
        
        %invert scaling transform
        switch app.movie_data.models.LSTM.feature_scaling
            case "None"
                % << do nothing >>
                
            case "Z-score"
                %standardize each feature in the current track using Z-score
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) * app.movie_data.models.LSTM.feature_stds(jj)) + app.movie_data.models.LSTM.feature_means(jj);
                end
                
            case "Normalise (0-1)"
                %normalise each feature in the current track using min-max normalisation
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) * (app.movie_data.models.LSTM.feature_maxs(jj) - app.movie_data.models.LSTM.feature_mins(jj))) + app.movie_data.models.LSTM.feature_mins(jj);
                end
                
            otherwise
            
        end
        
        %update the waitbar (optionally every 5 iterations)
        %if mod(ii, update_freq) == 0
            waitbar(ii/size(app.movie_data.results.LSTMLabelled.LabelledMols, 1), f, "Classificaiton complete for " + num2str(ii) + "/" + num2str(size(app.movie_data.results.LSTMLabelled.LabelledMols, 1)) + " trajectories");
        %end
    end
    
    t = toc;
    
    %update the waitbar one last time at the end
    waitbar(1, f, "Classification complete for all trajectories");

    app.textout.Value = "Completed classification and segmentation of entire dataset using Long Short-Term Memory model in " + num2str(t) + " seconds";
    
    close(f);
end


function [final_predictions] = labelSingleTrackSlidingLSTM(curr_track, window_size, N_classes, model)
%Uses a sliding window to label a single trajectory using a LSTM model,
%Oliver Pambos, 02/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: labelSingleTrackSlidingLSTM
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
%Moves a sliding window through a single trajectory classifying each step.
%As the sliding window passes each frame, confidence parameters
%for each state from multiple windows are combined to obtain the most
%likely class for each frame, thus labelling the entire trajectory.
%
%Input
%-----
%curr_track     (mat)   NxM numeric matrix of trajectory to be classified
%                           consisting of N features and M frames
%window_size    (int)   size of the window, in frames
%N_classes      (int)   number of classes used for classification
%model          (mdl)   LSTM model used for classification
%
%
%Output
%------
%final_predictions  (vec)   row vector of predictions for entire trajectory
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_frames = size(curr_track, 2);    
    
    %store predictions and their confidences
    class_predictions = zeros(N_frames, N_classes);
    confidence_scores = zeros(N_frames, N_classes);
    
    %move window through trajectory
    for start_idx = 1:(N_frames - window_size + 1)
        end_idx = start_idx + window_size - 1;
        
        %extract current window
        window_data = curr_track(:, start_idx:end_idx);
    
        %get predictions and confidences
        raw_scores = predict(model, window_data);
        probabilities = softmax(raw_scores);
        [max_probs, predicted_labels] = max(probabilities, [], 1);
        
        %store predictions and confidences
        for i = start_idx:end_idx
            class_predictions(i, predicted_labels(i - start_idx + 1)) = class_predictions(i, predicted_labels(i - start_idx + 1)) + 1;
            confidence_scores(i, predicted_labels(i - start_idx + 1)) = confidence_scores(i, predicted_labels(i - start_idx + 1)) + max_probs(i - start_idx + 1);
        end

    end
    
    %aggregate predictions for each frame
    final_predictions = zeros(1, N_frames);
    final_confidences = zeros(1, N_frames);
    for i = 1:N_frames
        [final_confidences(i), final_predictions(i)] = max(confidence_scores(i, :));
    end
    
end








































