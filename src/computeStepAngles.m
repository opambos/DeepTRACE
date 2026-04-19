function [angles] = computeStepAngles(track)
%Compute the list of step angles for a trajectory, 15/04/2022.
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
%track      (mat)   (x,y) coordinate list for a single molecular trajectory
%
%Output
%------
%angles     (mat)   matrix of two columns
%                       col1: step angles relative to x-axis (in radians) in range -pi to +pi, first element is zero
%                       col2: step angles relative to previous step (in radians), first element is zero
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %pre-allocate
    angles = zeros(size(track,1), 2);
    
    for ii = 2:size(track,1)
        %compute angle relative to FOV x-axis
        angles(ii,1) = atan2(track(ii,2) - track(ii-1,2), track(ii,1) - track(ii-1,1));

        %compute angle relative to previous step
        if ii > 2
            %these statements should have been used for calc relative to FOV as calc is repeated
            x1 = track(ii-2,1);
            x2 = track(ii-1,1);
            x3 = track(ii,1);
            y1 = track(ii-2,2);
            y2 = track(ii-1,2);
            y3 = track(ii,2);
            
            %compile three most recent localisations, and translate such
            %that second point is at origin
            curr_pts        = [x1, y1; x2, y2; x3, y3];
            curr_pts(:,1)   = curr_pts(:,1) - curr_pts(2,1);
            curr_pts(:,2)   = curr_pts(:,2) - curr_pts(2,2);

            %rotate such that previous step was along +ve x-axis
            theta       = angles(ii-1,1);
            R           = [cos(theta) -sin(theta); sin(theta) cos(theta)];
            curr_pts    = curr_pts * R;
            
            %compute rotation angle of displacement of molecule
            angles(ii,2) = atan2(curr_pts(3,2), curr_pts(3,1));
        end
    end
end