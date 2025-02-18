function [] = discoverRelationships(app)
%Discover relationships in any feature not used by model, Oliver Pambos,
%15/02/2025.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: discoverRelationships
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
%This function is part of the Discovery mode system; it attempts to find
%relationships in model-classified data between features unused by the
%model, and the assigned classes. This enables it to find and notify to the
%user relationships in features they had not expected, and behaviours that
%do not even exist in the training data.
%
%The function operates by first performing Pearson correlation to eliminate
%features that are linearly correlated to those in the model used for
%classification, it then computes the mutual information (MI) between each
%of the remaining (non-redundant) unused features and the classifications,
%ranking them by feature-class MI with adaptive binning. The user is able
%to set in the GUI thresholds for both correlation and MI. The results are
%displayed visually, and in the form of text.
%
%Important note for future development: the feature names are collected
%from the last model to be loaded of the same type as was used to annotate
%the data, however this could cause an error if say the user classified
%data with say a BiLSTM model, then laoded a new BiLSTM model but didn't
%classify with it before running discovery mode, as discovery mode would
%use the feature names from the latter loaded model, not the one used to do
%the classification. The solution is to update the classification process
%to store the features used with the classified data, i.e. in
%app.movie_data.results.(model)Labelled.feature_names, and then update this
%function to read the feature names from there. This would also simplify
%the code a little. This affects the local function importAnnotationData().
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
%concatTracks()
%computeMIScoresFeatureVsClass()
%importAnnotationData()             - local to this .m file
%plotDiscoveryResults()             - local to this .m file
    
    %bins using adaptive binning - hardcoded as suitable for a wide range of typical tracking data
    N_bins = 25;
    
    %obtain thresholds from GUI for redundancy (e.g., |r| > 0.9 is highly correlated), and MI
    redundancy_thresh   = app.DiscoveryRedundancythresholdSpinner.Value;
    MI_thresh           = app.MutualinformationthresholdSpinner.Value;
    
    %get user-requested data, and names of features used by model
    [track_data, used_features] = importAnnotationData(app);
    
    %find the column indices of all unused features
    unused_features                             = setdiff(app.movie_data.params.column_titles.tracks(:, 1:end-1), used_features, 'stable');
    [used_idx_cell{1:numel(used_features)}]     = findColumnIdx(app.movie_data.params.column_titles.tracks, used_features{:});
    [unused_idx_cell{1:numel(unused_features)}] = findColumnIdx(app.movie_data.params.column_titles.tracks, unused_features{:});
    
    %converting indices to vectors
    used_idx   = cell2mat(used_idx_cell);
    unused_idx = cell2mat(unused_idx_cell);
    
    %concat the tracks and labels into single matrix/vector
    [feature_data, class_labels] = concatTracks(track_data);
    
    %compute Pearson correlation between unused and used features
    feature_correlation = corr(feature_data(:, unused_idx), feature_data(:, used_idx));
    
    %gen mask of redundant features
    redundant_mask = any(abs(feature_correlation) > redundancy_thresh, 2);
    
    %compute MI for all unused features
    MI_full = computeMIScoresFeatureVsClass(feature_data, class_labels, unused_features, app.movie_data.params.column_titles.tracks, N_bins);
    
    %store the subset of non-redundant features, and corresponding MI scores
    filtered_unused_features    = unused_features(~redundant_mask);
    filtered_MI                 = MI_full(~redundant_mask);
    
    %exit if everything redundant
    if isempty(filtered_unused_features)
        app.textout.Value = "No non-redundant unused features found, the search for unknown correlations was not carried out as there are no viable features to study. "...
            + newline + "It is likely tthat the redudancy threshold is too low, you can try increasing this and repeating the process.";
        warndlg('No non-redundant unused features found.', 'Discovery Mode');
        return;
    end
    
    %gather correct results subset for user-requested plotting style
    switch app.DiscoveryDisplayDropDown.Value
        case 'All unused features'
            selected_features   = unused_features;
            selected_MI         = MI_full;
            
        case 'All non-redundant features above MI threshold'
            selected_features   = filtered_unused_features(filtered_MI >= MI_thresh);
            selected_MI         = filtered_MI(filtered_MI >= MI_thresh);
            
        case 'All non-redundant features'
            selected_features   = filtered_unused_features;
            selected_MI         = filtered_MI;
            
        otherwise
            warndlg("Unknown display options, please select a valid option from the [Display] dropdown box", "Unknown display option");
            return;
    end
    
    if isempty(selected_features)
        warndlg('No unexpected relationships found in unused features.', 'Discovery Mode');
        return;
    end
    
    %identify predictive features
    highlight_mask = selected_MI >= MI_thresh;
    
    %sort features by MI
    [sorted_MI, rank_idx]   = sort(selected_MI, 'descend');
    sorted_features         = selected_features(rank_idx);
    sorted_highlight_mask   = highlight_mask(rank_idx);
    
    %===========================================================
    %Plot and report identified relationships in unused features
    %===========================================================
    plotDiscoveryResults(app, sorted_MI, sorted_features, sorted_highlight_mask);
    
    %gather data
    valid_idx       = sorted_MI >= MI_thresh;
    final_features  = sorted_features(valid_idx);
    final_MI_scores = sorted_MI(valid_idx);
    
    %display all identified relationships in pop-up
    if isempty(final_features)
        warndlg("No unexplained feature relationships found.", "Discovery Mode");
    else
        result_str = sprintf('Relationships identified in features not used by model:\n\n');
        for ii = 1:numel(final_features)
            result_str = sprintf('%s- %s (MI = %.3f)\n', result_str, final_features{ii}, final_MI_scores(ii));
        end
        msgbox(result_str, 'Discovery Mode Results');
    end
