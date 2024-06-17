function [] = repopulateEventLabeller(app)
%Repopulate the human annotation system with a new molecule, Oliver Pambos,
%28/10/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: repopulateEventLabeller
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
    
    %load next mol, which is a callback to the next mol button
    
    %clear the axes and cell_ID and mol_ID display boxes
    cla(app.UIAxes_event_labeller, 'reset');
    cla(app.UIAxes_event_labeller_status);
    cla(app.UIAxes_labelling_progress);
    cla(app.UIAxes_event_labeller_mesh);
    app.CellIDTextArea.Value = '';
    app.MolIDTextArea.Value = '';
    
    %update the state positions
    app.movie_data.state.labeller_track_pos     = 1;
    app.movie_data.state.labeller_frame_video   = 1;
    app.movie_data.state.labelled_so_far        = 0;
    
    %find column indices
    col_t = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Time from start of track (s)');
    if col_t == 0
        error("repopulateEventLabeller:MissingTimeColumn", "The required time column ('Time from start of track (s)') is missing from the dataset.");
    end
    
    col_primary     = findColumnIdx(app.movie_data.params.column_titles.tracks, app.PrimaryFeatureDropDown.Value);
    app.movie_data.state.col_feature = col_primary;
    if col_primary == 0
        error("repopulateEventLabeller:MissingPrimaryFeature", "The primary feature column is missing in the column titles of the dataset.");
    end
    
    col_secondary   = findColumnIdx(app.movie_data.params.column_titles.tracks, app.SecondaryFeatureDropDown.Value);
    if col_secondary ~= 0
        app.movie_data.state.col_feature_secondary = col_secondary;
    end
    if ~strcmp(app.SecondaryFeatureDropDown.Value, '<< None >>') && col_secondary == 0
        error("repopulateEventLabeller:MissingPrimaryFeature", "The secondary feature column is missing in the column titles of the dataset.");
    end
    
    %simplifying code
    cell_ID         = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.CellID;
    mol_ID          = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.MolID;
    curr_mol        = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol;
    
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

        %also disable interactive tools in secondary axis while this is convenient
        disableDefaultInteractivity(app.UIAxes_event_labeller);
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
    scatter(app.UIAxes_event_labeller, app.movie_data.results.VisuallyLabelled.LabelledMols{1,1}.Mol(1, col_t), app.movie_data.results.VisuallyLabelled.LabelledMols{1,1}.Mol(1,col_primary), 'ro', 'Tag', 'current_loc', 'SizeData', 100, 'LineWidth', 1.5);
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
    axis(app.UIAxes_labelling_progress, 'off');
    app.UIAxes_labelling_progress.YLim = [0 1];
    app.UIAxes_labelling_progress.XLim = [0 size(app.movie_data.results.VisuallyLabelled,1)];
    rectangle(app.UIAxes_labelling_progress, 'Position', [0, 0, 1, 1], 'EdgeColor','k', 'FaceColor', 'none');
    rectangle(app.UIAxes_labelling_progress, 'Position', [0, 0, app.movie_data.state.event_labeller_current_ID/size(app.movie_data.results.VisuallyLabelled.LabelledMols,1), 1], 'EdgeColor','none', 'FaceColor', 'g');
    text_pc = strcat(num2str(app.movie_data.state.event_labeller_current_ID), '/', num2str(size(app.movie_data.results.VisuallyLabelled.LabelledMols,1)), ' mols (', num2str(100*app.movie_data.state.event_labeller_current_ID/size(app.movie_data.results.VisuallyLabelled.LabelledMols,1), '%.1f'), '%)');
    text(app.UIAxes_labelling_progress, app.UIAxes_labelling_progress.XLim(2)/2, 0.5, text_pc, 'HorizontalAlignment', 'center');
    
    %pull video from the correct video file
    app.movie_data.current_video = illustrateMol(app.movie_data, cell_ID, mol_ID, 0, app.SaveeveryviewedmoleculeCheckBox.Value, strcat('Cell', num2str(cell_ID), '_Mol', num2str(mol_ID)), 1);

    %display the first video frame (or initialise the handle if this is the first run)
    app.updateVideoFrame(app.movie_data.state.labeller_frame_video);
    
    %populate the track viewer component
    regenerateTrackViewer(app);
    
    %regenerate the draggable line
    setupDraggableLine(app);

    %return keyboard focus to the human annotation system
    focus(app.InVivoKineticsUIFigure);
end