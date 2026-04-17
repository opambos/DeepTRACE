function [] = labelWithRF(app)
%Label the entire loaded dataset using the currently loaded random forest
%model, Oliver Pambos, 14/12/2023.
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
%Every trajectory is copied from the unlabelled source data to the RF
%labelled substruct. The currently loaded random forest model is then used
%to classify all steps in the loaded dataset using features selected by the
%user. The model is able to handle temporal information via feature
%engineering to include for each step past and future information for key
%features such as step size.
%
%To overcome issues of missing values and to enable every datapoint to be
%used the code imputes sensible values. For example the previous step size
%does not exist in the first frame, so the code copies over the next
%available step size as this produces a lower impact on the resulting
%classification than a zero value. Currently, during development, this
%processes is temporarily hardcoded for simplicity of testing, but will be
%replaced with a more robust solution once testing is complete.
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
%None
    
    %clear any pre-existing RF labelled data
    app.movie_data.results.RFLabelled = [];
    
    %copy over every track to the results struct
    count = 1;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs,1)
            %write the LoColi tracks data to the LabelledMols struct
            app.movie_data.results.RFLabelled.LabelledMols{count,1}.Mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj), :);
            
            %update the RFLabelled results substruct; a cell array of classifications performed by the user
            app.movie_data.results.RFLabelled.LabelledMols{count,1}.CellID = ii;
            app.movie_data.results.RFLabelled.LabelledMols{count,1}.MolID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj);
            app.movie_data.results.RFLabelled.LabelledMols{count,1}.EventSequence = 'pending';
            app.movie_data.results.RFLabelled.LabelledMols{count,1}.MoleculeDuration = size(app.movie_data.results.RFLabelled.LabelledMols{count}.Mol,1) / app.movie_data.params.frame_rate;      %in seconds
            app.movie_data.results.RFLabelled.LabelledMols{count,1}.DateClassified = datestr(now, 'dd/mm/yy-HH:MM:SS');
            
            count = count + 1;
        end
    end
    
    %find in the source data the columns that were used to train the model
    feature_cols = zeros(1, numel(app.movie_data.models.RF.feature_names));
    for ii = 1:numel(app.movie_data.models.RF.feature_names)
        idx = find(ismember(app.movie_data.params.column_titles.tracks, app.movie_data.models.RF.feature_names{ii}));
        
        %if the feature exists record it; otherwise exit and warn the user
        if ~isempty(idx)
            feature_cols(ii) = idx;
        else
            warndlg("The loaded model was trained on a feature (" + app.movie_data.models.RF.feature_names{ii} +") which does not exist in the source data. " + ...
                "If you believe this to be a mistake please check carefully, the spelling of column headers", "Unable to classify, feature not available", "modal");
            return;
        end
    end
    
    %initialise a progress bar
    f = waitbar(0,"Labelling the entire loaded dataset using Random Forest model...");
    
    tic
    %loop over all molecules
    for ii = 1:size(app.movie_data.results.RFLabelled.LabelledMols, 1)
        %extract data from the relevant features to classify
        curr_track = app.movie_data.results.RFLabelled.LabelledMols{ii}.Mol(:, feature_cols);
        
        % %use imputation to replace any missing lagged step sizes with copies of the current step size;
        % %currently hardcoded; to be replaced in a future version with dynamic imputation controlled by the user control and features present
        % if any(app.movie_data.model_params.current_feature_cols == 24)
        %     col_to_fix = find(app.movie_data.model_params.current_feature_cols == 24, 1);
        %     curr_track(1:3, col_to_fix) = curr_track(4, col_to_fix);
        % end
        % if any(app.movie_data.model_params.current_feature_cols == 21)
        %     col_to_fix = find(app.movie_data.model_params.current_feature_cols == 21, 1);
        %     curr_track(1:2, col_to_fix) = curr_track(3, col_to_fix);
        % end
        % if any(app.movie_data.model_params.current_feature_cols == 19)
        %     col_to_fix = find(app.movie_data.model_params.current_feature_cols == 19, 1);
        %     curr_track(1, col_to_fix) = curr_track(2, col_to_fix);
        % end
        % if any(app.movie_data.model_params.current_feature_cols == 15)
        %     col_to_fix = find(app.movie_data.model_params.current_feature_cols == 15, 1);
        %     curr_track(1, col_to_fix) = curr_track(2, col_to_fix);
        % end
        
        %predict using the model
        predictions = str2double(app.movie_data.models.RF.model.predict(curr_track));
        
        %write predictions to RF labelled data
        app.movie_data.results.RFLabelled.LabelledMols{ii}.Mol(:,end) = predictions;
        
        waitbar(ii/size(app.movie_data.results.RFLabelled.LabelledMols, 1), f, "Classificaiton complete for " + num2str(ii) + "/" + num2str(size(app.movie_data.results.RFLabelled.LabelledMols, 1)) + " trajectories");
    end
    
    t=toc;
    app.textout.Value = "Completed classification and segmentation of entire dataset using random forest model in " + num2str(t) + " seconds";
    close(f);
end