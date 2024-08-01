function [] = plotAnnotatedTrack(app)
%Plots an annotated track over a brightfield image for each annotation
%source, Oliver Pambos,
%05/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotAnnotatedTrack
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
%Plots the track currently displayed in the [Inspect annotations] tab, with
%colours of the annotated class, displayed over brightfield, and with the
%segmented mesh also displayed.
%
%This code has been adapted from an earlier external tool used for data
%exploration of saved analysis files, and incorporated into the main GUI.
%
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
%plotTrackByColor() - local to this .m file
    
    cell_ID = str2double(app.InspectCellID.Text);
    mol_ID = str2double(app.InspectMolID.Text);
    
    %========================================================
    %Processing user selections for which annotations to plot
    %========================================================
    %use a map between the user selectable text and actual struct names
    annotation_map = containers.Map(...
    {'Human annotations', 'LSTM annotations', 'Bidirectional LSTM annotations', 'Random forest annotations', 'GRU annotations', 'Bidirectional GRU annotations'}, ...
    {'VisuallyLabelled',  'LSTMLabelled',     'BiLSTMLabelled',                 'RFLabelled',                'GRULabelled',     'BiGRULabelled'});
    
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
    plot_data = {};
    
    %loop over all structs to be used
    for ii = 1:numel(structs_to_use)
        %find the track (cell_ID, mol_ID) if it exists
        is_match = cellfun(@(x) x.CellID == cell_ID && x.MolID == mol_ID, ...
            app.movie_data.results.(string(structs_to_use(ii))).LabelledMols);
        if any(is_match)
            %add track data to plot_data struct
            track_data = app.movie_data.results.(string(structs_to_use(ii))).LabelledMols{is_match}.Mol(:, [1, 2, end]); %x, y, class
            plot_data.(string(structs_to_use(ii))) = track_data;
        end
    end
    
    %===================
    %Plotting the tracks
    %===================
    %generate figure windows
    fig_handles = gobjects(numel(structs_to_use), 1);

    %loop over all annotations, plotting them in separate windows
    for ii = 1:numel(structs_to_use)
        fig_handles(ii) = figure('Name', structs_to_use{ii}, 'Color', 'white', 'Position', [100, 100, 800, 800]);
        ax = axes('Parent', fig_handles(ii));
        
        %plot brightfield
        cell_overlay = app.movie_data.cellROI_data(cell_ID).overlay;
        overlay_offset = app.movie_data.cellROI_data(cell_ID).overlay_offset;
        imshow(cell_overlay, 'Parent', ax, 'InitialMagnification', 'fit');
        hold(ax, 'on');
        
        %plot mesh
        mesh        = app.movie_data.cellROI_data(cell_ID).mesh;
        x_outline   = [mesh(:, 1); flipud(mesh(:, 3)); mesh(1, 1)];
        y_outline   = [mesh(:, 2); flipud(mesh(:, 4)); mesh(1, 2)];
        plot(ax, x_outline - overlay_offset(2), y_outline - overlay_offset(1), 'k--', 'LineWidth', 1.5);
        
        %plot track
        plotTrackByColor(ax, plot_data.(string(structs_to_use(ii))), app.movie_data.params.event_label_colours, overlay_offset);
        axis(ax, 'off');
        title(ax, structs_to_use{ii});  %shold be replaced with reverse lookup with annotation_map to replace struct name with human readable text
    end
end


function [] = plotTrackByColor(ax, track_data, event_label_colours, overlay_offset)
%Plots a track into an existing figure axes with steps coloured by
%annotated state, Oliver Pambos, 05/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotAnnotatedTrack
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
%Plots the track currently displayed in the [Inspect annotations] tab, with
%colours of the annotated class, displayed over brightfield, and with the
%segmented mesh also displayed.
%
%This code has been adapted from an earlier external tool used for data
%exploration of saved analysis files, and incorporated into the main GUI.
%
%
%Inputs
%------
%ax                     (handle)    existing axes into which track is to be
%                                       plotted
%track_data             (mat)       Nx3 matrix of track and annotations
%                                       containing N timepoints to be
%                                       plotted, columns are,
%                                           col1: x-position (unit: pixels)
%                                           col2: y-position (unit: pixels)
%                                           col3: class index
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
    
    %subtrack the brighfield cropping offset to correctly position track in local FOV
    x = track_data(:, 1) - overlay_offset(2);
    y = track_data(:, 2) - overlay_offset(1);
    
    states = track_data(:, 3);
    hold(ax, 'on');
    start_idx = 1;
    
    %loop over track, plotting each colour segments separately
    while start_idx < size(states, 1)
        %find next contiguous segment to plot
        end_idx = start_idx;
        while end_idx < size(states, 1) && states(end_idx) == states(start_idx)
            end_idx = end_idx + 1;
        end
        
        %correct endpoint if it's run into the next state
        if states(end_idx - 1) ~= states(end_idx)
            end_idx = end_idx - 1;
        end
        
        %include the last point of the previous state, unless it was first point, because step sizes are essentially a measure of movement from the previous frame
        start_idx = max(1, start_idx - 1);

        %lookup color of current segment
        color = event_label_colours(states(end_idx), :);
        
        %plot the segment
        plot(ax, x(start_idx:end_idx), y(start_idx:end_idx), 'Color', color, 'LineWidth', 1.5);
        
        %move to next segment
        start_idx = end_idx + 1;
    end
    
    hold(ax, 'off');
    axis(ax, 'equal');
end