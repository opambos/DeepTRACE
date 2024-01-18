function [events] = getStateExits(mol, state)
%%Extracts all of the entrances from a labelled molecule matrix for a given
%state, and returns the events, Oliver Pambos, 25/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getStateExits
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
%This code scans through a labelled single molecule matrix, which contains
%a large number of features, the last of which is the state label. This
%code is agnostic as to the source of the labelling.
%
%Procedure
%When start of state is found write start point to matrix (col 1)
%When transition to another state is found, write this point to matrix (col 2)
%When end of that state (or end of molecule) is found, write this point to matrix (col 3)
%If the end of the non-state-of-interest is found before the end of the molecule,
%then reset all vars and continue searching.
%
%Input
%-----
%mol    (mat)   labelled single molecule data, rows are localisations, columns
%                   are features, except final column which is state label
%state  (int)   state of interest
%
%Output
%------
%events (mat)   the events present in the molecule; rows are events,
%                   col 1: row number of start of state of interest
%                   col 2: row numer of transition to next state (i.e. the exit)
%                   col 3: row number of end of next state, or end of mol
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %initialisation
    n_event = 1;
    events = [];

    %set state of interest bool
    if mol(1,end) == state
        events(1,1) = 1;
        SOI = true;
    else
        SOI = false;
    end
    
    for ii = 2:size(mol,1)
        %if it's an exit
        if SOI == true && mol(ii,end) ~= state
            SOI = false;
            events(n_event,2) = ii;
            if ii == size(mol,1)
                events(n_event,3) = ii;
            end

        %if it's a transition from a non-state back to a new state of interest, and it's not the final step
        elseif SOI == false && mol(ii,end) == state
            if ~isempty(events)
                events(n_event,3) = ii - 1;
                n_event = n_event + 1;
            end
            %assuming it's not the final localisation
            if ii < size(mol,1)
                events(n_event,1) = ii;
            end
            SOI = true;
        
        %if it's a continuation of the non-interesting state and the final step in the trajectory
        elseif SOI == false && mol(ii,end) ~= state && ii == size(mol,1) && ~isempty(events)
            events(n_event,3) = ii;
        
        %if end of molecule is reached before a new exit is found, then delete the current entry
        elseif SOI == true && mol(ii,end) == state && ii == size(mol,1) && ~isempty(events)
            events(end,:) = [];
        end
    end
end