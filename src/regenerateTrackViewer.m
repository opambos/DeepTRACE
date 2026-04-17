function [] = regenerateTrackViewer(app)
%Regenerate the track viewer inside the human annotation system, Oliver
%Pambos, 08/08/2024.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
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
    
    %if necessary, flip track display in human annotator's track viewer
    if isfield(app.movie_data.params, "flipped") && app.movie_data.params.flipped
        img_hei = size(app.movie_data.brightfield_image, 1);
        track(:, 2) = track(:, 2) - (img_hei/2);
        track(:, 2) = -1 .* track(:, 2);
        track(:, 2) = track(:, 2) + (img_hei/2);
    end
    
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