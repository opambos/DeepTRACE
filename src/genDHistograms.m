function [] = genDHistograms(app)
%Generates a diffusion histograms for annotated data, 27/11/2024.
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
%Generates diffusion histograms for every segmented class/state present in
%the dataset. This function provides options for plotting diffusion
%histograms for all unique tracks in the currently selected results data
%(which is selected using the [Source data] dropdown in the [Dataset
%overview] sub-tab of the [Insights] tab. This effectively transfers an
%annotated dataset to the app.movie_data.results.InsightData cell array,
%which is used here in this funciton. This behaviour is consistent across
%all various insight data analysis functions.
%
%Histograms can be plotted using the following methods,
%   "All" - this plots a single diffusion coefficient for all tracks
%   "Stacked states"    each segmented state in each track is treated as an
%                           independent track, and a stacked column plot
%                           histogram is produced for all states in the
%                           dataset
%   "< XYZ >"           various additional options defined during run time
%                           where each option represents a different state;
%                           this produces a plot of that single state in
%                           isolation
%
%This funciton enables the plotting of states with full user control over
%the range of lag times, bin widths, state selection, and using filtering
%for cell lengths.
%
%Diffusion is computed by a linear fit to the MSD lag time plot using,
%   D = MSD/4t
%where MSD is the mean squared displacement for steps with lag times t.
%
%If the user chooses to export data, the user is prompted to enter a
%filename prefix, which is appended with either "_binned_data.csv" or
%"_raw_data.csv" as follows,
%   "_binned_data.csv"  contains the binned data as displayed, in an N+1
%                           column file in which the first column provides
%                           each bin centre of the diffusion coefficient in
%                           um^2/s, and each further column shows the
%                           occupancy diffusion coefficient from all
%                           tracks/subtrack in each of the N states defined
%                           during runtime
%   "_raw_data.csv"     an N column file of all the raw diffusion
%                       coefficients of each state (or all tracks,
%                       depending upon options) source data used to
%                       generate the histogram
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
%compileMSDMatrixFast()
%fitGammas()
    
    %check valid data available - checks have been superseded by catchInvalidComponentActions()
    % if ~isprop(app, "movie_data")
    %     warndlg("You must load a data file before performing downstream analysis", "No data loaded!");
    %     app.textout.Value = "You must load a data file before performing downstream analysis!";
    %     return;
    % end
    % if ~isfield(app.movie_data, "results") && isfield(app.movie_data.results, "Insight data")
    %     warndlg("You must select a valid segmentation source before performing diffusion analysis. In the [Insights] tab, select the [Dataset overview] sub-tab, and select a dataset from the [Source data] dropdown menu.", "No segmented data available yet!");
    %     app.textout.Value = "You must select a valid segmentation source before performing diffusion analysis. In the [Insights] tab, select the [Dataset overview] sub-tab, and select a dataset from the [Source data] dropdown menu.";
    %     return;
    % end

    if strcmp(app.DiffusionHistStateDropDown.Value, "<< Select state >>")
        warndlg("You must select a valid state from the from the [State] dropdown menu.", "No state selected!");
        app.textout.Value = "You must select a valid state from the from the [State] dropdown menu.";
        return;
    end
    
    diffusion_coeffs = [];
    max_lag = app.DiffusionHistMaxlagframesSpinner.Value;
    
    %set scales (um, and s)
    px_scale     = app.movie_data.params.px_scale / 1000;
    t_interframe = 1 / app.movie_data.params.frame_rate;
    
    switch app.DiffusionHistStateDropDown.Value
        case "All"
            %loop through all labelled molecules
            N_tracks = numel(app.movie_data.results.InsightData.LabelledMols);
            for ii = 1:N_tracks
                curr_track = app.movie_data.results.InsightData.LabelledMols{ii, 1}.Mol(:, 1:3);
                
                if size(curr_track, 1) < 5
                    continue;
                end
                
                %if cell exists, get cell length
                cell_ID = app.movie_data.results.InsightData.LabelledMols{ii, 1}.CellID;
                if cell_ID <= numel(app.movie_data.cellROI_data)
                    cell_len = app.movie_data.cellROI_data(cell_ID).length * px_scale;
                else
                    continue;
                end
                
                %if cell length filtering criteria is applied, and it's outside of requested range then ignore track
                if app.DiffusionHistRestricttorangeofcelllengthsCheckBox.Value && (cell_len < app.DiffusionHistMincelllengthmSpinner.Value || cell_len > app.DiffusionHistMaxcelllengthmSpinner.Value)
                    continue;
                end
                
                %convert to micrometers
                curr_track(:, 1:2) = curr_track(:, 1:2) .* px_scale;
                
                %compute the MSD matrix
                msd_result = compileMSDMatrixFast(curr_track, t_interframe, max_lag);
                
                %check MSD matrix is valid
                if isempty(msd_result) || size(msd_result, 1) < max_lag
                    % warning(['Invalid MSD matrix for track #', num2str(ii)]);
                    continue;
                end
                
                %D = MSD/4t
                coeffs = polyfit(msd_result(1:max_lag, 3), msd_result(1:max_lag, 4), 1);
                slope = coeffs(1);
                D_track = slope / 4;
                
                %store D for curr track
                diffusion_coeffs = [diffusion_coeffs; D_track];
            end
            
            %plotting
            if strcmp(app.DiffusionHistPlotlocationDropDown.Value, "Inside GUI")
                cla(app.UIAxes_compiled_events, 'reset');
                h = histogram(app.UIAxes_compiled_events, diffusion_coeffs, 'BinWidth', app.DiffusionHistBinSizeSpinner.Value);
                ylim(app.UIAxes_compiled_events, [0, ceil(max(h.Values) * 1.05)]);  %rescale y-axis to provide 5% headroom
                h_axes = app.UIAxes_compiled_events; %save ax handle for fitting
                title(app.UIAxes_compiled_events, sprintf('Diffusion coefficient histogram for %d tracks', numel(diffusion_coeffs)));
                xlabel(app.UIAxes_compiled_events, 'Diffusion coefficient (\mum^2/s)');
                ylabel(app.UIAxes_compiled_events, 'Number of tracks');
            else
                h_fig = figure('MenuBar', 'none');
                ax = axes(h_fig);
                h = histogram(diffusion_coeffs, 'BinWidth', app.DiffusionHistBinSizeSpinner.Value);
                ylim(ax, [0, ceil(max(h.Values) * 1.05)]);  %rescale y-axis to provide 5% headroom
                h_axes = ax; %save ax handle for fitting
                title(ax, sprintf('Diffusion coefficient histogram for %d tracks', numel(diffusion_coeffs)));
                xlabel(ax, 'Diffusion coefficient (\mum^2/s)');
                ylabel(ax, 'Number of tracks');
            end
            h.FaceColor = 'black'; h.EdgeColor = 'white'; h.LineWidth = 2;
            
            %export data if the export checkbox is selected
            if app.DiffusionHistExportdatatoCSVCheckBox.Value
                %get filename prefix from user
                [file, path] = uiputfile('*.csv', 'Select filename prefix for data export', 'diffusion_data.csv');
                
                %if user hasn't pressed cancel, save CSV files
                if ischar(file)
                    %remove .csv extension
                    [~, prefix_name, ~] = fileparts(file); 
                    base_filename = fullfile(path, prefix_name);
                    
                    %save raw data
                    raw_filename = fullfile(path, strcat(prefix_name, '_raw_data.csv'));
                    writematrix(diffusion_coeffs, raw_filename);
                    
                    %save binned data
                    binned_filename = fullfile(path, strcat(prefix_name, '_binned_data.csv'));
                    binned_data = [h.BinEdges(1:end-1)', h.Values'];
                    writematrix(binned_data, binned_filename);
                end
            end
            
            %extracted binned data from histogram
            bin_centers = (h.BinEdges(1:end-1) + diff(h.BinEdges) / 2)';
            bin_values = h.Values';
            
            %perform multi-gamma fit to binned data
            if app.DiffusionHistPerformgammafitCheckBox.Value
                fitGammas(app, h_axes, h, [bin_centers, bin_values]);
            end

        case "Stack states"
            N_states = numel(app.movie_data.params.class_names);
            
            %cell array to store diffusion coefficients
            state_diffusion_coeffs = cell(1, N_states);
        
            %loop over states
            for state_idx = 1:N_states
                %loop over tracks
                N_tracks = numel(app.movie_data.results.InsightData.LabelledMols);
                for ii = 1:N_tracks
                    labelled_data   = app.movie_data.results.InsightData.LabelledMols{ii, 1};
                    curr_track      = labelled_data.Mol(:, 1:3);
                    class_labels    = labelled_data.Mol(:, end);
                    
                    %filter by state
                    curr_track = curr_track(class_labels == state_idx, :);
                    
                    if size(curr_track, 1) < 5
                        continue;
                    end
                    
                    %if cell exists, get cell length
                    cell_ID = app.movie_data.results.InsightData.LabelledMols{ii, 1}.CellID;
                    if cell_ID <= numel(app.movie_data.cellROI_data)
                        cell_len = app.movie_data.cellROI_data(cell_ID).length * px_scale;
                    else
                        continue;
                    end
                    
                    %if cell length filtering criteria is applied, and it's outside of requested range then ignore track
                    if app.DiffusionHistRestricttorangeofcelllengthsCheckBox.Value && (cell_len < app.DiffusionHistMincelllengthmSpinner.Value || cell_len > app.DiffusionHistMaxcelllengthmSpinner.Value)
                        continue;
                    end
                    
                    %convert to micrometers
                    curr_track(:, 1:2) = curr_track(:, 1:2) .* px_scale;
                    
                    %compute the MSD matrix
                    msd_result = compileMSDMatrixFast(curr_track, t_interframe, max_lag);
                    
                    %validate the MSD matrix
                    if isempty(msd_result) || size(msd_result, 1) < max_lag
                        % warning(['Invalid MSD matrix for track #', num2str(ii)]);
                        continue;
                    end
                    
                    %extract time, MSD for first max_lag lags
                    lag_times = msd_result(1:max_lag, 3);
                    MSD = msd_result(1:max_lag, 4);
                    
                    %D = MSD/4t
                    coeffs = polyfit(lag_times, MSD, 1);
                    slope = coeffs(1);
                    D_track = slope / 4;
                    
                    %store D for curr track in the current state
                    state_diffusion_coeffs{state_idx} = [state_diffusion_coeffs{state_idx}; D_track];
                end
            end
            
            bin_width   = app.DiffusionHistBinSizeSpinner.Value;
            all_data    = vertcat(state_diffusion_coeffs{:});
            bin_edges   = min(all_data):bin_width:(max(all_data) + bin_width);
            
            %compute hist counts for each state
            hist_counts = zeros(N_states, numel(bin_edges) - 1);
            for state_idx = 1:N_states
                hist_counts(state_idx, :) = histcounts(state_diffusion_coeffs{state_idx}, bin_edges);
            end
            
            %reverse the stacking order so that later states appear on bottom of stack
            hist_counts = flipud(hist_counts);
            
            %compute total for each state
            state_totals = sum(hist_counts, 2);
            total_tracks = sum(state_totals);
            
            legend_labels = strcat(flipud(app.movie_data.params.class_names), " (", string(flipud(state_totals)), ")");
            
            %plot stacked column histogram
            if strcmp(app.DiffusionHistPlotlocationDropDown.Value, "Inside GUI")
                %in GUI axes
                cla(app.UIAxes_compiled_events, 'reset');
                b = bar(app.UIAxes_compiled_events, bin_edges(1:end-1) + bin_width / 2, hist_counts', 'stacked', 'BarWidth', 0.9);
                ylim(app.UIAxes_compiled_events, [0, ceil(max(sum(hist_counts, 1)) * 1.05)]);
                h_axes = app.UIAxes_compiled_events; %save ax handle for fitting

                %remove black outline
                for state_idx = 1:N_states
                    b(state_idx).EdgeColor = 'none';
                end
                
                title(app.UIAxes_compiled_events, sprintf('Diffusion coefficient histogram from %d segmented subtracks', total_tracks));
                xlabel(app.UIAxes_compiled_events, 'Diffusion coefficient (\mum^2/s)');
                ylabel(app.UIAxes_compiled_events, 'Number of subtracks');
                legend(app.UIAxes_compiled_events, legend_labels, 'Location', 'Best');
            else
                %in new figure
                h_fig = figure('MenuBar', 'none');
                ax = axes(h_fig);
                b = bar(ax, bin_edges(1:end-1) + bin_width / 2, hist_counts', 'stacked', 'BarWidth', 0.9);
                ylim(ax, [0, ceil(max(sum(hist_counts, 1)) * 1.05)]);
                h_axes = ax; %save ax handle for fitting

                %remove black outline
                for state_idx = 1:N_states
                    b(state_idx).EdgeColor = 'none';
                end
                
                title(sprintf('Diffusion coefficient histogram from %d segmented subtracks', total_tracks));
                xlabel('Diffusion coefficient (\mum^2/s)');
                ylabel('Number of subtracks');
                legend(legend_labels, 'Location', 'Best');
            end
            
            %set colors for each state
            state_colors = flipud(app.movie_data.params.event_label_colours);
            for state_idx = 1:N_states
                b(state_idx).FaceColor = 'flat';
                b(state_idx).CData = repmat(state_colors(state_idx, :), size(hist_counts, 2), 1);
            end
            
            %export data if the export checkbox is selected
            if app.DiffusionHistExportdatatoCSVCheckBox.Value
                %prompt user for base filename
                [file, path] = uiputfile('*.csv', 'Select filename prefix for data export', 'diffusion_data.csv');
                if ischar(file)
                    %remove .csv extension from file if present
                    [~, prefix_name, ~] = fileparts(file);
                    
                    %save raw data (one col per state)
                    raw_filename = fullfile(path, strcat(prefix_name, '_raw_data.csv'));

                    %pad cols containnig missing vals with NaN to equalise lengths
                    max_len     = max(cellfun(@length, state_diffusion_coeffs));
                    padded_data = cellfun(@(x) [x; nan(max_len - length(x), 1)], state_diffusion_coeffs, 'UniformOutput', false);
                    
                    %write table
                    raw_data_table = table(padded_data{:}, 'VariableNames', app.movie_data.params.class_names);
                    writetable(raw_data_table, raw_filename);
                    
                    %save binned data
                    binned_filename = fullfile(path, strcat(prefix_name, '_binned_data.csv'));
                    binned_data     = [bin_edges(1:end-1)' + bin_width / 2, hist_counts'];
                    writematrix(binned_data, binned_filename);
                end
            end
            
            %compute binned data for stacked histogram
            bin_centers = bin_edges(1:end-1)' + bin_width / 2;
            stacked_counts = sum(hist_counts, 1)';
            
            %perform multi-Gamma fit to binned data
            if app.DiffusionHistPerformgammafitCheckBox.Value
                fitGammas(app, h_axes, b, [bin_centers, stacked_counts]);
            end

        otherwise
            selected_class = app.DiffusionHistStateDropDown.Value;
            
            %loop over tracks
            N_tracks = numel(app.movie_data.results.InsightData.LabelledMols);
            for ii = 1:N_tracks
                %get track, and its cell ID
                labelled_data   = app.movie_data.results.InsightData.LabelledMols{ii, 1};
                curr_track      = labelled_data.Mol(:, 1:3);
                cell_ID         = labelled_data.CellID;
                
                %if cell exists, get cell length
                if cell_ID <= numel(app.movie_data.cellROI_data)
                    cell_len = app.movie_data.cellROI_data(cell_ID).length * px_scale;
                else
                    continue;
                end
                
                %if cell length filtering criteria is applied, and it's outside of requested range then ignore track
                if app.DiffusionHistRestricttorangeofcelllengthsCheckBox.Value && (cell_len < app.DiffusionHistMincelllengthmSpinner.Value || cell_len > app.DiffusionHistMaxcelllengthmSpinner.Value)
                    continue;
                end
                
                %filter track by class (final col of Mol is class label)
                class_idx   = labelled_data.Mol(:, end) == find(strcmp(app.movie_data.params.class_names, selected_class));
                curr_track  = curr_track(class_idx, :);
                
                if size(curr_track, 1) < 5
                    continue;
                end
                
                %convert to micrometers
                curr_track(:, 1:2) = curr_track(:, 1:2) .* px_scale;
                
                %compute the MSD matrix
                msd_result = compileMSDMatrixFast(curr_track, t_interframe, max_lag);
                
                %validate the MSD matrix
                if isempty(msd_result) || size(msd_result, 1) < max_lag
                    % warning(['Invalid MSD matrix for track #', num2str(ii)]);
                    continue;
                end
                
                %D = MSD/4t
                coeffs = polyfit(msd_result(1:max_lag, 3), msd_result(1:max_lag, 4), 1);
                slope = coeffs(1);
                D_track = slope / 4;
                
                %store D for curr track
                diffusion_coeffs = [diffusion_coeffs; D_track];
            end
            
            %get N_subtracks for title/legend
            N_subtracks = numel(diffusion_coeffs);
            
            %plotting
            if strcmp(app.DiffusionHistPlotlocationDropDown.Value, "Inside GUI")
                %plot inside GUI axes
                cla(app.UIAxes_compiled_events, 'reset');
                h = histogram(app.UIAxes_compiled_events, diffusion_coeffs, 'BinWidth', app.DiffusionHistBinSizeSpinner.Value);
                ylim(app.UIAxes_compiled_events, [0, ceil(max(h.Values) * 1.05)]);  %add extra 5% headroom
                h_axes = app.UIAxes_compiled_events; %save ax handle for fitting
                title(app.UIAxes_compiled_events, sprintf('Diffusion coefficient histogram for %d subtracks in state %s', N_subtracks, selected_class));
            else
                %plot in external figure
                h_fig = figure('MenuBar', 'none');
                ax = axes(h_fig);
                h = histogram(ax, diffusion_coeffs, 'BinWidth', app.DiffusionHistBinSizeSpinner.Value);
                ylim(ax, [0, ceil(max(h.Values) * 1.05)]);  %add extra 5% headroom
                h_axes = ax; %save ax handle for fitting
                title(ax, sprintf('Diffusion coefficient histogram for %d subtracks in state %s', N_subtracks, selected_class));
                xlabel(ax, 'Diffusion coefficient (\mum^2/s)');
                ylabel(ax, 'Number of subtracks');
            end
            h.FaceColor = 'black'; h.EdgeColor = 'white'; h.LineWidth = 2;
            
            %export data if the export checkbox is selected
            if app.DiffusionHistExportdatatoCSVCheckBox.Value
                %prompt user for filename prefix
                [file, path] = uiputfile('*.csv', 'Select filename prefix for data export', 'diffusion_data.csv');
                
                %if user has not pressed cancel, save CSV files
                if ischar(file)
                    %remove .csv extension from file if present
                    [~, prefix_name, ~] = fileparts(file); 
                    
                    %save raw data
                    raw_filename = fullfile(path, strcat(prefix_name, '_raw_data.csv'));
                    writematrix(diffusion_coeffs, raw_filename);
                    
                    %save binned data
                    binned_filename = fullfile(path, strcat(prefix_name, '_binned_data.csv'));
                    binned_data = [h.BinEdges(1:end-1)', h.Values'];
                    writematrix(binned_data, binned_filename);
                end
            end

            %get binned data from histogram
            bin_centers = (h.BinEdges(1:end-1) + diff(h.BinEdges) / 2)';
            bin_values  = h.Values';
            
            %perform multi-Gamma fit to binned data
            if app.DiffusionHistPerformgammafitCheckBox.Value
                fitGammas(app, h_axes, h, [bin_centers, bin_values]);
            end
    end
end