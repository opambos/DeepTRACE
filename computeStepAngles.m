function [angles] = computeStepAngles(track)
%Compute the list of step angles for a trajectory, Oliver Pambos,
%15/04/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeStepAngles
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
    
    for i = 2:size(track,1)
        %compute angle relative to FOV x-axis
        angles(i,1) = atan2(track(i,2) - track(i-1,2), track(i,1) - track(i-1,1));

        %compute angle relative to previous step
        if i>2
            %these statements should have been used for calc relative to FOV as calc is repeated
            x1 = track(i-2,1);
            x2 = track(i-1,1);
            x3 = track(i,1);
            y1 = track(i-2,2);
            y2 = track(i-1,2);
            y3 = track(i,2);
            
            %compile three most recent localisations, and translate such
            %that second point is at origin
            curr_pts = [x1, y1; x2, y2; x3, y3];
            curr_pts(:,1) = curr_pts(:,1) - curr_pts(2,1);
            curr_pts(:,2) = curr_pts(:,2) - curr_pts(2,2);
            
            %rotate such that previous step was along +ve x-axis
            theta = rad2deg(angles(i-1,1));
            R = [cosd(theta) -sind(theta); sind(theta) cosd(theta)];
            curr_pts = curr_pts*R;
            
            %compute rotation angle of displacement of molecule (-ve is counter clockwise, +ve is clockwise)
            angles(i,2) = -atan2d(curr_pts(3,2), curr_pts(3,1));
        end
    end
    
    angles(:,2) = deg2rad(angles(:,2)); %once testing complete swap -atan2d for -atan2, cosd and sind for cos and sin, etc., above to work in radians
    
end
