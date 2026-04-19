function [] = undoLabel(app)
%Undoes the most recent label in the human annotation system, 02/06/2024.
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
    focus(app.DeepTRACEUIFigure);
end