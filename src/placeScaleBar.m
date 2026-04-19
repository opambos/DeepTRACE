function [] = placeScaleBar(app, ax)
%Insert a scalebar into a trajectory plot, 08/02/2024.
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
%This function generates and positions a scale bar within the
%track-plotting component of the human annotation system.
%
%There is a convoluted process of generating the label, establishing its
%extent within the axes, and then moving it using it's object handle. This
%was necessitated MATLAB treating differently A) the image and the plotted
%data including the scale bar's rectangle which have coordinates that scale
%with the background image, and B) the text which displays at a constant
%size in the GUI regardless of the number of pixels present in the
%background image.
%
%Note that the positional error only occurs in the y-dimension and not the
%x-dimension without this fix because the x-position is determined by an
%average of the scale bar's left and right edges, which is intrinsically
%adjusted as the background image changes in scale, which is not true of
%the offset required to displace the text vertically. Attempts to use the
%same approach in displacing the text using the relative height of the
%scale bar's extent also result in minor displacement errors because the
%relative size of the text (which is defined in `points` and relative to
%external components), and the scale bar itself can also change as the
%extent of the background image changes. The solution I implement here
%resolves all of these issues. If you need to adjust this function I would
%suggesting thinking carefully before doing so. I have left a variable at
%the start of the function (`text_offset_multiplier`) for this purpose.
%
%Input
%-----
%app    (handle)    main GUI handle
%ax     (axes)      handle to axes into which the scale bar is to be placed
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    cell_ID             = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.CellID;
    overlay_size        = size(app.movie_data.cellROI_data(cell_ID).overlay);
    scalebar_height_px  = max(overlay_size) / 60;
    scalebar_length_px  = app.ScalebarlengthSpinner.Value * 1000 / app.movie_data.params.px_scale;
    
    %set how far above scale bar to position text; this is measure in units of "text heights", see comment in header
    text_offset_multiplier = 1.05;
    
    %corner selection
    switch app.ScalebarpositionDropDown.Value
        case 'Top left'
            scale_bar_pos = [2, 6, scalebar_length_px, scalebar_height_px];
        case 'Top right'
            scale_bar_pos = [overlay_size(2) - scalebar_length_px - 1, 6, scalebar_length_px, scalebar_height_px];
        case 'Bottom left'
            scale_bar_pos = [2, overlay_size(1) - 2, scalebar_length_px, scalebar_height_px];
        case 'Bottom right'
            scale_bar_pos = [overlay_size(2) - scalebar_length_px - 1, overlay_size(1) - 2, scalebar_length_px, scalebar_height_px];
    end
    
    %draw scale bar
    rectangle('Position', scale_bar_pos, 'EdgeColor', app.ScalebarcolourDropDown.Value, 'FaceColor', app.ScalebarcolourDropDown.Value, 'Parent', ax);
    
    %add text label
    scalebar_label = string(app.ScalebarlengthSpinner.Value) + " μm";
    h_text = text(scale_bar_pos(1), 10, scalebar_label, 'Color', app.ScalebarcolourDropDown.Value, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top',...
        'FontSize', 12, 'Parent', ax);
    
    %get real extent of text object
    text_height = h_text.Extent(4);
    
    %position the text relative to scalebar object using the text's real size in the figure in pixels
    text_ypos = scale_bar_pos(2) - text_offset_multiplier * text_height;
    set(h_text, 'Position', [scale_bar_pos(1) + scale_bar_pos(3)/2, text_ypos]);
end