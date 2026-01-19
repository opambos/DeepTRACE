function [points] = rotate2D(points, theta)
%Rotate points in 2D, Oliver Pambos, 21/02/2018.
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