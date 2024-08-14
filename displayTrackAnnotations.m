function [] = displayTrackAnnotations(app)
%Display and compare track annotations, Oliver Pambos, 05/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: displayTrackAnnotations
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
%This funciton populates the annotation inspector UIAxes component with
%annotations for inspection and comparison.
%
%This code has been adapted from an earlier external tool used for
%visualisation, inspection, and data exploration of saved analysis files
%for the past couple of years, and is here incorporated into the main GUI.
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
%findColumnIdx()
%findCommonAnnotatedTracks()
%findCommonTracks()
%extractLabels()    - local to this .m file
    
    %obtain column indices
    [col_t, col_stepsize] = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Time from start of track (s)', 'Step size (nm)');
    
    %use a map between the user selectable text and actual struct names
    annotation_map = containers.Map(...
    {'Ground truth annotations', 'Human annotations', 'LSTM annotations', 'Bidirectional LSTM annotations', 'Random forest annotations', 'GRU annotations', 'Bidirectional GRU annotations'}, ...
    {'GroundTruth',              'VisuallyLabelled',  'LSTMLabelled',     'BiLSTMLabelled',                 'RFLabelled',                'GRULabelled',     'BiGRULabelled'});
    
    %map for reformatting to legend
    legend_map = containers.Map(...
    {'GroundTruth',  'VisuallyLabelled',  'LSTMLabelled',           'BiLSTMLabelled',           'RFLabelled',           'GRULabelled',           'BiGRULabelled'}, ...
    {'Ground truth', 'Human annotations', 'LSTM model annotations', 'BiLSTM model annotations', 'RF model annotations', 'GRU model annotations', 'BiGRU model annotations'});
    
    %get selected annotations from the checkbox tree; warn and exit if user hasn't yet made a selection
    selected_nodes = app.CompareAnnotationsTree.CheckedNodes;
    if isempty(selected_nodes)
        app.textout.Value = "Please select at least one annoation source to display";
        warndlg("You must select at least one annotated dataset to display!", "Source dataset not selected", "modal");
        return;
    end
    selected_annotations = {selected_nodes.Text};
    
    %check data exists for all selected annotations
    available_annotations = fieldnames(app.movie_data.results);
    for ii = 1:size(selected_annotations,2)
        struct_name = annotation_map(selected_annotations{ii});
        if ~ismember(struct_name, available_annotations)
            app.textout.Value = sprintf("Annotation dataset %s does not exist", selected_annotations{ii});
            return;
        end
    end
    
    %extract labels
    all_labels = struct();
    for ii = 1:size(selected_annotations,2)
        annotation_name = selected_annotations{ii};
        struct_name = annotation_map(annotation_name);
        all_labels.(struct_name) = extractLabels(app.movie_data.results.(struct_name).LabelledMols, col_t, col_stepsize);
    end
    
    %find common tracks among all selected annotations
    annotation_fields = fieldnames(all_labels);
    if isscalar(annotation_fields)
        common_tracks = cell2mat(cellfun(@(x) [x.CellID, x.MolID], all_labels.(annotation_fields{1}), 'UniformOutput', false));
    else
        common_tracks = findCommonAnnotatedTracks(all_labels, annotation_fields);
    end
    
    if isempty(common_tracks)
        disp('No common tracks found.');
        return;
    end
    
    %randomly select one common track
    idx = randi(size(common_tracks, 1));
    selected_track = common_tracks(idx, :);
    
    %extract the selected track data
    track_data = struct();
    for field_names = fieldnames(all_labels)'
        track_data.(field_names{1}) = findTrackData(all_labels.(field_names{1}), selected_track);
    end
    
    %plot track data
    ax = app.AnnotationUIAxes;
    reset(ax);
    yyaxis(ax, 'left');
    first_annotation = annotation_fields{1};
    plot(ax, track_data.(first_annotation).Time, track_data.(first_annotation).StepSize, 'k-', 'LineWidth', 2, 'DisplayName', 'Step Size');
    ylabel(ax, 'Step size (nm)', 'FontSize', 24);
    set(ax.YAxis(1), 'LineWidth', 2);   %line thickness of left y-axis bounding box
    set(ax.XAxis, 'LineWidth', 2);      %line thickness of left y-axis bounding box
    
    %plot labels on right axis
    yyaxis(ax, 'right');
    hold(ax, 'on');
    color_map = lines(size(fieldnames(track_data), 1));
    N_annotations = numel(fieldnames(track_data));

    %positions the annotations with a slight jitter/offset so that they don't lay one on-top of another
    if mod(N_annotations, 2) == 0
        %if there's an even number of annotation sources split them symmetrically either size of class position
        offsets = 0.03 * ((1:N_annotations) - (N_annotations / 2 + 0.5));
    else
        %if there's an even number of annotation sources split them symmetrically either size of class position with one state at zero offset
        offsets = 0.03 * ((1:N_annotations) - ceil(N_annotations / 2));
    end
    
    %plot the shifted annotations
    ii = 1;
    for field_names = fieldnames(track_data)'
        plot(ax, track_data.(field_names{1}).Time, track_data.(field_names{1}).Labels + offsets(ii), '--', 'LineWidth', 1.8, 'DisplayName', field_names{1}, 'Color', color_map(ii, :));
        ii = ii + 1;
    end
    
    %style the plot
    xlim(ax, [0, max(track_data.(first_annotation).Time)]);
    ylim(ax, [0.5, numel(app.movie_data.params.class_names) + 0.5]);
    set(ax, 'ytick', 1:length(app.movie_data.params.class_names), 'yticklabel', app.movie_data.params.class_names, 'FontSize', 22);
    ylabel(ax, 'Annotations', 'FontSize', 24);
    xlabel(ax, 'Time (s)', 'FontSize', 24);
    legend_entries = cellfun(@(x) legend_map(x), fieldnames(track_data), 'UniformOutput', false);
    legend(ax, [{'Step size'}; legend_entries], 'FontSize', 22, 'Box', 'on', 'LineWidth', 1.5);
    set(ax.YAxis(2), 'LineWidth', 2);   %line thickness of right axis bounding box
    hold(ax, 'off');
    
    set(app.AnnotationUIAxes, 'LineWidth', 2);
    
    %update cell and mol ID indicators
    app.InspectCellID.Text  = num2str(selected_track(1));
    app.InspectMolID.Text   = num2str(selected_track(2));
