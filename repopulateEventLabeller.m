function [] = repopulateEventLabeller(app)
%Repopulate the event labeller with a new molecule, Oliver Pambos,
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
%This function clears the relevant components of the Event Labeller, and
%repopulates them with new data associated with the next molecule ready for
%the next manual labelling.
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
    
    %load next mol, which is a callback to the next mol button
    
    %clear the axes and cell_ID and mol_ID display boxes
    cla(app.UIAxes_event_labeller);
    cla(app.UIAxes_event_labeller_status);
    cla(app.UIAxes_labelling_progress);
    cla(app.UIAxes_event_labeller_mesh);
    app.CellIDTextArea.Value = '';
    app.MolIDTextArea.Value = '';
    
    %simplifying code
    cell_ID = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.CellID;
    mol_ID = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.MolID;
    
    %obtain time and user-selected feature column; also write them to the
    %state features
    app.movie_data.state.col_t = find(strcmp(app.movie_data.params.column_titles.tracks, 'Time from start of trajectory (s)'));
    app.movie_data.state.col_feature = find(strcmp(app.movie_data.params.column_titles.tracks, app.FeatureDropDown.Value));

    %set the y-axis label
    ylabel(app.UIAxes_event_labeller, app.FeatureDropDown.Value);
    
    %plot the next molecule - note that column/feature ID for time and step size are currently hardcoded which will change in a future version
    plot(app.UIAxes_event_labeller, app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_t), app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature),...
        'LineWidth', app.LinethicknessSpinner.Value, 'Color', app.LinecolourDropDown.Value, 'Tag', 'step_trace');
    hold(app.UIAxes_event_labeller, 'on');
    xline(app.UIAxes_event_labeller, app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.labelled_so_far+1,1}.Mol(1,app.movie_data.state.col_t), 'LineWidth', app.IndicatorthicknessSpinner.Value, 'Tag', 'current_pos');
    app.movie_data.state.labeller_frame = 1;    %keep track of which frame is currently being displayed, this is incredibly important for performance on slower machine as it greatly reduces number of calls to imagesc()
    app.CellIDTextArea.Value =  num2str(cell_ID);
    app.MolIDTextArea.Value  =  num2str(mol_ID);
    
    %plot the reference lines (if they exist)
    if isfield(app.movie_data.params, 'reference_lines')
        %ensure user hasn't added duplicates
        app.movie_data.params.reference_lines = unique(app.movie_data.params.reference_lines);
        %yline(app.UIAxes_event_labeller, app.movie_data.params.reference_lines, 'r--', string(app.movie_data.params.reference_lines));
        for ii = 1:size(app.movie_data.params.reference_lines,1)
            yline(app.UIAxes_event_labeller, app.movie_data.params.reference_lines, '--', string(app.movie_data.params.reference_lines) + "  ", 'Color', app.ReferencelinecolourDropDown.Value, 'LineWidth', app.ReferencelinethicknessSpinner.Value);
        end
    end
    
    %set ranges for axes of the event labeller
    setLabellerAxesRange(app)

    %place red circle to highlight next labelling point - hardcoded feature/column IDs will be replaced in a future version
    scatter(app.UIAxes_event_labeller, app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.labelled_so_far+1,1}.Mol(1,app.movie_data.state.col_t), app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.labelled_so_far+1,1}.Mol(1,app.movie_data.state.col_feature), 'ro', 'Tag', 'current_loc');
    box(app.UIAxes_event_labeller, 'on');
    app.Slider_event_labeller.Limits = [app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(1,app.movie_data.state.col_t) app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(end,app.movie_data.state.col_t)];
    
    %prevent user being able to drag/zoom/etc.
    disableDefaultInteractivity(app.UIAxes_event_labeller);
    disableDefaultInteractivity(app.UIAxes_event_labeller_status);
    disableDefaultInteractivity(app.UIAxes_labelling_progress);
    
    %set up the status bar above the trajectory labeller
    axis(app.UIAxes_event_labeller_status, 'off');
    app.UIAxes_event_labeller_status.YLim = [0 1];
    app.UIAxes_event_labeller_status.XLim = [app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(1,app.movie_data.state.col_t) app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(end,app.movie_data.state.col_t)];
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
    
    %pull video from the correct FITS file
    app.movie_data.current_video = illustrateMol(app.movie_data, cell_ID, mol_ID, 0, app.SaveeveryviewedmoleculeCheckBox.Value, strcat('Cell', num2str(cell_ID), '_Mol', num2str(mol_ID)));
    
    %display the first video frame
    imagesc(app.movie_data.current_video(:,:,1), 'parent', app.UIAxes_image_event_labeller); %imagesc(app.movie_data.current_video(:,:,1), 'parent', app.UIAxes_image_event_labeller, [app.movie_data.params.dr_lo app.movie_data.params.dr_hi]);
    axis(app.UIAxes_image_event_labeller, 'equal');
    axis(app.UIAxes_image_event_labeller, 'off');
    colormap(app.UIAxes_image_event_labeller, gray(256));
    
    %populate the track viewer component
    regenerateTrackViewer(app);
    
    %update the state positions
    app.movie_data.state.labeller_track_pos     = 1;
    app.movie_data.state.labeller_frame_video   = 1;
    app.movie_data.state.labelled_so_far        = 0;

    %reset frame slider
    app.Slider_event_labeller.Value             = 0;
end