end


function [track_data, used_features] = importAnnotationData(app)
%Obtains track data classified by model requested by user, and feature
%names used by the model to classify, Oliver Pambos, 15/02/2025.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: importAnnotationData
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
%Important note for future development: the feature names are collected
%from the last model to be loaded of the same type as was used to annotate
%the data, however this could cause an error if say the user classified
%data with say a BiLSTM model, then laoded a new BiLSTM model but didn't
%classify with it before running discovery mode, as discovery mode would
%use the feature names from the latter loaded model, not the one used to do
%the classification. The solution is to update the classification process
%to store the features used with the classified data, i.e. in
%app.movie_data.results.(model)Labelled.feature_names, and then update this
%function to read the feature names from there. This would also simplify
%the code a little.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%track_data     (cell)  Nx1 cell array of all N tracks data classified by
%                           model
%used_features  (cell)  1xM cell array of names of all features used by
%                           model
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %get data from correct source
    switch app.DiscoverySourceDataDropDown.Value
        case 'Labels from RF'
            if isprop(app, "movie_data") && isfield(app.movie_data, "results") && ...
                    isfield(app.movie_data.results, "RFLabelled") && isfield(app.movie_data.results.RFLabelled, "LabelledMols")
                track_data = app.movie_data.results.RFLabelled.LabelledMols;
            else
                app.textout.Value = "Discovery mode did not run as random forest model-annotated data does not exist. Please ensure you have classified the loaded dataset with a random forest model first.";
                warndlg("Discovery mode did not run as random forest model-annotated data does not exist. Please ensure you have classified the loaded dataset with a random forest model first.", "Annotations not available");
                return;
            end
            if isprop(app, "movie_data") && isfield(app.movie_data, "models") && ...
                    isfield(app.movie_data.models, "RF") && isfield(app.movie_data.models.RF, "feature_names")
                used_features = app.movie_data.models.RF.feature_names;
            else
                app.textout.Value = "Discovery mode did not run as the loaded random forest model either is not correctly loaded or saved in this file. Please ensure you have classified the loaded dataset with a random forest model first.";
                warndlg("Discovery mode did not run as the random forest model is not properly loaded.", "Model details not available");
                return;
            end
            
        case 'Labels from LSTM'
            if isprop(app, "movie_data") && isfield(app.movie_data, "results") && ...
                    isfield(app.movie_data.results, "LSTMLabelled") && isfield(app.movie_data.results.LSTMLabelled, "LabelledMols")
                track_data = app.movie_data.results.LSTMLabelled.LabelledMols;
            else
                app.textout.Value = "Discovery mode did not run as LSTM model-annotated data does not exist. Please ensure you have classified the loaded dataset with an LSTM model first.";
                warndlg("Discovery mode did not run as LSTM model-annotated data does not exist. Please ensure you have classified the loaded dataset with an LSTM model first.", "Annotations not available");
                return;
            end
            if isprop(app, "movie_data") && isfield(app.movie_data, "models") && ...
                    isfield(app.movie_data.models, "LSTM") && isfield(app.movie_data.models.LSTM, "feature_names")
                used_features = app.movie_data.models.LSTM.feature_names;
            else
                app.textout.Value = "Discovery mode did not run as the loaded LSTM model either is not correctly loaded or saved in this file. Please ensure you have classified the loaded dataset with an LSTM model first.";
                warndlg("Discovery mode did not run as the LSTM model is not properly loaded.", "Model details not available");
                return;
            end
            
        case 'Labels from BiLSTM'
            if isprop(app, "movie_data") && isfield(app.movie_data, "results") && ...
                    isfield(app.movie_data.results, "BiLSTMLabelled") && isfield(app.movie_data.results.BiLSTMLabelled, "LabelledMols")
                track_data = app.movie_data.results.BiLSTMLabelled.LabelledMols;
            else
                app.textout.Value = "Discovery mode did not run as BiLSTM model-annotated data does not exist. Please ensure you have classified the loaded dataset with a BiLSTM model first.";
                warndlg("Discovery mode did not run as BiLSTM model-annotated data does not exist. Please ensure you have classified the loaded dataset with a BiLSTM model first.", "Annotations not available");
                return;
            end
            if isprop(app, "movie_data") && isfield(app.movie_data, "models") && ...
                    isfield(app.movie_data.models, "BiLSTM") && isfield(app.movie_data.models.BiLSTM, "feature_names")
                used_features = app.movie_data.models.BiLSTM.feature_names;
            else
                app.textout.Value = "Discovery mode did not run as the loaded BiLSTM model either is not correctly loaded or saved in this file. Please ensure you have classified the loaded dataset with a BiLSTM model first.";
                warndlg("Discovery mode did not run as the BiLSTM model is not properly loaded.", "Model details not available");
                return;
            end
            
        case 'Labels from GRU'
            if isprop(app, "movie_data") && isfield(app.movie_data, "results") && ...
                    isfield(app.movie_data.results, "GRULabelled") && isfield(app.movie_data.results.GRULabelled, "LabelledMols")
                track_data = app.movie_data.results.GRULabelled.LabelledMols;
            else
                app.textout.Value = "Discovery mode did not run as GRU model-annotated data does not exist. Please ensure you have classified the loaded dataset with a GRU model first.";
                warndlg("Discovery mode did not run as GRU model-annotated data does not exist. Please ensure you have classified the loaded dataset with a GRU model first.", "Annotations not available");
                return;
            end
            if isprop(app, "movie_data") && isfield(app.movie_data, "models") && ...
                    isfield(app.movie_data.models, "GRU") && isfield(app.movie_data.models.GRU, "feature_names")
                used_features = app.movie_data.models.GRU.feature_names;
            else
                app.textout.Value = "Discovery mode did not run as the loaded GRU model either is not correctly loaded or saved in this file. Please ensure you have classified the loaded dataset with a GRU model first.";
                warndlg("Discovery mode did not run as the GRU model is not properly loaded.", "Model details not available");
                return;
            end
            
        case 'Labels from BiGRU'
            if isprop(app, "movie_data") && isfield(app.movie_data, "results") && ...
                    isfield(app.movie_data.results, "BiGRULabelled") && isfield(app.movie_data.results.BiGRULabelled, "LabelledMols")
                track_data = app.movie_data.results.BiGRULabelled.LabelledMols;
            else
                app.textout.Value = "Discovery mode did not run as BiGRU model-annotated data does not exist. Please ensure you have classified the loaded dataset with a BiGRU model first.";
                warndlg("Discovery mode did not run as BiGRU model-annotated data does not exist. Please ensure you have classified the loaded dataset with a BiGRU model first.", "Annotations not available");
                return;
            end
            if isprop(app, "movie_data") && isfield(app.movie_data, "models") && ...
                    isfield(app.movie_data.models, "BiGRU") && isfield(app.movie_data.models.BiGRU, "feature_names")
                used_features = app.movie_data.models.BiGRU.feature_names;
            else
                app.textout.Value = "Discovery mode did not run as the loaded BiGRU model either is not correctly loaded or saved in this file. Please ensure you have classified the loaded dataset with a BiGRU model first.";
                warndlg("Discovery mode did not run as the BiGRU model is not properly loaded.", "Model details not available");
                return;
            end
            
        otherwise
            warndlg("Please select a valid data source from the [Source dataset] dropdown menu. If no option is present then you must first classify a dataset with a model.", "Invalid data source");
            return;
    end
