function [] = labelWithSlidingWindow(app, model_type)
%Label the entire loaded dataset with a pre-trained BiLSTM model in sections
%using a sliding window, Oliver Pambos, 02/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: labelWithBiLSTMSlidingWindow
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
%Moves a sliding window through a trajectory predicting classes for the
%entire trajectory. As the sliding window passes each frame we obtain the
%confidence per class for every localisation in every window. As each
%localisation appears in multiple windows, it then combines the confidences
%for each localisation from multiple windows to obtain a total normalised
%confidence per class based on the multiple observations. After obtaining
%the consensus normalised probability for each localisation, the chosen
%class is then obtained as the class with the highest consensus
%probability. Repeating this across all windows annotates the entire
%trajectory, and repetition over all tracks annoates the full dataset.
%
%This latest refactoring of the code replaces earlier use of numeric
%matrices with dlarrays, and further minimises, modularises, and vectorises
%operations to improve performance. The dlarray has the structure
%   [class, sequence_ID, timepoint], a.k.a. [C,B,T] (class, batch, time)
%
%Note that the dlarray contains the windowed data, such that each example
%represents only a part of a track, and so the size along the B dimension
%is typically much larger than the total number of tracks from which the
%windows are extracted.
%
%The classification is extremely rapid, with a typical dataset being
%annotated in a few hundred milliseconds. However, there is a much larger
%overhead in terms of performing the consensus scoring, and returning the
%data to the appropriate place in the more human-accessible cell array in
%which the data is stored for downstream processing. Any future performance
%improvements should focus on this part of the process.
%
%cropTrajectories has been temporarily disabled pending a future update to
%computeAnnotationMetrics which will ensure following row removal that
%comparisons are made between the correct localisations.
%
%
%Input
%-----
%app        (handle)    main GUI handle
%model_type (str)       type of model (e.g., 'BiLSTM', 'LSTM', 'GRU', 'BiGRU')
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%cropTrajectories()
%computeConsensus()     - local to this .m file
%reformatToDLArray()    - local to this .m file
    
    %construct a dynamic field name, enabling this code to work with any model type
    model_label_field = [model_type 'Labelled'];

    %clear any pre-existing labelled data for the given model type
    app.movie_data.results.(model_label_field) = [];
    
    %copy over every track to the empty struct
    count = 1;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs,1)
            %write the LoColi tracks data to the LabelledMols struct
            app.movie_data.results.(model_label_field).LabelledMols{count,1}.Mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj), :);
            
            %update the labelled results substruct; a cell array of classifications performed by the user
            app.movie_data.results.(model_label_field).LabelledMols{count,1}.CellID = ii;
            app.movie_data.results.(model_label_field).LabelledMols{count,1}.MolID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj);
            app.movie_data.results.(model_label_field).LabelledMols{count,1}.EventSequence = 'pending';
            app.movie_data.results.(model_label_field).LabelledMols{count,1}.MoleculeDuration = size(app.movie_data.results.(model_label_field).LabelledMols{count,1}.Mol,1) / app.movie_data.params.frame_rate;      %in seconds; note that this current implementation does not factor in memory param; to be later replaced with calculation based on start-finish frame numbers as these are required for input file regardless of source data
            app.movie_data.results.(model_label_field).LabelledMols{count,1}.DateClassified = datestr(now, 'dd/mm/yy-HH:MM:SS');
            
            count = count + 1;
        end
    end
    
    %erase non-meaningful rows - temporarily disabled pending a future update to computeAnnotationMetrics to match the correct localisations during the metric calculations
    %cropTrajectories(app, [model_type '_labelled'], app.movie_data.models.(model_type).removed_rows(1,1), app.movie_data.models.(model_type).removed_rows(1,2));
    
    %find in the source data the columns that were used to train the model
    feature_cols = zeros(1, numel(app.movie_data.models.(model_type).feature_names));
    for ii = 1:numel(app.movie_data.models.(model_type).feature_names)
        idx = find(ismember(app.movie_data.params.column_titles.tracks, app.movie_data.models.(model_type).feature_names{ii}));
        
        %if the feature exists record it; otherwise exit and warn the user
        if ~isempty(idx)
            feature_cols(ii) = idx;
        else
            warndlg("The loaded model was trained on a feature (" + app.movie_data.models.(model_type).feature_names{ii} +") which does not exist in the source data. " + ...
                "If you believe this to be a mistake please check carefully, the spelling of column headers", "Unable to classify, feature not available", "modal");
            return;
        end
    end
    
    %===============================================================
    %Reformat data to a dlarray, apply feature scaling, and classify
    %===============================================================
    [data_dlarray, source_track] = reformatToDLArray(app.movie_data.results.(model_label_field).LabelledMols, app.movie_data.models.(model_type).max_len, feature_cols);

    %perform feature scaling (Z-score or min-max normalisation)
    scaled_data_dlarray = data_dlarray;

    %apply feature scaling
    switch app.movie_data.models.(model_type).feature_scaling
        case "None"
            %<< do nothing >>
        
        case "Z-score"
            %standardize each feature using Z-score
            for jj = 1:numel(feature_cols)
                mean_val = app.movie_data.models.(model_type).feature_means(jj);
                std_val = app.movie_data.models.(model_type).feature_stds(jj);
                scaled_data_dlarray(jj, :, :) = (scaled_data_dlarray(jj, :, :) - mean_val) / std_val;
            end
        
        case "Normalise (0-1)"
            %normalize each feature using min-max normalization
            for jj = 1:numel(feature_cols)
                min_val = app.movie_data.models.(model_type).feature_mins(jj);
                max_val = app.movie_data.models.(model_type).feature_maxs(jj);
                scaled_data_dlarray(jj, :, :) = (scaled_data_dlarray(jj, :, :) - min_val) / (max_val - min_val);
            end
        
        otherwise
            error('Unknown feature scaling method.');
    end
    
    tic
    %classify all tracks
    raw_scores = predict(app.movie_data.models.(model_type).model, scaled_data_dlarray);
    t = toc;
    
    %convert raw scores to probabilities
    probabilities = softmax(raw_scores);
    
    [tracks_cell_array] = computeConsensus(app.movie_data.results.(model_label_field).LabelledMols, probabilities, source_track);
    
    %write the results back to the original cell array
    app.movie_data.results.(model_label_field).LabelledMols = tracks_cell_array;

    %compute the event sequence
    for ii = 1:size(app.movie_data.results.(model_label_field).LabelledMols, 1)
        app.movie_data.results.(model_label_field).LabelledMols{ii,1}.EventSequence = condenseStateSequence(app.movie_data.results.(model_label_field).LabelledMols{ii,1}.Mol(:,end));
    end
    
    app.textout.Value = "Completed classification and segmentation of entire dataset using " + model_type + " model. Classification took " + num2str(t) +...
        " seconds, followed by consensus voting from overlapping windows, and the data has been reformatted for downstream analytics.";
