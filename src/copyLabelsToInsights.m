function [success] = copyLabelsToInsights(app)
%Copies the relevant source of labels to the `insights` substruct for
%analysis, Oliver Pambos, 07/03/2024.
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
%This function copies an entire labelled dataset into a dedicated substruct
%(`InsightData`), providing a stable location for data to be analysed.
%Operating on a consistent data struct greatly simplifies the organisation
%of downstream analysis code, and enables additional models and data
%labelling methods to be later incorporated into the InVivoKinetics
%codebase.
%
%The labelled data to copy into the `InsightData` struct is determined by
%the GUI component `app.InsightsSourcedataDropDown`.
%
%Input
%-----
%app        (handle)    main GUI handle
%
%Output
%------
%success    (bool)      true only if labelled data substruct successfully
%                           copied to InsightData substruct; else false
%app        (handle)    main GUI handle, now containing a copy of the relevant
%                           data labels in the `InsightData` substrct (not
%                           passed by value)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None    
    
    success = false;
    
    if ~isfield(app.movie_data, "results")
        return;
    elseif isfield(app.movie_data.results, "InsightData")
        app.movie_data.results  = rmfield(app.movie_data.results, 'InsightData');
    end
    
    %copy selected labelled dataset to the `InsightData` substruct; if this is not found,
    %execute the dropdown callback to make sure the options available to the user in the app is up to date
    switch app.InsightsSourcedataDropDown.Value
        case "Human annotations"
            if isfield(app.movie_data.results, "VisuallyLabelled")
                app.movie_data.results.InsightData = app.movie_data.results.VisuallyLabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select a different data source from the dropdown menu.";
                %app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Ground truth"
            if isfield(app.movie_data.results, "GroundTruth")
                app.movie_data.results.InsightData = app.movie_data.results.GroundTruth;
            else
                app.textout.Value = "The selected dataset is no longer available, please select a different data source from the dropdown menu.";
                %app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from RF"
            if isfield(app.movie_data.results, "RFLabelled")
                app.movie_data.results.InsightData = app.movie_data.results.RFLabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select a different data source from the dropdown menu.";
                %app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from LSTM"
            if isfield(app.movie_data.results, "LSTMLabelled")
                app.movie_data.results.InsightData = app.movie_data.results.LSTMLabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select a different data source from the dropdown menu.";
                %app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from BiLSTM"
            if isfield(app.movie_data.results, "BiLSTMLabelled")
                app.movie_data.results.InsightData = app.movie_data.results.BiLSTMLabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select a different data source from the dropdown menu.";
                %app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from GRU"
            if isfield(app.movie_data.results, "GRULabelled")
                app.movie_data.results.InsightData = app.movie_data.results.GRULabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select a different data source from the dropdown menu.";
                %app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from BiGRU"
            if isfield(app.movie_data.results, "BiGRULabelled")
                app.movie_data.results.InsightData = app.movie_data.results.BiGRULabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select a different data source from the dropdown menu.";
                %app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from ResAnDi2"
            if isfield(app.movie_data.results, "ResAnDi")
                app.movie_data.results.InsightData = app.movie_data.results.ResAnDi;
            else
                app.textout.Value = "The selected dataset is no longer available, please select a different data source from the dropdown menu.";
                %app.InsightsSourcedataDropDownOpening(app, []);
            end
        otherwise
            app.textout.Value = "No data is available to compute insights";
    end
    
    
    if isfield(app.movie_data.results, "InsightData") && ~isempty(app.movie_data.results.InsightData)
        %if user restricts model stats to only those which have human annotations, then delete other mols from Insights
        if app.StatsoverlapCheckBox.Value && ~strcmp(app.InsightsSourcedataDropDown.Value, "Human annotations") && isfield(app.movie_data.results, 'VisuallyLabelled')
            
            %extract unique CellID_MolID from VisuallyLabelled that have usable data
            vis_labelled_data = app.movie_data.results.VisuallyLabelled.LabelledMols;
            N_vis_labelled = size(vis_labelled_data, 1);
            
            usable_IDs = [];
            for ii = 1:N_vis_labelled
                if all(vis_labelled_data{ii}.Mol(:, end) ~= -1)
                    usable_IDs = [usable_IDs; vis_labelled_data{ii}.CellID, vis_labelled_data{ii}.MolID];
                end
            end
            
            usable_IDs = unique(usable_IDs, 'rows');
            
            %sort through InsightData removing invalid entries
            insight_data = app.movie_data.results.InsightData.LabelledMols;
            N_insight_data = size(insight_data, 1);
            
            %loop backwards when deleting entries
            for ii = N_insight_data : -1 : 1
                if ~ismember([insight_data{ii}.CellID, insight_data{ii}.MolID], usable_IDs, 'rows')
                    app.movie_data.results.InsightData.LabelledMols(ii) = [];
                end
            end

        end
        success = true;
    end
end