function [video] = saveMolVideo(video, frame_rate, filetype, pathname, overlay, overlay_pc, dr_mode, save_to_disk)
%Saves a video of a molecule with BF overlay, Oliver Pambos, 10/11/2020.
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
%The output format is a looping gif video. This is saved relative to the
%current project path defined as ffPath inside the movie_data.params
%substruct. This subroutine can also run without saving a video to disk in
%order to either display the video to the user without saving, or to
%combine the fluorescence and inverted brightfield data and passed to
%another function for further use.
%
%Note that dynamic range adjustments are applied to the fluorescence video
%by illustrateMol() prior to passing to this function.
%
%Inputs
%------
%video          (mat)       XxYxN image sequence of N frames (fluorescence video)
%frame_rate     (double)    frames per second of output video
%filetype       (str)       'gif' for .gif output; currently only gif video is implemented
%pathname       (str)       full path, and filename, of output file - to avoid saving the file keep this as ~, in this case the function just returns the video stack
%overlay        (mat)       single brightfield frame to overlay - set to 0 if unused
%overlay_pc     (double)    intensity (as a %) of overlay
%dr_mode        (string)    ('auto' or 'manual') determines whether to automatically assign the dynamic range of the image based on max and min values in stack
%save_to_disk   (int)       0 or 1 depending on whether the video is saved to disk
%
%Output
%------
%video          (mat)       XxYxN image sequence of N frames consisting of fluorescence video combined with inverted brightfield overlay
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %note overlays are now stored as uint16, and need rescaling, then conversion to uint8 before using here
    video = video.*255;
    video = double(video);
    overlay = double(overlay);
    
    %combine all frames with overlay
    if size(overlay) ~= [1 1]
        scale_factor = (max(max(max(double(video)))) / max(max(double(overlay)))) * (overlay_pc/100);
        overlay         = overlay .* scale_factor;
        
        %loop over all video frames, and combine with re-scaled overlay
        for i = 1:size(video, 3)
            video(:,:,i) = video(:,:,i) + overlay;
        end
    end
    
    video = mat2gray(video);
    
    %save video
    if save_to_disk == 1
        if strcmp(filetype,'gif') && exist('pathname', 'var')
                video = video .*255;
                video = uint8(video);
            imwrite(video(:,:,1), pathname, 'Loopcount', inf, 'DelayTime', 1/frame_rate);
            
            for i = 2:size(video,3)
              imwrite(video(:,:,i), pathname, 'WriteMode', 'append', 'DelayTime', 1/frame_rate); 
            end

            % <further filetypes here if required>
        else
            disp('Error in saveMolVideo: unknown filetype');
        end
    else
        video = video .*255;
        video = uint8(video);
    end 
end