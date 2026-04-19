function [] = repopulateEventLabeller(app)
%Repopulate the human annotation system with a new molecule, 28/10/2022.
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
%This function clears the relevant components of the human annotation
%system, and repopulates them with new data associated with the next
%molecule ready for the next manual labelling.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle, with filtered tracks
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%illustrateMol()
%plotColourTrack()
%setLabellerAxRanges()
%regenerateTrackViewer()
%setupDraggableLine()
    
    %clear the axes and cell_ID and mol_ID display boxes
    cla(app.UIAxes_event_labeller, 'reset');
    cla(app.UIAxes_event_labeller_status);
    cla(app.UIAxes_labelling_progress);
    cla(app.UIAxes_event_labeller_mesh);
    app.CellIDTextArea.Value = '';
    app.MolIDTextArea.Value = '';
    
    %locally cache current track as property of main GUI class to avoid traversing deeply nested hierarcy, for faster access during drag operations and assignments
    ID = app.movie_data.state.event_labeller_current_ID;
    mol_struct = app.movie_data.results.VisuallyLabelled.LabelledMols{ID};
    app.annotation_data.current_ID      = ID;
    app.annotation_data.current_track   = mol_struct.Mol;
    app.annotation_data.current_cell    = mol_struct.CellID;
    app.annotation_data.current_mol     = mol_struct.MolID;
    app.annotation_data.col_time        = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Time from start of track (s)');
    app.annotation_data.col_frame       = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Frame number');
    app.annotation_data.frame_rate      = app.movie_data.params.frame_rate;
    
    %also disable interactive tools in secondary axis while this is convenient
    disableDefaultInteractivity(app.UIAxes_event_labeller);

    %update the state positions
    app.movie_data.state.labeller_track_pos     = 1;
    app.movie_data.state.labeller_frame_video   = 1;
    app.movie_data.state.labelled_so_far        = 0;
    
    %find feature column indices
    if isfield(app.annotation_data,'col_time')
        col_t = app.annotation_data.col_time;
    else
        error("repopulateEventLabeller:MissingTimeColumn", "The required time column ('Time from start of track (s)') is missing from the dataset.");
    end
    
    col_primary = findColumnIdx(app.movie_data.params.column_titles.tracks, app.PrimaryFeatureDropDown.Value);
    app.movie_data.state.col_feature = col_primary;                 %later to move to app.annotation_data above
    if col_primary == 0
        %handles rare cases in which primary feature dropdown does not exist due to a previous initialisation of primary feature dropdown menu when user switches
        %between files processed with different features/tracking sources; ideally this should auto-set to step size as this core feature is always available
        error("repopulateEventLabeller:MissingPrimaryFeature", "The primary feature column is missing in the column titles of the dataset. Please select a new primary feature from the [Human annotation]>[Plot settings] subtab to continue.");
    end
    
    col_secondary = findColumnIdx(app.movie_data.params.column_titles.tracks, app.SecondaryFeatureDropDown.Value);
    app.movie_data.state.col_feature_secondary = col_secondary;     %later to move to app.annotation_data above
    if ~strcmp(app.SecondaryFeatureDropDown.Value, '<< None >>') && col_secondary == 0
        %see note above for col_primary
        error("repopulateEventLabeller:MissingPrimaryFeature", "The secondary feature column is missing in the column titles of the dataset. Please select a new secondary feature from the [Human annotation]>[Plot settings] subtab to continue.");
    end
    
    cell_ID     = app.annotation_data.current_cell;
    mol_ID      = app.annotation_data.current_mol;
    curr_mol    = app.annotation_data.current_track;
    
    %plot time series for primary feature on left y-axis
    yyaxis(app.UIAxes_event_labeller, 'left');
    hold(app.UIAxes_event_labeller, 'on');
    grid(app.UIAxes_event_labeller, 'on');
    box(app.UIAxes_event_labeller, 'on');
    ylabel(app.UIAxes_event_labeller, app.PrimaryFeatureDropDown.Value);
    xlabel(app.UIAxes_event_labeller, 'Time (s)');
    app.UIAxes_event_labeller.FontSize  = 16;
    plot(app.UIAxes_event_labeller, curr_mol(:, col_t), curr_mol(:, col_primary), 'LineWidth', app.PrimaryLinethicknessSpinner.Value, 'Color', app.PrimaryLinecolourDropDown.Value, 'Tag', 'step_trace');
    app.UIAxes_event_labeller.YColor    = app.PrimaryLinecolourDropDown.Value;
    app.movie_data.state.labeller_frame = 1;    %keep track of which frame is currently being displayed; important for performance on slower machine as it greatly reduces number of calls to imagesc()
    app.CellIDTextArea.Value            =  num2str(cell_ID);
    app.MolIDTextArea.Value             =  num2str(mol_ID);
    
    %optionally plot time series for secondary feature; otherwise set the right yyaxis components identical to left
    if ~strcmp(app.SecondaryFeatureDropDown.Value, '<< None >>')
        yyaxis(app.UIAxes_event_labeller, 'right');
        plot(app.UIAxes_event_labeller, curr_mol(:, col_t), curr_mol(:, col_secondary), 'LineWidth', app.SecondaryLinethicknessSpinner.Value, 'Color', [0.5 0.5 0.5], 'Tag', 'secondary_trace', 'LineStyle', ':');
        ylabel(app.UIAxes_event_labeller, app.SecondaryFeatureDropDown.Value);
        app.UIAxes_event_labeller.YColor = [0.5 0.5 0.5];
        
        %also disable interactive tools in secondary axis while this is convenient
        disableDefaultInteractivity(app.UIAxes_event_labeller);
        app.UIAxes_event_labeller.Toolbar.Visible = 'off';
        
        yyaxis(app.UIAxes_event_labeller, 'left');
    else
        yyaxis(app.UIAxes_event_labeller, 'left');
        y_limits_left = ylim(app.UIAxes_event_labeller);
        yyaxis(app.UIAxes_event_labeller, 'right');
        ylim(app.UIAxes_event_labeller, y_limits_left);
        app.UIAxes_event_labeller.YColor = 'k';
        app.UIAxes_event_labeller.Toolbar.Visible = 'off';

        yyaxis(app.UIAxes_event_labeller, 'left');
    end
    
    %plot the reference lines (if they exist)
    if isfield(app.movie_data.params, 'reference_lines')
        %ensure user hasn't added duplicates
        app.movie_data.params.reference_lines = unique(app.movie_data.params.reference_lines);
        for ii = 1:size(app.movie_data.params.reference_lines,1)
            yline(app.UIAxes_event_labeller, app.movie_data.params.reference_lines, '--', string(app.movie_data.params.reference_lines) + "  ", 'Color', app.ReferencelinecolourDropDown.Value, 'LineWidth', app.ReferencelinethicknessSpinner.Value);
        end
    end
    
    %set ranges for axes of the human annotation system
    setLabellerAxesRange(app)
    
    %place red circle to highlight next labelling point
    scatter(app.UIAxes_event_labeller, curr_mol(1, col_t), curr_mol(1, col_primary), 'ro', 'Tag', 'current_loc', 'SizeData', 100, 'LineWidth', 1.5);
    box(app.UIAxes_event_labeller, 'on');
    
    %ensure secondary y-axis scale matches primary
    if strcmp(app.SecondaryFeatureDropDown.Value, '<< None >>')
        yyaxis(app.UIAxes_event_labeller, 'left');
        y_limits_left = ylim(app.UIAxes_event_labeller);
        yyaxis(app.UIAxes_event_labeller, 'right');
        ylim(app.UIAxes_event_labeller, y_limits_left);
        app.UIAxes_event_labeller.YTickLabel = {};
        app.UIAxes_event_labeller.YColor = [0.5 0.5 0.5];
        yyaxis(app.UIAxes_event_labeller, 'left');
    end

    %prevent user being able to drag/zoom/etc.
    disableDefaultInteractivity(app.UIAxes_event_labeller);
    disableDefaultInteractivity(app.UIAxes_event_labeller_status);
    disableDefaultInteractivity(app.UIAxes_labelling_progress);
    
    %set up the status bar above the trajectory labeller
    axis(app.UIAxes_event_labeller_status, 'off');
    app.UIAxes_event_labeller_status.YLim = [0 1];
    app.UIAxes_event_labeller_status.XLim = [curr_mol(1, col_t) curr_mol(end, col_t)];
    inpos  = app.UIAxes_event_labeller.InnerPosition;
    outpos = app.UIAxes_event_labeller.OuterPosition;
    app.UIAxes_event_labeller_status.InnerPosition = [inpos(1), outpos(2)+outpos(4), inpos(3), 20];
    
    %set up the progress bar
    N_mols = numel(app.movie_data.results.VisuallyLabelled.LabelledMols);
    axis(app.UIAxes_labelling_progress, 'off');
    app.UIAxes_labelling_progress.YLim = [0 1];         %should be hardcoded in GUI component's initialisation
    app.UIAxes_labelling_progress.XLim = [0 N_mols];    %should ideally be updated only when new dataset loaded and recalc when mol deleted
    rectangle(app.UIAxes_labelling_progress, 'Position', [0, 0, 1, 1], 'EdgeColor','k', 'FaceColor', 'none');   %inefficient, shouldn't require redrawing
    rectangle(app.UIAxes_labelling_progress, 'Position', [0, 0, app.movie_data.state.event_labeller_current_ID, 1], 'EdgeColor','none', 'FaceColor', 'g');
    text_pc = strcat(num2str(app.movie_data.state.event_labeller_current_ID), '/', num2str(N_mols), ' mols (', num2str(100*app.movie_data.state.event_labeller_current_ID / N_mols, '%.1f'), '%)');
    text(app.UIAxes_labelling_progress, app.UIAxes_labelling_progress.XLim(2)/2, 0.5, text_pc, 'HorizontalAlignment', 'center');
    
    %pull video from the correct video file
    if isfield(app.movie_data.params, 'flipped') && app.movie_data.params.flipped
        flipped = true;
    else
        flipped = false;
    end
    app.current_video = illustrateMol(app.movie_data, cell_ID, mol_ID, 0, false, strcat('Cell', num2str(cell_ID), '_Mol', num2str(mol_ID)), 1, flipped);
    
    %display the first video frame (or initialise the handle if this is the first run)
    app.updateVideoFrame(app.movie_data.state.labeller_frame_video);
    
    %populate the track viewer component
    regenerateTrackViewer(app);
    
    %cache data which is static for current molecule for faster draggable line and human annotator key press updates
    app.annotation_data.cached_ylim = ylim(app.UIAxes_event_labeller);
    app.annotation_data.cached_xlim = xlim(app.UIAxes_event_labeller);
    app.annotation_data.col_t       = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Time from start of track (s)');
    app.annotation_data.frame_rate  = app.movie_data.params.frame_rate;
    app.annotation_data.mol_data    = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol;
    
    %regenerate the draggable line
    setupDraggableLine(app);
    
    % if ~strcmp(app.DeepTRACEUIFigure.CurrentObject, app.DeepTRACEUIFigure)
    %     focus(app.DeepTRACEUIFigure);
    % end
end