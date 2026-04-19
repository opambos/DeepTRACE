function [points] = rotate2D(points, theta)
%Rotate points in 2D, 21/02/2018.
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
%This code was originally written for an earlier project (Cluster Tracker).
%
%This function rotates a set of points in 2D about an angle theta in
%degrees. Note that this function does not consider the offset, it simply
%rotates all the points about the origin (x, y) = (0, 0).
%
%Input
%-----
%points     Points to be rotated, each row contains (x, y)
%
%Output
%------
%points     Rotated points, each row contains (x', y')
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %rotation matrix, R
    R = [cosd(theta), -sind(theta); sind(theta), cosd(theta)];
    
    %loop over all points
    for i = 1:size(points, 1)
        %apply rotation
        points(i,1:2) = R*(points(i,1:2)');
    end
end