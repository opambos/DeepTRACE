function [] = updateMLPlot(h_axes, data, feat_idx, feature_names, class_names, class_colours, text_title, N_max, viewer_state)
%Update the ML data viewer axes, Oliver Pambos, 01/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: updateMLPlot
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
    xlim(h_axes, [min(data(:,feat_idx(1))) max(data(:,feat_idx(1)))]);
    ylim(h_axes, [min(data(:,feat_idx(2))) max(data(:,feat_idx(2)))]);
    
    if size(feat_idx,2) > 2
        rotate3d(h_axes, 'on');
        zlim(h_axes, [min(data(:,feat_idx(3))) max(data(:,feat_idx(3)))]);
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
        if size(feat_idx,2) > 2
            scatter3(h_axes, plot_class(:,feat_idx(1)), plot_class(:,feat_idx(2)), plot_class(:,feat_idx(3)), [], plot_class(:,end), 'filled', 'CData', class_colours(ii,:));
        else
            scatter(h_axes, plot_class(:,feat_idx(1)), plot_class(:,feat_idx(2)), 36, plot_class(:,end), 'filled', 'CData', class_colours(ii,:));
        end
    end
    
    %display labels
    xlabel(h_axes, string(feature_names{1}));
    ylabel(h_axes, string(feature_names{2}));
    if size(feat_idx, 2) > 2
        zlabel(h_axes, string(feature_names{3}));
    end
    title(h_axes, text_title);
    legend(h_axes, class_names, 'Location', 'northoutside', 'Orientation', 'horizontal');
end