function [] = fillMissingDefaults(app)
%Populates a DeepTRACE file with any missing parameter values, 09/07/2025.
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
%After loading a DeepTRACE file, some parameters may not be populated,
%particularly if the file is from an earlier version which relied more
%heavily on the live state of GUI inputs. This enables more robust
%compatibility with previous versions, and enables the handing off of more
%GUI controls to a dedicated settings app, which in turns reduces the GUI
%app handles clutter, improving app performance.
%
%A hacky alternative would be to essentially call the General Settings
%PopUp app (not currently in public repo) after data preparation or file
%loading, as this would pre-fill, but this may confuse the user.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if ~isprop(app, "movie_data") || ~isfield(app.movie_data, "params")
        app.textout.Value = "No valid DeepTRACE file is loaded.";
        return;
    end
    
    default_params = struct(...
        'dr_lo', 525, ...                       %dynamic range lower bound
        'dr_hi', 1200,...                       %dynamic range upper bound
        'dr_auto', 'Auto',...                   %dynamic range adjustments set to auto
        'overlay_pc', 30,...                    %reference image overlay opacity
        'video_upscaling_factor', 4,...         %number of pixels in each axis to assign to each real video pixel
        'export_frame_rate', 5,...              %frame rate of exported animated GIFs
        'autosave_interval', 10,...             %number of tracks between each autosave checkpoint in human annotation process
        'N_autosave_files', 3,...               %number of autosave files to use with human annotation process (oldest is always overwritten)
        'save_data_with_ill', true,...          %when user saves a video illustration, should the associated data be saved alongside
        'primary_feature', 'Step size (nm)',... %primary feature for plotting in human annotator
        'secondary_feature', '<< None >>',...   %secondary feature for plotting in human annotator
        'display_secondary', false,...          %display secondary feature in human annotator
        'FOV', size(app.movie_data.brightfield_image)...   %dimensions of the reference image (should be identical to fluroescence recording
    );
    
    %loop through default fields and populate missing ones
    param_fields = fieldnames(default_params);
    for ii = 1:numel(param_fields)
        field = param_fields{ii};
        if ~isfield(app.movie_data.params, field)
            app.movie_data.params.(field) = default_params.(field);
        end
    end
end