function [] = regenerateLabelButtons(app)
%Regenerate the state label button list during runtime, 29/10/2022.
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
%This function generates an array of buttons and labels (column 1 labels,
%column 2 is buttons) inside the label state selection panel during
%runtime inside a grid. This grid dynamically resizes, rescaling its
%contents based on the available space, for example by adjusting button
%width and height.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle, now with the generated buttons
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%eventLabelButtonCallback()
%addPartialVisualLabel()    - called from local callback function
    
    %delete existing buttons
    if numel(app.Event_label_buttons.Children) > 0
        delete(app.Event_label_buttons.Children);
    end
    
    %compute required number of rows and columns; two columns for every button (one hold the number, the other the button itself)
    N_buttons   = size(app.movie_data.params.class_names, 1);
    N_rows      = min(N_buttons, 5);        
    N_cols      = ceil(N_buttons / 5) * 2;
    
    %build a grid layout object to hold the buttons, make digit-holding column 10x smaller than button-holding columns
    grid_layout = uigridlayout(app.Event_label_buttons, [N_rows, N_cols]);
    grid_layout.ColumnWidth = repmat({'1x', '10x'}, 1, ceil(N_buttons / 5));
    grid_layout.RowHeight = repmat({22}, 1, N_rows);
    grid_layout.BackgroundColor = [1 1 1]; %set background colour to white
    
    %generate buttons & labels on the fly
    for ii = 1:N_buttons
        column_offset = floor((ii - 1) / 5) * 2; %determine the column offset for each set of four buttons
        
        %add button label
        label = uilabel(grid_layout, 'Text', num2str(ii) + ".");
        label.Layout.Row = mod(ii - 1, 5) + 1;
        label.Layout.Column = 1 + column_offset;
        label.FontName = 'Arial'; label.FontSize = 14;
        
        %generate button
        btn = uibutton(grid_layout, 'Text', app.movie_data.params.class_names(ii), 'ButtonPushedFcn', @(btn,event) eventLabelButtonCallback(app, btn));
        btn.Layout.Row = mod(ii - 1, 5) + 1;
        btn.Layout.Column = 2 + column_offset;
        btn.FontName = 'Arial'; btn.FontSize = 14;
    end
end