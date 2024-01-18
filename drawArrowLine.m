function [] = drawArrowLine(h_axes, x1, y1, x2, y2, colour, arr_len, arr_wid, arr_style)
%Draws a line between two points with a triangular arrow at its centre in
%the (x1, y1) to (x2, y2) direction, Cluster Tracker, Oliver Pambos,
%26/02/2018.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: drawArrowLine
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD, UK
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%LEGAL DISCLAIMER
%THIS CODE IS INTENDED FOR USE ONLY BY INDIVIDUALS WHO HAVE RECEIVED
%EXPLICIT AUTHORIZATION FROM THE AUTHOR, OLIVER JAMES PAMBOS. ANY FORM OF
%COPYING, REDISTRIBUTION, OR UNAUTHORIZED USE OF THIS CODE, IN WHOLE OR IN
%PART, IS PROHIBITED. BY USING THIS CODE, USERS SIGNIFY THAT THEY HAVE
%READ, UNDERSTOOD, AND AGREED TO BE BOUND BY THE TERMS OF SERVICE PRESENTED
%UPON SOFTWARE LAUNCH, INCLUDING THE REQUIREMENT FOR CO-AUTHORSHIP ON ANY
%RELATED PUBLICATIONS. THIS APPLIES TO ALL LEVELS OF USE, INCLUDING PARTIAL
%USE OR MODIFICATION OF THE CODE OR ANY OF ITS EXTERNAL FUNCTIONS.
%
%USERS ARE RESPONSIBLE FOR ENSURING FULL UNDERSTANDING AND COMPLIANCE WITH
%THESE TERMS, INCLUDING OBTAINING AGREEMENT FROM THE APPROPRIATE
%PUBLICATION DECISION-MAKERS WITHIN THEIR ORGANIZATION OR INSTITUTION.
%
%NOTE: UPON PUBLIC RELEASE OF THIS SOFTWARE, THESE TERMS MAY BE SUBJECT TO
%CHANGE. HOWEVER, USERS OF THIS PRE-RELEASE VERSION ARE STILL BOUND BY THE
%CO-AUTHORSHIP AGREEMENT FOR ANY USE MADE PRIOR TO THE PUBLIC RELEASE. THE
%RELEASED VERSION WILL BE AVAILABLE FROM A DESIGNATED ONLINE REPOSITORY
%WITH POTENTIALLY DIFFERENT USAGE CONDITIONS.
%
%
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

