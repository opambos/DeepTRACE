function [] = displayTrackAnnotations(app)
%Display the differences between annotations, Oliver Pambos, 05/07/2024.
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
%annotations for comparison.
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
%extractLabels()    - local to this .m file
    
    %obtain column indices
    [col_t, col_stepsize] = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Time from start of track (s)', 'Step size (nm)');
    
    %check data exists
    if ~isfield(app.movie_data.results, 'VisuallyLabelled') || ~isfield(app.movie_data.results, 'BiLSTMLabelled')
        app.textout.Value = "One of the annotation datasets does not exist";
        return;
    end
    
    %extract labels
    human_labels = extractLabels(app.movie_data.results.VisuallyLabelled.LabelledMols, col_t, col_stepsize);
    model_labels = extractLabels(app.movie_data.results.BiLSTMLabelled.LabelledMols, col_t, col_stepsize);
    
    %find common tracks between human and model annotations
    common_tracks = findCommonTracks(human_labels, model_labels);
    
    if isempty(common_tracks)
        disp('No common tracks found.');
        return;
    end
    
    %randomly select one common track
    idx = randi(size(common_tracks, 1));
    selected_track = common_tracks(idx, :);
    
    %extract the selected track data
    human_track_data = findTrackData(human_labels, selected_track);
    model_track_data = findTrackData(model_labels, selected_track);
    
    %plotting
    ax = app.AnnotationUIAxes;
    reset(ax);
    yyaxis(ax, 'left');
    plot(ax, human_track_data.Time, human_track_data.StepSize, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Step Size');
    ylabel(ax, 'Step size (nm)', 'FontSize', 18);
    
    yyaxis(ax, 'right');
    hold(ax, 'on');
    plot(ax, human_track_data.Time, human_track_data.Labels - 0.01, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Human Annotations');
    plot(ax, model_track_data.Time, model_track_data.Labels + 0.01, 'g--', 'LineWidth', 1.5, 'Color', [0, 0.5, 0], 'DisplayName', 'BiLSTM Annotations');
    xlim(ax, [0 max(human_track_data.Time)]);
    ylim(ax, [0.5 2.5]);
    set(ax, 'ytick', 1:length(app.movie_data.params.class_names), 'yticklabel', app.movie_data.params.class_names, 'FontSize', 18);
    ylabel(ax, 'Annotations', 'FontSize', 18);
    xlabel(ax, 'Time (s)', 'FontSize', 18);
    legend(ax, 'FontSize', 16);
    hold(ax, 'off');
    
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


function [common] = findCommonTracks(human, model)
%Finds the tracks in common between two annotation sets, Oliver Pambos,
%05/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findCommonTracks
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
%human  (cell)  cell array of human annotations
%model  (cell)  cell array of model annotations
%
%Output
%------
%common (mat)   Nx2 matrix of tracks that are common to both annotation
%                   datasets, columns are,
%                       col1: Cell ID
%                       col2: Mol ID
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    human_keys = cell2mat(cellfun(@(x) [x.CellID, x.MolID], human, 'UniformOutput', false));
    model_keys = cell2mat(cellfun(@(x) [x.CellID, x.MolID], model, 'UniformOutput', false));
    common = intersect(human_keys, model_keys, 'rows');
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