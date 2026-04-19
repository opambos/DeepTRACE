function [] = plotClassDistributions(app)
%Plot the class-conditional feature distributions, 23/11/2024.
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
%This function is a modified version of the earlier external code
%visaliseClassDistribtions.m that previously operated on saved analysis
%files to visualise features. The inputs have been replaced with GUI
%controls to provide the user with fast access to this tool prior to public
%release.
%
%This function enables the plotting of the distribution of features using
%kernel density estimators, and mirrored violin plots for pairs of classes.
%This enables the user to interpret the performance of features prior to
%model training.
%
%This function also computes and displays the Kolmogorov–Smirnov statistic
%for the two selected classes to quantify class separability. Wasserstein
%distance and histogram non-overlap metrics have been disabled in the
%current version to avoid user confusion arising from the adaptive binning
%process. This will be later expanded in a future update to compute a
%single metric across all classes.
%
%A future update will involve removing feature-wise the first and last
%regions of tracks for features that do not generate meaningful values in
%these ranges, e.g. step angle has two leading zeros at the start of every
%track as it takes three localisations to obtain the relative step angle.
%This has been implemented during model training, but not here for feature
%visualisation, and leads to an overpopulation of some features at zero,
%which potentially skews slightly the KDE plots.
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
%None
    
    %check requested classes are valid, if so get their IDs
    if strcmp(app.FeatureAnalysisClassADropDown.Value, app.FeatureAnalysisClassBDropDown.Value) || ~ismember(app.FeatureAnalysisClassADropDown.Value, app.movie_data.params.class_names) || ~ismember(app.FeatureAnalysisClassBDropDown.Value, app.movie_data.params.class_names)
        app.textout.Value = "You must select two different and valid classes from the [Class A] and [Class B] dropdown boxes in the [Feature visualisation] subtab.";
        warndlg("You must select two different and valid classes from the [Class A] and [Class B] dropdown boxes in the [Feature visualisation] subtab.", "Invalid classes requested");
        return;
    else
        class_A_ID = find(strcmp(app.FeatureAnalysisClassADropDown.Value, app.movie_data.params.class_names));
        class_B_ID = find(strcmp(app.FeatureAnalysisClassBDropDown.Value, app.movie_data.params.class_names));
    end
    
    %get feature list and params from GUI
    feature_list    = app.MLfeatures.CheckedNodes;
    
    %check user selected at least one feature
    if isempty(feature_list)
        app.textout.Value = "You have not selected any features! Please select the featuers you would like to produce plots for from the [Features] list in the [ML Classification tab]";
        warndlg("Please select the featuers you would like to produce plots for from the [Features] list in the [ML Classification tab]", "You have not selected any features!");
        return;
    end
    
    %get the source data
    switch app.FeatureAnalysisSourcedataDropDown.Value
        case "Ground truth"
            track_data = app.movie_data.results.GroundTruth.LabelledMols;
        case "Human annotations"
            track_data = app.movie_data.results.VisuallyLabelled.LabelledMols;
        case "<< Selet dataset >>"
            app.textout.Value = "Please select a dataset for the source annotations from the [Source data] dropdown in the [Feature analysis] subtab of the [ML Classification] tab.";
            warndlg("Please select a dataset for the source annotations from the [Source data] dropdown in the [Feature analysis] subtab of the [ML Classification] tab.", "No source data selected!");
            return;
        otherwise
            app.textout.Value = "The dataset selected in the [Source data] dropdown in the [Feature analysis] subtab of the [ML Classification] tab is not present in the loaded data. Please reload the file and try again.";
            warndlg("The dataset selected in the [Source data] dropdown in the [Feature analysis] subtab of the [ML Classification] tab is not present in the loaded datafile. Please reload the file and try again.", "No source data available!");
            return;
    end
    
    %verify tracks data contains data
    if isempty(track_data)
        app.textout.Value = "The selected dataset contains no annotated data in " + app.FeatureAnalysisSourcedataDropDown.Value + "; for you must either load the appropriate ground truth file or perform human annotation of the dataset.";
        warndlg("The selected dataset contains no annotated data in " + app.FeatureAnalysisSourcedataDropDown.Value + "; for you must either load the appropriate ground truth file or perform human annotation of the dataset.", "No tracks have been annotated!");
        return;
    end
    
    %obtain from GUI params for binning data
    smooth_param        = app.SmoothingfactorSpinner.Value;
    N_pts               = app.PlotresolutionSpinner.Value;
    ignore_rows_start   = app.FeatureAnalysisIgnorerowsfromstartSpinner.Value;
    ignore_rows_end     = app.FeatureAnalysisIgnorerowsfromendSpinner.Value;
    transition_range    = app.FeatureAnalysisTransitionregionrangestepsSpinner.Value;
    
    %loop over features
    for ii = 1:numel(feature_list)
        feature_name = feature_list(ii).Text;
        feature_col = findColumnIdx(app.movie_data.params.column_titles.tracks, feature_name);
        
        %collect data for each class
        data_class_A = [];
        data_class_B = [];
        
        %loop over annotated tracks, gathering data for analysis
        for jj = 1:numel(track_data)
            curr_track      = track_data{jj, 1}.Mol;
            feature_data    = curr_track(ignore_rows_start+1:end-ignore_rows_end, feature_col);
            class_data      = curr_track(ignore_rows_start+1:end-ignore_rows_end, end);
            
            %process data based on selected subset
            switch app.FeatureAnalysisDatasubsetDropDown.Value
                case "All data"
                    %use all data points as currently implemented
                    data_class_A = [data_class_A; feature_data(class_data == class_A_ID)];
                    data_class_B = [data_class_B; feature_data(class_data == class_B_ID)];
                    
                case "Changepoint-proximal"
                    %identify all transitions
                    transition_A_to_B = find(class_data(1:end-1) == class_A_ID & class_data(2:end) == class_B_ID);
                    transition_B_to_A = find(class_data(1:end-1) == class_B_ID & class_data(2:end) == class_A_ID);
                    
                    %handle transitions from Class A → Class B
                    for idx = transition_A_to_B'
                        %define bounds for the current transition region
                        start_idx   = max(1, idx - transition_range + 1); %lower bound
                        end_idx     = min(length(class_data), idx + transition_range); %upper bound
                        
                        %append all data in this region to Class A histogram
                        data_class_A = [data_class_A; feature_data(start_idx:end_idx)];
                    end
                    
                    %handle transitions from Class B → Class A
                    for idx = transition_B_to_A'
                        %define bounds for the current transition region
                        start_idx   = max(1, idx - transition_range + 1); %lower bound
                        end_idx     = min(length(class_data), idx + transition_range); %upper bound
                        
                        %append all data in this region to Class B histogram
                        data_class_B = [data_class_B; feature_data(start_idx:end_idx)];
                    end
                    
                case "Changepoint-distal"
                    %identify all transitions (any class change)
                    transition_indices = find(diff(class_data) ~= 0);
                    
                    %initialize mask for non-transition regions
                    non_transition_mask = true(size(class_data)); %start with all true
                    
                    %exclude rows in transition regions
                    for idx = transition_indices'
                        %define bounds for the current transition region
                        start_idx   = max(1, idx - transition_range + 1); %lower bound
                        end_idx     = min(length(class_data), idx + transition_range); %upper bound
                        
                        %mark rows in transition regions as false
                        non_transition_mask(start_idx:end_idx) = false;
                    end
                    
                    %append data for each class
                    data_class_A = [data_class_A; feature_data(non_transition_mask & class_data == class_A_ID)];
                    data_class_B = [data_class_B; feature_data(non_transition_mask & class_data == class_B_ID)];
                    
                otherwise
                    error('Invalid option selected in FeatureAnalysisDatasubsetDropDown.');
            end
        end
        
        switch app.FeatureVisualisationMethodDropDown.Value
            case "Histogram"
                %compute histogram bin edges and centers
                bin_edges_A     = linspace(min(data_class_A), max(data_class_A), N_pts + 1);
                bin_edges_B     = linspace(min(data_class_B), max(data_class_B), N_pts + 1);
                bin_centers_A   = (bin_edges_A(1:end-1) + bin_edges_A(2:end)) / 2;
                bin_centers_B   = (bin_edges_B(1:end-1) + bin_edges_B(2:end)) / 2;
                
                counts_A = histcounts(data_class_A, bin_edges_A, 'Normalization', 'pdf');
                counts_B = histcounts(data_class_B, bin_edges_B, 'Normalization', 'pdf');
                
                %apply smoothing if smoothing_param > 0
                if smooth_param > 0
                    %define Gaussian kernel based on smoothing_param
                    kernel_width = ceil(3 * smooth_param); %kernel size, covers ~99% of Gaussian
                    kernel = gausswin(2 * kernel_width + 1, 1 / smooth_param); %create Gaussian kernel
                    kernel = kernel / sum(kernel); %normalize kernel
                    
                    %smooth histogram counts
                    counts_A = conv(counts_A, kernel, 'same'); %apply smoothing
                    counts_B = conv(counts_B, kernel, 'same'); %apply smoothing
                end
                
                %plot mirrored histograms
                figure('Name', feature_name, 'Position', [100, 100, 1200, 800], 'Color', 'w', 'MenuBar', 'none');
                hold on;
                fill([-counts_A 0 0], [bin_centers_A bin_centers_A(end) bin_centers_A(1)], app.movie_data.params.event_label_colours(class_A_ID, :), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
                fill([counts_B 0 0], [bin_centers_B bin_centers_B(end) bin_centers_B(1)], app.movie_data.params.event_label_colours(class_B_ID, :), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
                
                %set symmetric x-axis limits
                max_val = max(max(abs([-counts_A counts_B])));
                xlim([-max_val .* 1.05, max_val .* 1.05]);
                
            case "Kernel density estimator"
                %enforce a minimum bandwidth of 0.01 for KDE
                smooth_param = min(smooth_param, 0.01);
                
                %create KDEs for each class
                if min(data_class_A) >= 0 && min(data_class_B) >= 0
                    %non-negative feature: remove zeros to comply with 'Support', 'positive'
                    data_class_A = data_class_A(data_class_A > 0);
                    data_class_B = data_class_B(data_class_B > 0);
                    [f1, x1] = ksdensity(data_class_A, 'Support', 'positive', 'Bandwidth', smooth_param, 'NumPoints', N_pts); 
                    [f2, x2] = ksdensity(data_class_B, 'Support', 'positive', 'Bandwidth', smooth_param, 'NumPoints', N_pts);
                else
                    %general case: allow full range, including zero and negatives
                    [f1, x1] = ksdensity(data_class_A, 'Bandwidth', smooth_param, 'NumPoints', N_pts);
                    [f2, x2] = ksdensity(data_class_B, 'Bandwidth', smooth_param, 'NumPoints', N_pts);
                end
                
                %================
                %Plotting feature
                %================
                %generate violin-like plot for both classes (class 1 mirrored)
                figure('Name', feature_name, 'Position', [100, 100, 1200, 800], 'Color', 'w', 'MenuBar', 'none');
                hold on;
                fill([-f1, 0, 0], [x1, x1(end), x1(1)], app.movie_data.params.event_label_colours(class_A_ID, :), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
                fill([f2, 0, 0],  [x2, x2(end), x2(1)], app.movie_data.params.event_label_colours(class_B_ID, :), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
                
                %set symmetric x-axis limits such that plots are centred within figure
                max_val = max(max(abs([-f1, f2])));
                xlim([-max_val .* 1.05, max_val .* 1.05]);
                
            otherwise
                warndlg("Unknown binning method", "Error: Unknown binning method!");
                app.textout.Value = "Unable to generate feature plot: unknown binning method!";
                return;
        end
        
        %compute class-separability metric(s)
        switch app.ClassseparabilitymetricDropDown.Value
            case "Kolmogorov-Smirnov"
                %compute Kolmogorov-Smirnov statistic
                [~, ~, ks_stat] = kstest2(data_class_A, data_class_B);
                title_metric_str = "D_{KS} = " + num2str(ks_stat, '%.3f');
                title(title_metric_str);
            otherwise
                
        end
        
        %formatting
        set(gca, 'Color', 'w', 'Box', 'on', 'FontSize', 20, 'LineWidth', 2, 'TickDir', 'in', 'TickLength', [0.02, 0.02]);
        ylabel(feature_name, 'FontSize', 24);
        legend({'Slow', 'Fast'}, 'Location', 'best', 'FontSize', 20, 'Box', 'off');
        
        hold off;
    end
end