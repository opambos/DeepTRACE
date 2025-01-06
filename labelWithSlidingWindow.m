function [] = labelWithSlidingWindow(app, model_type)
%Label the entire loaded dataset with a pre-trained model in sections
%using a sliding window, Oliver Pambos, 02/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: labelWithSlidingWindow
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
    
    app.movie_data.results.(model_label_field).annotation_time = t;
end