function [] = genAnnotationVideo(app)
%Generate an animated GIF visualizing the annotated tracks synchronised
%with the fluorescence video, Oliver Pambos, 03/08/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genAnnotationVideo
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
%Inputs
%------
%app     (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%plotVideoTrackByColor() - local to this .m file
    
    cell_ID = str2double(app.InspectCellID.Text);
    mol_ID  = str2double(app.InspectMolID.Text);
    
    %========================================================
    %Processing user selections for which annotations to plot
    %========================================================
    %use a map between the user selectable text and actual struct names
    annotation_map = containers.Map(...
        {'Ground truth annotations', 'Human annotations', 'LSTM annotations', 'Bidirectional LSTM annotations', 'Random forest annotations', 'GRU annotations', 'Bidirectional GRU annotations'}, ...
        {'GroundTruth',              'VisuallyLabelled',  'LSTMLabelled',     'BiLSTMLabelled',                 'RFLabelled',                'GRULabelled',     'BiGRULabelled'});
    
    %get selected annotations from the checkbox tree
    selected_nodes = app.CompareAnnotationsTree.CheckedNodes;
    requested_annotations = {selected_nodes.Text};
    
    %check all of the substructs selected exist
    structs_to_use = {};
    available_annotations = fieldnames(app.movie_data.results);
    for ii = 1:size(requested_annotations,2)
        struct_name = annotation_map(requested_annotations{ii});
        if ~ismember(struct_name, available_annotations)
            app.textout.Value = sprintf("Annotation dataset %s does not exist", requested_annotations{ii});
            return;
        else
            structs_to_use = cat(1, structs_to_use, struct_name);
        end
    end
    
    %==========================
    %Compiling the data to plot
    %==========================
    plot_data = struct();
    frame_numbers = [];
    
    %loop over all structs to be used
    for ii = 1:numel(structs_to_use)
        %find the track (cell_ID, mol_ID) if it exists
        is_match = cellfun(@(x) x.CellID == cell_ID && x.MolID == mol_ID, ...
            app.movie_data.results.(string(structs_to_use(ii))).LabelledMols);
        if any(is_match)
            %add track data to plot_data struct
            track_data = app.movie_data.results.(string(structs_to_use(ii))).LabelledMols{is_match}.Mol(:, [1, 2, 3, end]); %x, y, frame, class
            plot_data.(string(structs_to_use(ii))) = track_data;
            frame_numbers = [frame_numbers; track_data(:, 3)];
        end
    end
    
    %determine frame range
    frame_numbers = unique(frame_numbers);
    frame_lo = min(frame_numbers);
    frame_hi = max(frame_numbers);
    
    %find file region to extract
    [idx_file_lo, file_frame_lo] = findFrame(app.movie_data.params.frame_offsets, frame_lo);
    [idx_file_hi, file_frame_hi] = findFrame(app.movie_data.params.frame_offsets, frame_hi);
    
    %This is required to handle the filename depending on whether it is a char array (if there is a single file), or a cell array of char arrays (if there are multiple files)
    if ischar(app.movie_data.params.ffFile)
        temp_filename_lo = app.movie_data.params.ffFile;
        temp_filename_hi = app.movie_data.params.ffFile;
    else
        temp_filename_lo = app.movie_data.params.ffFile(idx_file_lo);
        temp_filename_hi = app.movie_data.params.ffFile(idx_file_hi);
    end
    
    %obtain plotting data for segmented cell mesh
    x_outline = [app.movie_data.cellROI_data(cell_ID).mesh(:, 1); flipud(app.movie_data.cellROI_data(cell_ID).mesh(:, 3)); app.movie_data.cellROI_data(cell_ID).mesh(1, 1)];
    y_outline = [app.movie_data.cellROI_data(cell_ID).mesh(:, 2); flipud(app.movie_data.cellROI_data(cell_ID).mesh(:, 4)); app.movie_data.cellROI_data(cell_ID).mesh(1, 2)];
    
    %get the pixel ROI from the cell mesh
    % x_lo     = floor(min(app.movie_data.cellROI_data(cell_ID).ROIVertices(:,1)) - app.movie_data.params.ill_border);
    % x_hi     = ceil(max(app.movie_data.cellROI_data(cell_ID).ROIVertices(:,1)) + app.movie_data.params.ill_border);
    % y_lo     = floor(min(app.movie_data.cellROI_data(cell_ID).ROIVertices(:,2)) - app.movie_data.params.ill_border);
    % y_hi     = ceil(max(app.movie_data.cellROI_data(cell_ID).ROIVertices(:,2)) + app.movie_data.params.ill_border);
    x_lo     = floor(min(x_outline - app.movie_data.params.ill_border - app.movie_data.params.pixelshift(1)));
    x_hi     = ceil(max(x_outline + app.movie_data.params.ill_border - app.movie_data.params.pixelshift(1)));
    y_lo     = floor(min(y_outline - app.movie_data.params.ill_border - app.movie_data.params.pixelshift(2)));
    y_hi     = ceil(max(y_outline + app.movie_data.params.ill_border - app.movie_data.params.pixelshift(2)));
    
    %extract the video from source files
    if idx_file_lo == idx_file_hi           %track is all within one video file
        video = extractVideo(app.movie_data.params.ffPath, temp_filename_lo, file_frame_lo, file_frame_hi, x_lo, x_hi, y_lo, y_hi);
    elseif idx_file_hi == idx_file_lo + 1   %track spans two video files
        video = extractVideo(app.movie_data.params.ffPath, temp_filename_lo, file_frame_lo, app.movie_data.params.frames_per_file(idx_file_lo), x_lo, x_hi, y_lo, y_hi);
        video = cat(3, video, extractVideo(app.movie_data.params.ffPath, temp_filename_hi, 1, file_frame_hi, x_lo, x_hi, y_lo, y_hi));
    elseif idx_file_hi > idx_file_lo + 1
        error("Error in genAnnotationVideo: track spans more than two files, currently unsupported as there is no currently sample data to validate");
    else
        error("Unknown error in genAnnotationVideo");
    end
    
    %===========================
    %Generating the animation
    %===========================
    %generate empty animated GIF
    gif_filename = sprintf('Annotation video C%d_M%d.gif', cell_ID, mol_ID);
    delay_time = 0.1; %time between frames in seconds
    
    %generate tiled layout
    num_tiles = numel(structs_to_use) + 1;
    fig = figure('Color', 'white', 'Position', [100, 100, 1200, 800]);
    t = tiledlayout(1, num_tiles, 'Padding', 'compact', 'TileSpacing', 'compact');
    
    %first tile is fluorescence video
    ax_fluorescence = nexttile(t);
    title(ax_fluorescence, 'Fluorescence Video');
    
    %subsequent tiles are annotation sources
    ax = gobjects(num_tiles - 1, 1);
    for ii = 1:numel(structs_to_use)
        ax(ii) = nexttile(t);
        
        overlay_offset = app.movie_data.cellROI_data(cell_ID).overlay_offset;
        
        %plot brightfield if requested
        if app.UsecellreferenceimageasbackgroundCheckBox.Value
            cell_overlay = app.movie_data.cellROI_data(cell_ID).overlay;
            overlay_offset = app.movie_data.cellROI_data(cell_ID).overlay_offset;
            imshow(cell_overlay, 'Parent', ax(ii), 'InitialMagnification', 'fit');
            hold(ax(ii), 'on');
        end
        
        %plot mesh
        plot(ax(ii), x_outline - overlay_offset(2), y_outline - overlay_offset(1), 'k--', 'Color', app.AnnotationInspectormeshlinecolourDropDown.Value, 'LineWidth', 1.5);
        
        title(ax(ii), requested_annotations{ii});
    end
    
    %iterate over each frame
    for frame_idx = frame_lo:frame_hi
        %display fluorescence video frame
        imshow(video(:, :, frame_idx - frame_lo + 1), [], 'Parent', ax_fluorescence);
        
        %update each annotation plot with next segment if the frame exists in frame_numbers
        if ismember(frame_idx, frame_numbers)
            for ii = 1:numel(structs_to_use)
                track_data = plot_data.(string(structs_to_use(ii)));
                frame_indices = find(track_data(:, 3) <= frame_idx);
                plotVideoTrackByColor(ax(ii), track_data(frame_indices, :), app.movie_data.params.event_label_colours, overlay_offset);
                ax(ii).XAxis.Visible = 'off';
                ax(ii).YAxis.Visible = 'off';
            end
        end
        
        %capture the frame and write to GIF
        frame = getframe(fig);
        im = frame2im(frame);
        [imind, cm] = rgb2ind(im, 256);
        if frame_idx == frame_lo
            imwrite(imind, cm, gif_filename, 'gif', 'Loopcount', inf, 'DelayTime', delay_time);
        else
            imwrite(imind, cm, gif_filename, 'gif', 'WriteMode', 'append', 'DelayTime', delay_time);
        end
    end
    
    close(fig);
end


function [] = plotVideoTrackByColor(ax, track_data, event_label_colours, overlay_offset)
%plots a track into an existing figure axes with steps coloured by
%annotated state, Oliver Pambos, 03/08/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotVideoTrackByColor
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
%Note that this is an (almost) identical copy of plotTrackByColor() in
%plotAnnotatedTrack.m. The difference is in the number of columns passed
%into track_data. This function could be generalised by assigning,
%   states = track_data(:, end);
%
%Inputs
%------
%ax                     (handle)    existing axes into which track is to be
%                                       plotted
%track_data             (mat)       Nx4 matrix of track and annotations
%                                       containing N timepoints to be
%                                       plotted, columns are,
%                                           col1: x-position (unit: pixels)
%                                           col2: y-position (unit: pixels)
%                                           col3: frame number
%                                           col4: class index
%event_label_colours    (mat)       Nx3 matrix containing the RGB values
%                                       for all N possible classes,
%                                       coloumns contain [Red, Green, Blue]
%                                       values normalised to range 0 - 1
%overlay_offset         (vec)       2-element row vector for the offsets in
%                                       the y- and x-axes respectively of
%                                       the cropped brightfield image
%                                       relative to the full frame FOV
%                                       (note y-axis is first due to
%                                       orientation definition)
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %subtrack the brightfield cropping offset to correctly position track in local FOV
    x = track_data(:, 1) - overlay_offset(2);
    y = track_data(:, 2) - overlay_offset(1);
    
    states = track_data(:, 4);
    hold(ax, 'on');
    start_idx = 1;
    
    %loop over track, plotting each colour segment separately
    while start_idx < size(states, 1)
        %find next contiguous segment to plot
        end_idx = start_idx;
        while end_idx < size(states, 1) && states(end_idx) == states(start_idx)
            end_idx = end_idx + 1;
        end
        
        %correct endpoint if it's run into next state
        if states(end_idx - 1) ~= states(end_idx)
            end_idx = end_idx - 1;
        end
        
        %include last point of previous state, unless it was first point, because step sizes are essentially a measure of movement from the previous frame
        start_idx = max(1, start_idx - 1);
        
        %lookup color of current segment
        color = event_label_colours(states(end_idx), :);
        
        %plot segment
        plot(ax, x(start_idx:end_idx), y(start_idx:end_idx), 'Color', color, 'LineWidth', 1.5);
        
        %move to next segment
        start_idx = end_idx + 1;
    end
    
    hold(ax, 'off');
    axis(ax, 'equal');
end