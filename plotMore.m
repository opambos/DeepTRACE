function [] = plotMore(app)
%Displays additional data about a molecule/trajectory in an external
%window, Oliver Pambos, 17/12/2021.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotMore
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
%This is a re-introduction of the plotMore() function originally written in
%2021.
%
%This function displays in an external figure window additional data from a
%trajectory that cannot fit in the GUI's UIAxes component. This includes
%information such as the step step angle distribution, additional features,
%and larger illustrations of the molecule and its trajectory. The structure
%of the figure window consists of plots of the time series plots in the
%first (left-hand) column, which spans 3/4 of the figure width, and plots
%of the trajectory (top) and step angle distribution (bottom) in the second
%(right-hand) column. To do this the function employs a tiled layout to
%enable arbitrary numbers of time series plots to be plotted in the first
%column without affecting the second
%
%Note that a tiledlayout is used with double the number of rows as there
%are features. This forces the layout to always contain an even number of
%rows which enables the plots on the right hand side (of which there are
%two) can always be plotted with equal sizes.
%
%Long titles are split into multiple lines to prevent overlap.
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
%placeScaleBar()
%splitAtCenterWhitespace()  - local to this .m file
    
    %obtain trajectory
    cell_ID = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.CellID;
    mol_ID = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.MolID;
    mol = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol;
    %get the time series plots to display
    checked_nodes = app.PlotMoreFeatures.CheckedNodes;
    
    if isempty(checked_nodes)
        app.textout.Value = "No features were selected. Please select features to plot using the `Plot settings` tab.";
        return;
    end
    
    %set up the plot; see notes in header
    N_rows = length(checked_nodes) * 2;
    h = tiledlayout(N_rows, 4, "TileSpacing", "compact");
    title(h, "More details of cell " + cell_ID + ", molecule " + mol_ID, 'FontSize', 18);
    set(gcf, 'Position', [100, 100, 1200, 800], 'Color', 'white');
    
    %maximum length of an axes title before splitting it onto two lines
    title_max_len = 25;
    
    %find the time column
    col_t = find(strcmp(app.movie_data.params.column_titles.tracks, "Time from start of track (s)"));
    
    %loop over the time series plots to display in left-hand column
    for ii = 1:length(checked_nodes)
        feature_name = checked_nodes(ii).Text;
        col_data = find(strcmp(app.movie_data.params.column_titles.tracks, feature_name));
        
        %plot if both time and data columns are found
        if ~isempty(col_t) && ~isempty(col_data)
            startTile = (ii - 1) * 2 * 4 + 1;
            ax = nexttile(startTile, [2, 3]);                   %spans 2 rows and first 3 columns
            plot(ax, mol(:, col_t), mol(:, col_data), 'k-', 'LineWidth', 1.5);
            
            %set axis properties
            plot_title = splitAtCenterWhitespace(feature_name, title_max_len);
            ylabel(ax, plot_title, 'FontSize', 18);
            xlabel(ax, 'Time (s)');
            ax.FontSize = 16;
            xlim([0 mol(end, col_t)]);
        end
    end
    
    %top right plot
    trajectory_plot = nexttile(4, [(N_rows / 2), 1]);

    %display the mesh over the overlay
    imagesc(app.movie_data.cellROI_data(cell_ID).overlay, 'parent', trajectory_plot);
    axis(trajectory_plot, 'equal');
    axis(trajectory_plot, 'off');
    hold(trajectory_plot, 'on');
    colormap(trajectory_plot, gray(256));
    
    %obtain the trajectory
    track = mol(:,1:2);
    
    %correct offset between cropped image and track - note that the offset applied by LoColi's ROI_tracking function appears to have already been applied to the localisation data
    track(:,1) = track(:,1) - app.movie_data.cellROI_data(cell_ID).overlay_offset(2);
    track(:,2) = track(:,2) - app.movie_data.cellROI_data(cell_ID).overlay_offset(1);
    
    %plot the trajectory
    plotColourTrack(trajectory_plot, "Rainbow", "Lines", track, app.movie_data.params.event_label_colours);
    
    %add a scalebar; set size, position, draw rectangle, add text label
    if app.ScalebarCheckBox.Value
        placeScaleBar(app, trajectory_plot);
    end
    title(trajectory_plot, 'Molecular trajectory', 'FontSize', 16);
    
    %step angle plot
    step_angle_plot = nexttile(4 + (N_rows/2)*4, [(N_rows / 2), 1]);

    title(step_angle_plot, 'Relative step angles');
    feat_idx = strcmp(app.movie_data.params.column_titles.tracks, "Step angle relative to previous step (degrees, absolute)");
    step_angle_data = mol(3:end,feat_idx);

    %convert degrees to radians and bin data
    [bin_count, bin_edges] = histcounts(deg2rad(step_angle_data), deg2rad(0:15:360));

    %mirror the data
    mirror_data = deg2rad(360) - deg2rad(step_angle_data);
    [bins_mirrored, ~] = histcounts(mirror_data, deg2rad(0:15:360));

    %combine real and mirrored data
    combined_data = bin_count + bins_mirrored;
    
    %calc mean angles
    x = combined_data .* cos((bin_edges(1:end-1) + bin_edges(2:end)) / 2);
    y = combined_data .* sin((bin_edges(1:end-1) + bin_edges(2:end)) / 2);

    %compass plot
    h_compass = compass(step_angle_plot, x, y);
    set(h_compass, 'LineWidth', 2, 'Color', 'k');
    
    %hide labels, and generate mirrored replacements
    set(findall(step_angle_plot, 'type', 'text'), 'Visible', 'off')
    angles = 0:30:360;
    labels = arrayfun(@num2str, [0:30:180, 150:-30:0], 'UniformOutput', false);
    
    %loop over all angles, positioning labels
    for i = 1:length(angles)
        angle = angles(i);
        label = labels{i};
        
        %position for next label
        r = 1.3 * max(combined_data);
        x_text = r * cosd(angle);
        y_text = r * sind(angle);
    
        %print label
        text(x_text, y_text, label, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontSize', 14);
    end

    %adjust the axis limits to fit the labels
    axis_lim = 1.2 * max(combined_data);
    axis(step_angle_plot, [-axis_lim, axis_lim, -axis_lim, axis_lim]);
    
end


function split_str = splitAtCenterWhitespace(title_str, max_len)
%Splits a title string into two if it exceeds a specified length, Oliver
%Pambos, 17/12/2021.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: splitAtCenterWhitespace
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
%Long titles are split into multiple lines to prevent overlap.
%
%Input
%-----
%title_str  (str)   string to be tested for splitting
%max_len    (int)   maximum number of characters the string can contain
%                       before being considered for splitting
%
%Output
%------
%split_str  (cell)  string, split into multiple lines if it is too long and
%                       can be split
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %if the string is shorter, return it as it is
    if length(title_str) <= max_len
        split_str = {title_str};
        return;
    end
    
    %find the mid-point
    idx_centre = ceil(length(title_str) / 2);
    
    %search for the nearest whitespace to the middle index
    low_idx     = find(isspace(title_str(1:idx_centre)), 1, 'last');
    upper_idx   = find(isspace(title_str(idx_centre:end)), 1, 'first') + idx_centre - 1;
    
    %determine closest index to the centre
    if isempty(low_idx) && isempty(upper_idx)
        %no whitespace found, return original string in a cell array
        split_str = {title_str};
    elseif isempty(low_idx) || (~isempty(upper_idx) && (upper_idx - idx_centre) < (idx_centre - low_idx))
        %split at the upper index
        split_str = {title_str(1:upper_idx-1), title_str(upper_idx+1:end)};
    else
        %split at the lower index
        split_str = {title_str(1:low_idx-1), title_str(low_idx+1:end)};
    end
end


