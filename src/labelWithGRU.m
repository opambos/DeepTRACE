function [] = labelWithGRU(app)
%Label the entire loaded dataset using a pre-trained GRU model, 28/04/2023.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
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
    
    %clear any pre-existing GRU labelled data
    app.movie_data.results.GRULabelled = [];
    
    %copy over every track to the empty struct
    count = 1;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs,1)
            %write the LoColi tracks data to the LabelledMols struct
            app.movie_data.results.GRULabelled.LabelledMols{count,1}.Mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj), :);
            
            %update the GRULabelled results substruct; a cell array of classifications performed by the user
            app.movie_data.results.GRULabelled.LabelledMols{count,1}.CellID = ii;
            app.movie_data.results.GRULabelled.LabelledMols{count,1}.MolID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj);
            app.movie_data.results.GRULabelled.LabelledMols{count,1}.EventSequence = 'pending';
            app.movie_data.results.GRULabelled.LabelledMols{count,1}.MoleculeDuration = size(app.movie_data.results.GRULabelled.LabelledMols{count,1}.Mol,1) / app.movie_data.params.frame_rate;      %in seconds; note that this current implementation does not factor in memory param; to be later replaced with calculation based on start-finish frame numbers as these are required for input file regardless of source data
            app.movie_data.results.GRULabelled.LabelledMols{count,1}.DateClassified = datestr(now, 'dd/mm/yy-HH:MM:SS');
            
            count = count + 1;
        end
    end
    
    %erase non-meaningful rows
    cropTrajectories(app, "GRU_labelled", app.movie_data.models.GRU.removed_rows(1,1), app.movie_data.models.GRU.removed_rows(1,2));
    
    %find in the source data the columns that were used to train the model
    feature_cols = zeros(1, numel(app.movie_data.models.GRU.feature_names));
    for ii = 1:numel(app.movie_data.models.GRU.feature_names)
        idx = find(ismember(app.movie_data.params.column_titles.tracks, app.movie_data.models.GRU.feature_names{ii}));
        
        %if the feature exists record it; otherwise exit and warn the user
        if ~isempty(idx)
            feature_cols(ii) = idx;
        else
            warndlg("The loaded model was trained on a feature (" + app.movie_data.models.GRU.feature_names{ii} +") which does not exist in the source data. " + ...
                "If you believe this to be a mistake please check carefully, the spelling of column headers", "Unable to classify, feature not available", "modal");
            return;
        end
    end
    
    %initialise a progress bar
    %f = waitbar(0,"Labelling the entire loaded dataset using Gated Recurrent Unit (GRU) model...");
    
    tic
    
    %loop over all molecules
    for ii = 1:size(app.movie_data.results.GRULabelled.LabelledMols, 1)
        
        %apply feature scaling
        switch app.movie_data.models.GRU.feature_scaling
            case "None"
                % << do nothing >>
                
            case "Z-score"
                %standardize each feature in the current track using Z-score
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) - app.movie_data.models.GRU.feature_means(jj)) / app.movie_data.models.GRU.feature_stds(jj);
                end
                
            case "Normalise (0-1)"
                %normalise each feature in the current track using min-max normalisation
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) - app.movie_data.models.GRU.feature_mins(jj)) / (app.movie_data.models.GRU.feature_maxs(jj) - app.movie_data.models.GRU.feature_mins(jj));
                end
                
            otherwise
            
        end
        
        %extract columns of features to classify
        curr_track = app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols);
        
        %add padding feature column
        curr_track = [curr_track, ones(size(curr_track, 1), 1)];
        
        %ensure track is same length as model input layer; pad or crop
        if size(curr_track, 1) <app.movie_data.models.GRU.max_len
            padding = zeros(app.movie_data.models.GRU.max_len - size(curr_track, 1), size(curr_track, 2));
            curr_track = [curr_track; padding];
        elseif size(curr_track, 1) > app.movie_data.models.GRU.max_len
            curr_track = curr_track(1:app.movie_data.models.GRU.max_len, :);
        end
        
        %transpose and predict labels with model
        curr_track = curr_track';
        
        %predict labels using GRU model
        label_sequence = classify(app.movie_data.models.GRU.model, curr_track);

        %crop labels to non-padded region using padded mask feature
        label_sequence = label_sequence(curr_track(end, :) == 1);
        
        %convert from categorical to numeric
        label_sequence = str2double(cellstr(label_sequence));

        %write labels back into GRULabelled results struct
        app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:,end) = double(label_sequence');
        
        %invert scaling transform
        switch app.movie_data.models.GRU.feature_scaling
            case "None"
                % << do nothing >>
                
            case "Z-score"
                %standardize each feature in the current track using Z-score
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) * app.movie_data.models.GRU.feature_stds(jj)) + app.movie_data.models.GRU.feature_means(jj);
                end
                
            case "Normalise (0-1)"
                %normalise each feature in the current track using min-max normalisation
                for jj = 1:size(feature_cols,2)
                    app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) =...
                        (app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(:, feature_cols(jj)) * (app.movie_data.models.GRU.feature_maxs(jj) - app.movie_data.models.GRU.feature_mins(jj))) + app.movie_data.models.GRU.feature_mins(jj);
                end
                
            otherwise
            
        end
        
       %waitbar(ii/size(app.movie_data.results.RFLabelled.LabelledMols, 1), f, "Classificaiton complete for " + num2str(ii) + "/" + num2str(size(app.movie_data.results.RFLabelled.LabelledMols, 1)) + " trajectories");
    end
    
    t = toc;
    app.textout.Value = "Completed classification and segmentation of entire dataset using Gated Recurrent Unit model in " + num2str(t) + " seconds";
    %close(f);
end