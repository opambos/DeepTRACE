function [events] = getStateEntrances(mol, state)
%Extracts all of the exits from a labelled molecule matrix for a given
%state, and returns the events, Oliver Pambos, 26/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getStateEntrances
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
%This code works by flipping the molecule's dataset, then running
%getStateExits(), on the reversed molecule, and then flipping the result.
%Doing so simplifies the code.
%
%Inputs
%------
%mol    (mat)   labelled molecule data, rows are localisations, columns
%                   are features, except final column which is the state label
%state  (int)   ID associated with the state of interest
%
%Output
%------
%events (mat)   the events present in the molecule, rows are events
%                   col 1: row number of start of state of interest
%                   col 2: row numer of transition to next state (i.e. the exit)
%                   col 3: row number of end of next state, or end of mol
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%getStateExits()
    
    mol = flipud(mol);
    events = getStateExits(mol, state);
    if isempty(events)
        return;
    end
    events = ((events - size(mol,1)/2).*-1) + size(mol,1)/2 + 1;
    events(:,2) = events(:,2) + 1;  %accounts for the fact that col 2 is on the wrong side of the transition (entrances vs exits)
    events = fliplr(events);
    events = flipud(events);        %there is no need to replace these operations with rot90(events,2) as suggested
end