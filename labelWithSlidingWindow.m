function [] = labelWithSlidingWindow(app, model_type)
%Label the entire loaded dataset with a pre-trained model in sections
%using a sliding window, Oliver Pambos, 02/02/2024.
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
%To handle memory more robustly on specific hardware configurations, a
%temporary change has been made to evaluation which involves two additional
%matrix/dlarray conversions and evaluation in chunks, which substantially
%slows evaluation.
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
%computeConsensus()
%reformatToDLArray()
    
    %construct a dynamic field name, enabling this code to work with any model type
    model_label_field = [model_type 'Labelled'];

    %clear any pre-existing labelled data for the given model type
    app.movie_data.results.(model_label_field) = [];
    
    %single access of timestamp and frame rate
    timestamp_str   = datestr(now, 'dd/mm/yy-HH:MM:SS');
    frame_rate      = app.movie_data.params.frame_rate;
    
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
            app.movie_data.results.(model_label_field).LabelledMols{count,1}.MoleculeDuration = size(app.movie_data.results.(model_label_field).LabelledMols{count,1}.Mol,1) / frame_rate;      %in seconds; note that this current implementation does not factor in memory param; to be later replaced with calculation based on start-finish frame numbers as these are required for input file regardless of source data
            app.movie_data.results.(model_label_field).LabelledMols{count,1}.DateClassified = timestamp_str;
            
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
    
    %=================================================================
    %Temporary implementation of classification: dlarray to matrix
    %conversion and evaluation in small chunks introduces significant
    %overhead but handles memory allocation issues on certain hardware
    %configurations - increases runtime from ~900 ms to ~20 s
    %=================================================================
    tic
    %classify all tracks
    % raw_scores = predict(app.movie_data.models.(model_type).model, scaled_data_dlarray);
    
    %extract matrix from dlarray
    scaled_data_matrix  = extractdata(scaled_data_dlarray);
    B                   = size(scaled_data_matrix, 2);
    max_batch_size      = 10000;
    
    if B <= max_batch_size
        %process all results in one operation
        raw_scores = predict(app.movie_data.models.(model_type).model, dlarray(scaled_data_matrix, 'CBT'));
    else
        %too large; process in chunks
        N_chunks            = ceil(B / max_batch_size);
        raw_scores_chunks   = cell(1, N_chunks);
        h_wait              = waitbar(0, sprintf('Processing batch 0/%d', N_chunks));
        
        for ii = 1:N_chunks
            %extract matrix batch and convert to dlarray for prediction
            start_idx   = (ii - 1) * max_batch_size + 1;
            end_idx     = min(ii * max_batch_size, B);
            
            waitbar(ii/N_chunks, h_wait, sprintf('Processing batch %d/%d: [%d to %d]', ii, N_chunks, start_idx, end_idx));
            
            batch_dlarray = dlarray(scaled_data_matrix(:, start_idx:end_idx, :), 'CBT');
            raw_scores_chunks{ii} = predict(app.movie_data.models.(model_type).model, batch_dlarray);
        end
        
        %reconstruct raw_scores
        raw_scores = cat(2, raw_scores_chunks{:});
    end
    
    t = toc;
    close(h_wait);
    
    %convert raw scores to probabilities
    probabilities = softmax(raw_scores);
    
    [tracks_cell_array] = computeConsensus(app.movie_data.results.(model_label_field).LabelledMols, probabilities, source_track);
    
    %write the results back to the original cell array
    app.movie_data.results.(model_label_field).LabelledMols = tracks_cell_array;

    %compute the event sequence
    for ii = 1:size(app.movie_data.results.(model_label_field).LabelledMols, 1)
        app.movie_data.results.(model_label_field).LabelledMols{ii,1}.EventSequence = condenseStateSequence(app.movie_data.results.(model_label_field).LabelledMols{ii,1}.Mol(:,end));
    end
    
    app.movie_data.results.(model_label_field).annotation_time = t;
end