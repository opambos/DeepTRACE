function [condensed_state_sequence] = condenseStateSequence(track)
%Determines the class of event present in a track, Oliver Pambos,
%18/11/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: condenseStateSequence
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
%This function takes in the refined state sequence of a track, and
%identifies the type of event(s) found.
%
%Input
%-----
%track                      (vec)   column vector of integers representing the state sequence of the track
%
%Output
%------
%condensed_state_sequence   (char)  event type, expressed as a series of integers in a char array
%                                   0:      no event present
%                                   1:      continuous event of lowest diffusion state
%                                   2:      continuous event of second diffusion state
%                                   N:      (where N is a positive integer) continuous event of diffusion state N
%                                   21:     fast-slow transition
%                                   12:     slow-fast transition
%                                   MN:     (where M and N are positive integers) transition from state M to state N (not currently supported)
%                                   212:    "full" event, fast-slow-fast
%                                   121:    slow-fast-slow event
%                                   MNM:    (M, N both positive integers) transition from state M to N to M (not currently supported)
%                                   >3 digits: multiple transition event
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    curr_state = track(1);
    if curr_state ~= 0
        condensed_state_sequence = num2str(curr_state);
    else
        condensed_state_sequence = '';
    end
    for i = 2:size(track,1)
        if track(i) ~= curr_state && track(i) ~= 0
            curr_state = track(i);
            condensed_state_sequence = strcat(condensed_state_sequence, num2str(curr_state));
        end
    end
    
    if strcmp(condensed_state_sequence,'')
        condensed_state_sequence = num2str(0);
    end
end

