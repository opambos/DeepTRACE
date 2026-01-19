function [vid_idx, loc_idx, loc_coords] = getNextAvailablePoint(t, frameseries, locseries)
%Identify the next available point in time series, Oliver Pambos,
%26/10/2022.
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
%Determine from the continuous slider input of the human annotation system
%the next available discrete value in the video stack, and the time series
%trajectory, which may have missing values due to the 2D Gauss fitting and
%band-pass filtering processes from localisation; this essentially
%discretises the continuous distribution from a continuous input slider.
%
%Note that there are never missing frames in the video, but there may be
%missing localisations in the trajectory due to the memory parameter. This
%may in future versions change once complex iALEX patterns are invoked, as
%the frame separator tool I have previously built for complex temporal
%patterning of samples removes frames from the video stack to improve
%storage and aids visualisation.
%
%Inputs
%------
%t              (float)     the continuous input time
%frameseries    (vec)       column vector containing the time points for each frame of the video to be displayed using the human annotation system
%locseries      (mat)       2xN matrix containing the time points (col1: t,
%col2: step size) for each localisation in the trajectory currently displayed using the human annotation system
%
%Outputs
%------
%vid_idx        (int)       the row number of the next timepoint in the unbroken video stack
%loc_idx        (int)       the row number of the next timepoint in the trajectory (which can have missing values)
%loc_coords     (vec)       row vector containing coordinates of the next available localisation to highlight
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    vid_idx = ceil(round((t * (size(frameseries,1) - 1) / frameseries(end,1)) + 1, 6));     %this irritating rounding is required to eliminate arithmetic error following application of ceil() to some inputs
    
    loc_idx = vid_idx;
    
    if loc_idx > size(locseries,1)
        loc_idx = size(locseries,1);
    end
    
    %conversion to single here is necessary to avoid arithmetic issue;
    %limits interframe times to > ~1 microsecond, so will never be an issue
    while single(locseries(loc_idx,1)) > single(frameseries(vid_idx))
        loc_idx = loc_idx - 1;
        
        %ugly, but necessary due to time pressure
        if single(locseries(loc_idx,1)) < single(frameseries(vid_idx))
            loc_idx = loc_idx + 1;
            break
        end
    end
    
    loc_coords = locseries(loc_idx,:);
end