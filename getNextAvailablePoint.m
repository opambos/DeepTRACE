function [vid_idx, loc_idx, loc_coords] = getNextAvailablePoint(t, frameseries, locseries)
%Identify the next available point in time series, Oliver Pambos,
%26/10/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getNextAvailablePoint
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
%Determine from the continuous slider input of the event labeller the  next
%available discrete value in the video stack, and the time series
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
%frameseries    (vec)       column vector containing the time points for each frame of the video to be displayed using the event labeller
%locseries      (mat)       2xN matrix containing the time points (col1: t, col2: step size) for each localisation in the trajectory currently displayed using the event labeller
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