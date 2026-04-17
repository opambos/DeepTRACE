function [] = drawArrowLine(h_axes, x1, y1, x2, y2, colour, arr_len, arr_wid, arr_style)
%Draws a line between two points with a triangular arrow at its centre in
%the (x1, y1) to (x2, y2) direction, Cluster Tracker, Oliver Pambos,
%26/02/2018.
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
%This function plots a line, computes the angle between the points,
%constructs a virtual triangle around the origin, then rotates and
%translates this into place at the midpoint of the line. The plotting is
%performed inside the desired axes handle passed to the function.
%
%Inputs
%------
%x_axes     (handle)    axes handle
%x1, y1     (float)     coordinates for the first point
%x2, y2     (float)     coordinates for the second point
%colour     (vec)       row vector colour of the line and arrow to plot in RGB value
%arr_len    (float)     length of the arrow (along the line)
%arr_wid    (float)     width of arrow (perpendicular to line)
%arr_style  (char)      style of arrow: 'unfilled gives line arrow', 'filled' gives filled triangle style
%
%Dependent functions
%-------------------
%rotate2D()
%findEuclidDist()
    
    %plot the line
    plot(h_axes, [x1; x2], [y1; y2], '-', 'Color', colour);
    hold on;
    
    %calculate clockwise rotation angle
    phi = atand((x2 - x1)/(y2 - y1));
    
    %generate a virtual triangle around (0, 0)
    tri(1, :) = [-arr_wid/2 -arr_len/2];
    tri(2, :) = [0          arr_len/2];
    tri(3, :) = [arr_wid/2  -arr_len/2];
    
    %rotate triangle to correct angle
    if y2 >= y1
        tri = rotate2D(tri, -phi);
    else
        tri = rotate2D(tri, -phi + 180);
    end
    
    %move triangle to mid-point of line
    tri(:, 1) = tri(:, 1) + mean([x1 x2]);
    tri(:, 2) = tri(:, 2) + mean([y1 y2]);
    
    %plot triangle if there is enough space (3* arrow length)
    if findEuclidDist([x1 y1], [x2 y2]) > arr_len*3
        switch arr_style
            case 'unfilled'
                plot(h_axes, tri(:, 1), tri(:, 2), 'Color', colour);
            case 'filled'
                fill(tri(:, 1), tri(:, 2), colour, 'EdgeColor', 'none');
            otherwise
                disp('Error in drawArrowLine: no valid arrow type (either unfilled or filled).');
        end
    end
    axis equal;
end