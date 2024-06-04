function [] = undoLabel(app)
%Undoes the most recent label in the human annotation system, Oliver
%Pambos, 02/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: undoLabel
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
%If a user makes a mistake during human annotation, this function provides
%a mechanism to unassign the last annotated state. It resets all state
%variables back to their values prior to the state being assigned, and
%clears the associated box and label in the state indicator UIAxes above
%the main plot.
%
%Explanation of video frame index calculation: we can't simply pass
%state_start_idx as current frame because the tracking memory parameter
%results in the possibility of missing localisations; instead I compute the
%frame offset of the current identified localisation within the current
%track to avoid rare occurences of user being presented with the wrong
%video frame after removing a label.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    curr_labels = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.Mol(:,end);
    
    %find the final value > 0
    state_end_idx = find(curr_labels > 0, 1, 'last');
    state_ID         = curr_labels(state_end_idx);
    
    %find the start of this state
    if all(curr_labels(1:state_end_idx) == state_ID)
        state_start_idx = 1;
    else
        state_start_idx = find(curr_labels(1:state_end_idx) ~= state_ID, 1, 'last') + 1;
    end
    
    %replace all entries of final state with -1
    app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.Mol(state_start_idx:state_end_idx, end) = -1;
    
    if state_start_idx > 0
        app.movie_data.state.labelled_so_far = state_start_idx - 1;
    else
        app.movie_data.state.labelled_so_far = 0;
    end
    app.movie_data.state.labeller_track_pos = state_start_idx - 1;
    
    %delete most recent rectangle in state labeller
    if ~isempty(app.UIAxes_event_labeller_status.Children)
        delete(app.UIAxes_event_labeller_status.Children(1:2));
    end
    
    %move the draggable line back to the first unannotated frame
    col_t = findColumnIdx(app.movie_data.params.column_titles.tracks, "Time from start of track (s)");
    x_pos = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.Mol(state_start_idx, col_t);
    app.draggable_line.Position = [x_pos, min(ylim(app.UIAxes_event_labeller)); x_pos, max(ylim(app.UIAxes_event_labeller))];
    
    %update the position tracker
    app.movie_data.state.labeller_track_pos = state_start_idx;
    
    %update the video frame: see function header for explanation here
    app.movie_data.state.labeller_frame_video = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(state_start_idx,3) - app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(1,3) + 1;
    
    %display the correct video frame
    app.updateVideoFrame(app.movie_data.state.labeller_frame_video);
    
    %move the small circle indicating the state being assigned
    [~, ~, coords] = getNextAvailablePoint((x_pos - 0.00001), [0 : (1/app.movie_data.params.frame_rate) : app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(end, col_t)]', [app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:, col_t) app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:, app.movie_data.state.col_feature)]);
    current_loc_obj = findobj(app.UIAxes_event_labeller, 'Tag', 'current_loc');
    current_loc_obj.XData = coords(1);
    current_loc_obj.YData = coords(2);
    
    %return keyboard focus to the human annotation system
    focus(app.InVivoKineticsUIFigure);
end