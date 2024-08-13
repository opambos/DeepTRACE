function [events] = extractLabelledState(mol, state_ID, col_t)
%Extract a given state from a labelled trajectory, Oliver Pambos,
%29/10/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: extractLabelledState
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
%This function retrieves an individual trajectory, then by scanning it
%row by row compiles a list of all transitions into and out of a given
%state, and returns all states as an Nx4 matrix describing its duration, 
%and truncation.
%
%Note that as with other functions this relies on the state label being the
%final column. Should have pre-allocated matrices here, but performance
%overhead is negligible.
%
%Update: following changes to feature engineering process, this function
%now resolves the time column outside the function, which is passed as the
%input col_t. This eliminates hardcoding, and improves modularity.
%
%Inputs
%------
%mol        (mat)   the contents of app.movie_data.results.VisuallyLabelled.LabelledMols{ii, 1}.Mol
%                       for a given molecule ii
%state_ID   (int)   state being interrogated
%col_t      (int)   time column in the matrix mol
%
%Output
%------
%app    (handle)    main GUI handle containing a new cell array,
%                       app.movie_data.results.VisuallyLabelled.extractedStates
%                       which contains the list of events for each state in
%                       the entire dataset, each entry in the cell array
%                       contains an Nx4 matrix with the columns,
%                           col 1: state_ID
%                           col 2: duration, in seconds
%                           col 3: left truncated?  (1 yes, 0 no)
%                           col 4: right truncated? (1 yes, 0 no)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    events = [];
    
    state_start = -1;   %time entry for first localisation in state
    state_end   = -1;   %time entry for final localisation in state
    event_count = 0;    %keeping  track of the number of events
    
    %loop over all localisations in trajectory
    for ii = 1:size(mol,1)
        %start of a new state
        if state_start == -1 && mol(ii,end) == state_ID
            state_start = mol(ii, col_t);
            event_count = event_count + 1;
            
            %if it's the first localisation, then it's left truncated
            if ii == 1
                events(event_count,1) = state_ID;
                events(event_count,3) = 1;
            end
            
        %not a new state, and not a continuation
        elseif state_start == -1 && mol(ii,end) ~= state_ID
            state_start = -1;
            state_end = -1;
            
        %continuation of a state
        elseif state_start ~= -1 && mol(ii,end) == state_ID
            state_end = mol(ii, col_t);
            
        %end of a state
        elseif state_start ~= -1 && mol(ii,end) ~= state_ID
            events(event_count,4) = 0;  %not truncated right
            
            %enter the previous state, then reset variables
            if state_end == -1
                %hacky solution to catch an error for when a state consists
                %only of a single frame (state_end remains as -1); a more
                %complete solution would be to fix the above logic
                events(event_count, 2) = mol(2, col_t) - mol(1, col_t);
            else
                events(event_count, 2) = state_end - state_start;
            end
            events(event_count, 1) = state_ID;
            state_start = -1;
            state_end = -1;
        end
    end
    
    %assign any states right truncated by end of trajectory
    if state_end == mol(end, col_t)
        events(event_count, 1) = state_ID;
        events(event_count, 2) = state_end - state_start;
        if state_start == 0
            events(event_count, 3) = 1; %event is also left truncated
        else
            events(event_count, 3) = 0; %event is only right truncated
        end
        events(end,4) = 1;
    end
    
end