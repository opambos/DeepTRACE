function [angles] = computeStepAnglesRelToCell(track, cell_poles)
%Compute the step angles for every step in a track relative to the cell
%axis, 27/04/2023.
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
%track      (mat)   Nx2 matrix of coordinates of track with columns of (x,y)
%cell_poles (mat)   2x2 matrix of coordinates for cell poles row 1: (x,y) for pole 1; row 2: (x,y) for pole 2
%
%Output
%------
%angles     (vec)   step angles relative to the cell axis in degrees
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %pre-allocate
    angles = zeros(size(track,1),1);
    
    for ii = 2:size(track,1)
        %translate both vectors to the origin (0,0)
        v1 = [track(ii,1)-track(ii-1,1), track(ii,2)-track(ii-1,2), 0];
        v2 = [cell_poles(2,1) - cell_poles(1,1), cell_poles(2,2)-cell_poles(1,2), 0];
        
        %compute the angle between the two vectors
        angles(ii,1) = atan2d(norm(cross(v1,v2)),dot(v1,v2));
        
        %if the angle is greater than 180 degrees, subtract it from 360 degrees
        if angles(ii,1) > 90
            angles(ii,1) = abs(180 - angles(ii,1));
        end
    end
end