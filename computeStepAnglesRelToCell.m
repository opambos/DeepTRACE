function [angles] = computeStepAnglesRelToCell(track, cell_poles)
%Compute the step angles for every step in a track relative to the cell
%axis, Oliver Pambos, 27/04/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeStepAnglesRelToCell
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
        
        title(num2str(angles(ii,1)));
    end
    
end