function [] = labelWithBiLSTM(app)
%Label the entire loaded dataset using a pre-trained BiLSTM model, Oliver
%Pambos, 11/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: labelWithBiLSTM
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
%This function temporarily replicates the function labelWithLSTM() for
%testing during development until they are merged in a future update.
%
%Uses a pre-trained model to classify the data. This function begins by
%first generating a new copy of the source data to ensure the data is
%uncorrupted by any other actions performed during runtime. Currently
%trajectory cropping is hardcoded and favoured over imputation, so the
%newly copied trajectories do not contain the irrelevant steps at their
%start and end. The selected features will be scaled using the same feature
%scaling method used during feature scaling of the source data.
%
%Note that labelling with an pre-trained model requires all of the features
%used to train the original model to exist in the data being labelled;
%specifically the string literal of each feature must be identical to that
%used in training.
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
    
    %clear any pre-existing BiLSTM labelled data
    app.movie_data.results.BiLSTMLabelled = [];
    
    %copy over every track to the empty struct
    count = 1;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs,1)
            %write the LoColi tracks data to the LabelledMols struct
            app.movie_data.results.BiLSTMLabelled.LabelledMols{count,1}.Mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj), :);
            
            %update the BiLSTMLabelled results substruct; a cell array of classifications performed by the user
            app.movie_data.results.BiLSTMLabelled.LabelledMols{count,1}.CellID = ii;
            app.movie_data.results.BiLSTMLabelled.LabelledMols{count,1}.MolID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj);
            app.movie_data.results.BiLSTMLabelled.LabelledMols{count,1}.EventSequence = 'pending';
            app.movie_data.results.BiLSTMLabelled.LabelledMols{count,1}.MoleculeDuration = size(app.movie_data.results.BiLSTMLabelled.LabelledMols{count,1}.Mol,1) / app.movie_data.params.frame_rate;      %in seconds; note that this current implementation does not factor in memory param; to be later replaced with calculation based on start-finish frame numbers as these are required for input file regardless of source data
            app.movie_data.results.BiLSTMLabelled.LabelledMols{count,1}.DateClassified = datestr(now, 'dd/mm/yy-HH:MM:SS');
            
            count = count + 1;
        end
    end
    
    %erase non-meaningful rows
    cropTrajectories(app, "BiLSTM_labelled", app.movie_data.models.BiLSTM.removed_rows(1,1), app.movie_data.models.BiLSTM.removed_rows(1,2));
    
    %find in the source data the columns that were used to train the model
    feature_cols = zeros(1, numel(app.movie_data.models.BiLSTM.feature_names));
    for ii = 1:numel(app.movie_data.models.BiLSTM.feature_names)
        idx = find(ismember(app.movie_data.params.column_titles.tracks, app.movie_data.models.BiLSTM.feature_names{ii}));
        
        %if the feature exists record it; otherwise exit and warn the user
        if ~isempty(idx)
            feature_cols(ii) = idx;
        else
            warndlg("The loaded model was trained on a feature (" + app.movie_data.models.BiLSTM.feature_names{ii} +") which does not exist in the source data. " + ...
                "If you believe this to be a mistake please check carefully, the spelling of column headers", "Unable to classify, feature not available", "modal");
            return;
        end
    end
    
    %initialise a progress bar
    %f = waitbar(0,"Labelling the entire loaded dataset using Bidirectional Long Short-Term Memory (BiLSTM) model...");
    
    tic
    
    %loop over all molecules
    for ii = 1:size(app.movie_data.results.BiLSTMLabelled.LabelledMols, 1)
        
        %apply feature scaling
        switch app.movie_data.models.BiLSTM.feature_scaling
            case "None"
                % << do nothing >>
                
            case "Z-score"
                %standardize each feature in the current track using Z-score
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) - app.movie_data.models.BiLSTM.feature_means(jj)) / app.movie_data.models.BiLSTM.feature_stds(jj);
                end
                
            case "Normalise (0-1)"
                %normalise each feature in the current track using min-max normalisation
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) - app.movie_data.models.BiLSTM.feature_mins(jj)) / (app.movie_data.models.BiLSTM.feature_maxs(jj) - app.movie_data.models.BiLSTM.feature_mins(jj));
                end
                
            otherwise
            
        end
        
        %extract columns of features to classify
        curr_track = app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols);
        
        %add padding feature column
        curr_track = [curr_track, ones(size(curr_track, 1), 1)];
        
        %ensure track is same length as model input layer; pad or crop
        if size(curr_track, 1) <app.movie_data.models.BiLSTM.max_len
            padding = zeros(app.movie_data.models.BiLSTM.max_len - size(curr_track, 1), size(curr_track, 2));
            curr_track = [curr_track; padding];
        elseif size(curr_track, 1) > app.movie_data.models.BiLSTM.max_len
            curr_track = curr_track(1:app.movie_data.models.BiLSTM.max_len, :);
        end
        
        %transpose and predict labels with model
        curr_track = curr_track';
        
        %predict labels using BiLSTM model
        label_sequence = classify(app.movie_data.models.BiLSTM.model, curr_track);

        %crop labels to non-padded region using padded mask feature
        label_sequence = label_sequence(curr_track(end, :) == 1);
        
        %convert from categorical to numeric
        label_sequence = str2double(cellstr(label_sequence));

        %write labels back into BiLSTMLabelled results struct
        app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:,end) = double(label_sequence');
        
        %invert scaling transform
        switch app.movie_data.models.BiLSTM.feature_scaling
            case "None"
                % << do nothing >>
                
            case "Z-score"
                %standardize each feature in the current track using Z-score
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) * app.movie_data.models.BiLSTM.feature_stds(jj)) + app.movie_data.models.BiLSTM.feature_means(jj);
                end
                
            case "Normalise (0-1)"
                %normalise each feature in the current track using min-max normalisation
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.BiLSTMLabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) * (app.movie_data.models.BiLSTM.feature_maxs(jj) - app.movie_data.models.BiLSTM.feature_mins(jj))) + app.movie_data.models.BiLSTM.feature_mins(jj);
                end
                
            otherwise
            
        end

       %waitbar(ii/size(app.movie_data.results.RFLabelled.LabelledMols, 1), f, "Classificaiton complete for " + num2str(ii) + "/" + num2str(size(app.movie_data.results.RFLabelled.LabelledMols, 1)) + " trajectories");
    end
    
    t = toc;
    app.textout.Value = "Completed classification and segmentation of entire dataset using BiLSTM model in " + num2str(t) + " seconds";
    %close(f);
end