end


function [] = plotDiscoveryResults(app, sorted_MI, sorted_features, sorted_highlight_mask)
%Plot the discovery results graphically, Oliver Pambos, 15/02/2025.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotDiscoveryResults
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
%Plots the MI results of the requested features in either the GUI or an
%external figure.
%
%Inputs
%------
%app                    (handle)    main GUI handle
%sorted_MI              (vec)       1xN row vector of MI scores for each
%                                       unused feature to be displayed,
%                                       sorted by MI (highest first)
%sorted_features        (cell)      1xN cell array of feature names
%                                       corresponding to each entry in
%                                       sorted_MI
%sorted_highlight_mask  (vec)       1xN boolean row vector indicating
%                                       whether each corresponding feature
%                                       meets/exceeds the MI threshold
%                                       necessary to be highlighted
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %define plot location (GUI/external)
    if strcmp(app.DiscoveryPlotlocationDropDown.Value, 'External')
        fig = figure;
        ax = axes(fig);
    else
        ax = app.DiscoveryUIAxes;
        cla(ax, 'reset');
    end
    
    hold(ax, 'on');
    box(ax, 'on');
    
    %set colours
    default_color   = [0.7, 0.7, 0.7];
    highlight_color = [0.63, 0.76, 0.67]; %Cambridge blue!
    bar_colors = repmat(default_color, numel(sorted_MI), 1);
    bar_colors(sorted_highlight_mask, :) = repmat(highlight_color, sum(sorted_highlight_mask), 1);
    
    %plot data
    bars = barh(ax, sorted_MI, 'FaceColor', 'flat', 'EdgeColor', 'none');
    
    %set bar colours
    for ii = 1:numel(sorted_MI)
        bars.CData(ii, :) = bar_colors(ii, :);
    end
    
    %add feature names, and style plot
    ax.YTick            = 1:numel(sorted_features);
    ax.YTickLabel       = sorted_features;
    ax.YAxis.FontSize   = 14;
    ax.XAxis.FontSize   = 14;
    ax.YDir             = 'reverse';    %highest MI score at top
    ax.LineWidth        = 2;
    ax.Layer            = 'top';
    
    xlabel(ax, 'Mutual Information (MI)', 'FontSize', 16, 'FontWeight', 'bold');
    title(ax, 'Predictive strength in features not used by model', 'FontSize', 16, 'FontWeight', 'bold');
    hold(ax, 'off');
end