function [angles] = computeStepAnglesSimple(track)
%Compute step angles, new version, 18/04/2023.
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
%This is a simplified version of computeStepAngles(), it only computes the
%relative angles in each step as an absolute value (omits sign indicating
%direction). Note that this is the change in the molecule's direction, not
%the angle between the vectors (consider the motion of the molecule).
%
%Input
%-----
%track  (mat)   2xN matrix of (x,y) coordinate list, for N locs in a track
%
%Output
%------
%angle  (vec)   column vector of step angles (in degrees) that represent the changes in direction of the molecule
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeAngle() - local to this .m file
    
    angles = zeros(size(track,1) - 2, 1);
    for ii = 3:size(track,1)    %intentionally including the initial two zeros here
        angles(ii) = computeAngle(track(ii-2, 1:2), track(ii-1, 1:2), track(ii, 1:2));
    end
end


function [angle] = computeAngle(A, B, C)
%Computes the angle between three points, 18/04/2023.
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
%A  (vec)   row vector containing the (x,y) coordinate of the first point
%B  (vec)   row vector containing the (x,y) coordinate of the middle point
%C  (vec)   row vector containing the (x,y) coordinate of the final point
%
%Ouput
%-----
%angle  (float)     the angle ABC, in degrees
    
    %compute the vectors between the three points
    v1 = [B(1)-A(1), B(2)-A(2)];
    v2 = [C(1)-B(1), C(2)-B(2)];
    
    %compute the angle between the vectors in degrees
    angle = acosd(dot(v1, v2) / (norm(v1) * norm(v2)));
end