end


function [labels] = extractLabels(LabelledMols, col_t, col_stepsize)
%Extracts annotations from a given LabelledMols cell array, Oliver Pambos,
%05/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: extractLabels
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
%This code has been adapted from an earlier external tool used for data
%exploration of saved analysis files, and incorporated into the main GUI.
%
%
%Inputs
%------
%LabelledMols   (cell)  results cell array of tracks data; each cell
%                           contains a struct of data associated with a
%                           single track
%col_t          (int)   feature column ID for time from start of track (in
%                           seconds)
%col_stepsize   (int)   feature column ID for step size in nanometers
%
%Output
%------
%labels         (cell)  cell array of structs; each entry contains
%                           information for annotations of a single track
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N = numel(LabelledMols);
    labels = cell(N, 1);
    for ii = 1:N
        mol = LabelledMols{ii}.Mol;
        labels{ii} = struct('CellID', LabelledMols{ii}.CellID, ...
                           'MolID', LabelledMols{ii}.MolID, ...
                           'Time', mol(:, col_t), ...
                           'StepSize', mol(:, col_stepsize), ...
                           'Labels', mol(:, end));
    end
end


function [data] = findTrackData(labels, track)
%Extracts track data from the selected track for plotting, Oliver Pambos,
%05/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findTrackData
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
%This code has been adapted from an earlier external tool used for data
%exploration of saved analysis files, and incorporated into the main GUI.
%
%
%Inputs
%------
%labels (cell)  track data for the cell defined by indices in 'track'
%track  (vec)   row vector with entries (1) cell_ID, (2) mol_ID
%
%Output
%------
%data   (mat)   track data for the requested track
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    for ii = 1:length(labels)
        if labels{ii}.CellID == track(1) && labels{ii}.MolID == track(2)
            data = labels{ii};
            break;
        end
    end
end