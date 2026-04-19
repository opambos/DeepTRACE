function [file_list] = confirmVideoOrder(file_list)
%Present the user with the video file list, and rearrange if required,
%13/11/2020.
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
%This function replaces parts of the earlier text-based command line entry
%method identifyFITSFiles(). This function displays a listbox in an
%external figure window containing the list of source video files to be
%ordered by the user. The user is able to reorder files by moving them up
%and down the list. This updated list is then returned so that the calling
%function can re-organise the file list. This is required to avoid issues
%of either the user selecting the video source files in the wrong order, or
%the files themselves not being alphabetical. It also resolves an issue in
%Windows 10 machines in which the file selection tool appears to performs
%an operation in which the first and last selected files become
%mis-ordered. This appears to be an issue across multiple Windows
%applications rather than related to MATLAB. This function eliminates all
%of these issues, and enables the code to run cross-platform.
%
%Input
%-----
%file_list  (cell)  1xN cell array containing char arrays of file names for all video files
%
%Output
%------
%file_list  (cell)  1xN cell array containing char arrays of file names for all video files, possibly reordered by user
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %create the figure window containing a listbox, and buttons
    h_fig = uifigure('Name', 'Reorder List', 'Position', [100, 100, 800, 400]);
    h_lb = uilistbox(h_fig, 'Items', file_list, 'Position', [50, 100, 700, 250]);
    
    btn_up      = uibutton(h_fig, 'Text', 'Up', 'Position', [50, 60, 100, 20], 'ButtonPushedFcn', @(btn, event) moveFileUp(h_lb));
    btn_down    = uibutton(h_fig, 'Text', 'Down', 'Position', [150, 60, 100, 20], 'ButtonPushedFcn', @(btn, event) moveFileDown(h_lb));
    btn_ok      = uibutton(h_fig, 'Text', 'OK', 'Position', [50, 20, 100, 20], 'ButtonPushedFcn', @(btn, event) finishReordering(h_fig, true));
    btn_cancel  = uibutton(h_fig, 'Text', 'Cancel', 'Position', [150, 20, 100, 20], 'ButtonPushedFcn', @(btn, event) finishReordering(h_fig, false));
    
    %wait until figure window is closed
    uiwait(h_fig);
    
    if isvalid(h_fig)
        file_list = h_lb.Items;
        close(h_fig);
    end
end


function [] = moveFileUp(h_lb)
%Callback to swap currently selected item with item above, 13/11/2020.
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
%
%Input
%-----
%h_lb   (handle)    handle to the listbox UI
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    curr_item = h_lb.Value;
    all_items = h_lb.Items;
    idx = find(strcmp(all_items, curr_item));
    
    if idx > 1
        all_items([idx-1, idx]) = all_items([idx, idx-1]);
        h_lb.Items = all_items;
        h_lb.Value = all_items{idx - 1};
    end
end


function [] = moveFileDown(h_lb)
%Callback to swap currently selected item with item below, 13/11/2020.
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
%
%Input
%-----
%h_lb   (handle)    handle to the listbox UI
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    curr_item = h_lb.Value;
    all_items = h_lb.Items;
    idx = find(strcmp(all_items, curr_item));
    
    if idx < numel(all_items)
        all_items([idx, idx+1]) = all_items([idx+1, idx]);
        h_lb.Items = all_items;
        h_lb.Value = all_items{idx + 1};
    end
end


function [] = finishReordering(h_fig, carry_on)
%Callback for OK and Cancel buttons, 13/11/2020.
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
%This callback is necessary to avoid accessing property .Items of the
%possibly deleted object defined by the handle h_fig.
%
%
%Input
%-----
%h_fig      (handle)    handle to the figure window
%carry_on   (bool)      if user has pressed OK button this will invoke uiresume to break out of uiwait() f'n
%                           if user has pressed cancel button this will delete figure handle h_fig
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if carry_on
        uiresume(h_fig);
    else
        delete(h_fig);
    end
end