end


function [tracks_cell_array] = computeConsensus(tracks_cell_array, probabilities, source_track)
%Compute the consensus scores for each localisation from scores in multiple
%windows, Oliver Pambos, 21/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeConsensus
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
%Computes a confidence score per class for every unqiue localisation from
%class probabilities as observed from multiple observations in different
%sliding windows, and writes this back into the cell array of annotations.
%
%Note that in the current form this effectively computes confidence as the
%mean of the prediction from all windows in which each localisation
%appears. However, it may be better to instead use median here to minimise
%the influence of outliers on the final prediction, which may be leading to
%some of the flickering of classes in model-annotated data.
%
%
%Input
%-----
%tracks_cell_array  (cell)      Nx1 cell array containing N tracks
%probabilities      (dlarray)   CxWxF dlarray of probabilties assigned to
%                                   each localisation in each window to
%                                   each class, with dimensions of,
%                                       C: number of classes
%                                       W: number of windows in dataset
%                                       F: number of features used by model
%source_track       (vec)       Wx1 column vector containing an int for
%                                   each classified window that holds the
%                                   original track index to which that
%                                   window belongs; this enables the
%                                   probabilities for each window to be
%                                   inserted re-assigned to the correct
%                                   track in the original cell array
%
%Output
%------
%tracks_cell_array  (cell)      Nx1 cell array containing N tracks, now
%                                   containing model annotations
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    f = waitbar(0,"Annotation complete for all track, studying consensus...");
    update_freq = 5;
    
    N_tracks    = max(source_track);
    window_size = size(probabilities, 3);
    N_classes   = size(probabilities, 1);
    
    %cell array to store final predictions and norm probabilities
    final_predictions_cell = cell(N_tracks, 1);
    
    for ii = 1:N_tracks
        %update waitbar every 5 tracks
        if mod(ii, update_freq) == 0
            waitbar(ii/N_tracks, f, "Classification complete, computing consensus annotations for track " + num2str(ii) + "/" + N_tracks);
        end
        
        %get section of array corresponding to current track
        track_window = find(source_track == ii);
        
        %get number of timepoints in the current track
        curr_track_len = size(tracks_cell_array{ii, 1}.Mol, 1);
        
        class_counts        = zeros(curr_track_len, N_classes);
        confidence_scores   = zeros(curr_track_len, N_classes);
        
        %loop over windows in the current track
        for jj = 1:length(track_window)
            window_idx = track_window(jj);
            
            %extract probs for window, and predict classes
            curr_probabilities = reshape(probabilities(:, window_idx, :), [N_classes, window_size]);
            [~, predicted_labels] = max(curr_probabilities, [], 1);
            
            %calc start and end indices for current window relative to track
            start_idx = window_idx - min(track_window) + 1;
            end_idx = start_idx + window_size - 1;
            
            %ensure indices don't exceed track length
            valid_indices = start_idx:end_idx;
            valid_indices = valid_indices(valid_indices <= curr_track_len);
            valid_timepoints = 1:length(valid_indices);
            
            %update confidence scores
            confidence_scores(valid_indices, :) = confidence_scores(valid_indices, :) + curr_probabilities(:, valid_timepoints)';
            
            %update class counts
            for tt = 1:length(valid_timepoints)
                timepoint_idx = valid_indices(tt);
                class_counts(timepoint_idx, predicted_labels(tt)) = class_counts(timepoint_idx, predicted_labels(tt)) + 1;
            end
        end
        
        window_counts = sum(class_counts, 2);
        
        %calc consensus annotation, and normalized probability for each timepoint
        final_predictions = zeros(curr_track_len, 2);
        for tt = 1:curr_track_len
            [~, consensus_label] = max(confidence_scores(tt, :));
            normalized_confidence = confidence_scores(tt, consensus_label) / sum(confidence_scores(tt, :));
            final_predictions(tt, 1) = consensus_label;
            final_predictions(tt, 2) = normalized_confidence;
        end
        
        %store the final predictions in cell array
        final_predictions_cell{ii} = final_predictions;
        tracks_cell_array{ii, 1}.Mol(:, end) = final_predictions(:, 1);
        tracks_cell_array{ii, 1}.consensus_prediction = [final_predictions, window_counts];
        tracks_cell_array{ii, 1}.confidence_scores = confidence_scores;
    end
    
    close(f);
