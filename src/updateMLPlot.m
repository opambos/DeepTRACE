function [] = updateMLPlot(h_axes, data, feat_cols, feature_names, class_names, class_colours, text_title, N_max, viewer_state)
%Update the ML data viewer axes, 01/05/2023.
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
%Displays the classified data of up to 3 features simultaneously with
%classifications encoded as colours.
%
%Inputs
%------
%h_axes         (obj)   object handle for the MLDataView axes in the GUI
%data           (mat)   MxN matrix of the data to plot; contains M data points, and N-1 features (final column is an integer class label)
%feat_idx       (vec)   row vector of the indices of the features to plot
%feature_names  (cell)  cell array of strings of the names of features being plotted
%class_names    (cell)  cell array of strings of class names
%class_colours  (mat)   Nx3 matrix of RGB colour values for N classes
%text_title     (str)   title to place above the plot
%viewer_state   (str)   stores the current content of the app.MLDataViewer
%                           UIAxes component; this is necessary because the
%                           process of reseting the figure causes lag, this
%                           ensures the call to reset() only occurs when
%                           needed, when the viewer does not currently
%                           display the same type of data.
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %downsamle the data if necessary, also shuffles rows
    N_keep      = min(N_max, size(data, 1));
    idx_keep    = randperm(size(data, 1), N_keep);
    data        = data(idx_keep, :);
    
    %find the feature column IDs

    %if the last plot wasn't data visualisation
    if ~strcmp(viewer_state, "Visualisation")
        reset(h_axes);
        box(h_axes, "on");
        grid(h_axes, "on");
    end
    
    %set the axis style
    cla(h_axes);
    hold(h_axes, 'on');
    zoom(h_axes, 'off');
    pan(h_axes, 'off');
    
    %handling error in call to xlim, ylim when a feature contains a single
    %repeating value (f'ns require a pair of non-identical values)
    x_lims = [min(data(:,feat_cols(1))) max(data(:,feat_cols(1)))];
    y_lims = [min(data(:,feat_cols(2))) max(data(:,feat_cols(2)))];
    if x_lims(1) == x_lims(2)
        x_lims(1) = x_lims(1) - 0.1*x_lims(1);
        x_lims(2) = x_lims(2) + 0.1*x_lims(2);
    end
    if y_lims(1) == y_lims(2)
        y_lims(1) = y_lims(1) - 0.1*y_lims(1);
        y_lims(2) = y_lims(2) + 0.1*y_lims(2);
    end

    %set limits
    xlim(h_axes, x_lims);
    ylim(h_axes, y_lims);
    
    if size(feat_cols,2) > 2
        rotate3d(h_axes, 'on');
        zlim(h_axes, [min(data(:,feat_cols(3))) max(data(:,feat_cols(3)))]);
    else
        rotate3d(h_axes, 'off');
        view(h_axes, 0, 90);
        zlim(h_axes, [0 1]);
        zlabel(h_axes, "");
    end
    
    cla(h_axes);
    %set default limits for axes
    %xlim(h_axes, 'auto');
    %ylim(h_axes, 'auto');
    
    %separate data into the labelled classes, plot with different colours for each class, then plot either 3D or 2D scatter
    for ii = 1:size(class_names, 1)
        plot_class = data(data(:,end)==ii,:);
        if size(feat_cols,2) > 2
            scatter3(h_axes, plot_class(:,feat_cols(1)), plot_class(:,feat_cols(2)), plot_class(:,feat_cols(3)), [], plot_class(:,end), 'filled', 'CData', class_colours(ii,:));
        else
            scatter(h_axes, plot_class(:,feat_cols(1)), plot_class(:,feat_cols(2)), 36, plot_class(:,end), 'filled', 'CData', class_colours(ii,:));
        end
    end
    
    %display labels
    xlabel(h_axes, string(feature_names{1}));
    ylabel(h_axes, string(feature_names{2}));
    if size(feat_cols, 2) > 2
        zlabel(h_axes, string(feature_names{3}));
    end
    title(h_axes, text_title);
    legend(h_axes, class_names, 'Location', 'northoutside', 'Orientation', 'horizontal');
end