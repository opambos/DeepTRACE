function [] = regenerateTrackViewer(app)
%Regenerate the track viewer inside the human annotation system, Oliver
%Pambos, 08/08/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: regenerateTrackViewer
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
%This function regenerates all components of the track viewer component
%inside the human annotation system.
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
%placeScaleBar()
%getFeatureStats()
%plotColourTrack()
    
    cell_ID = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.CellID;
    mol_ID = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.MolID;

    %display the mesh over the overlay
    imagesc(app.movie_data.cellROI_data(cell_ID).overlay, 'parent', app.UIAxes_event_labeller_mesh);
    axis(app.UIAxes_event_labeller_mesh, 'equal');
    axis(app.UIAxes_event_labeller_mesh, 'off');
    hold(app.UIAxes_event_labeller_mesh, 'on');
    colormap(app.UIAxes_event_labeller_mesh, gray(256));
    
    %obtain track
    track = app.movie_data.cellROI_data(cell_ID).tracks(app.movie_data.cellROI_data(cell_ID).tracks(:,4) == mol_ID, :);
    
    %correct offset between cropped image and track - note that the offset applied by LoColi's ROI_tracking function appears to have already been applied to the localisation data
    track(:,1) = track(:,1) - app.movie_data.cellROI_data(cell_ID).overlay_offset(2);
    track(:,2) = track(:,2) - app.movie_data.cellROI_data(cell_ID).overlay_offset(1);
    
    %plot the track
    %plotColourTrack(app.UIAxes_event_labeller_mesh, "Rainbow", "Lines", track, app.movie_data.params.event_label_colours);
    
    %get feature data and plot track
    feat_idx = findColumnIdx(app.movie_data.params.column_titles.tracks, app.PrimaryFeatureDropDown.Value);
    getFeatureStats(app, false);    %recalculate feature ranges if required
    plotColourTrack(app.UIAxes_event_labeller_mesh, 'Colour', 'Feature', track(:, 1:2), 0, track(:, feat_idx), app.movie_data.params.feature_stats(:, feat_idx));
    
    %add a scalebar; set size, position, draw rectangle, add text label
    if app.ScalebarCheckBox.Value
        placeScaleBar(app, app.UIAxes_event_labeller_mesh);
    end
end