end


function [data_dlarray, source_track] = reformatToDLArray(cell_array, window_size, feature_cols)
%Convert the cell array used to store tracks to be annotation into a matlab
%dlarray of sliding windows of those tracks, higher perfomance in
%classification, Oliver Pambos, 21/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: reformatToDLArray
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
%Converts the cell array in which the data is stored into a more efficient
%single dlarray for faster computation. This function also splits the
%tracks into windows such that the returned dlarray contains all of the
%windows for the dataset to be annotated. Finally, it also returns the
%vector 'source_track', which is a list of indices which keeps track of
%which slides in the dlarray correspond to which track, enabling the
%annotations to be correctly reassembled inside the original cell array
%after model classification.
%
%
%Input
%-----
%cell_array     (cell)  Nx1 cell array containing N tracks, where each
%                           cell contains a single track to be
%                           annotated
%window_size    (int)   size of each window used to break up tracks
%feature_cols   (vec)   row vector of column IDs of features to be used for
%
%
%Output
%------
%data_dlarray   (dlarray)   CxBxT dlarray containing all of the windowed
%                               data to be classified
%%source_track  (vec)       Mx1 column vector of ints which identify the
%                               original track to which each of the M windows
%                               (i.e. each slice of data_dlarray) correspond
%                               to; this enables annotations to be written back
%                               correctly to each track.
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_tracks    = length(cell_array);
    N_features  = length(feature_cols);
    
    %calc total number of windows
    total_windows = 0;
    for ii = 1:N_tracks
        curr_track = cell_array{ii, 1}.Mol;
        N_timepoints = size(curr_track, 1);
        total_windows = total_windows + (N_timepoints - window_size + 1);
    end
    
    data_array   = zeros(N_features, total_windows, window_size, 'single');  %dimensions 'CBT' format
    source_track = zeros(total_windows, 1);
    
    %fill array and source_track
    window_idx = 1;
    for ii = 1:N_tracks
        curr_track = cell_array{ii, 1}.Mol;
        N_timepoints = size(curr_track, 1);
        
        %extract relevant features
        curr_track = curr_track(:, feature_cols);
        
        for start_idx = 1:(N_timepoints - window_size + 1)
            end_idx = start_idx + window_size - 1;
            
            %extract window, and insert into array
            window_data = curr_track(start_idx:end_idx, :)';
            data_array(:, window_idx, :) = window_data;
            source_track(window_idx) = ii;
            
            window_idx = window_idx + 1;
        end
    end
    
    %convert to dlarray with (class [feature], batch, time) format
    data_dlarray = dlarray(data_array, 'CBT');
end