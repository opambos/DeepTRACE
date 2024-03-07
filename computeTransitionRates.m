function [transition_rates, state_transitions] = computeTransitionRates(movie_data)
%Computes the number and frequency of transitions between all possible
%state combinations, Oliver Pambos, 18/09/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeTransitionRates
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
%The square transition matrices describe state transition from on the
%y-axis (dimension 1, )and state transition TO on the x-axis (dimension 2).
%
%Update 07/03/2024: the active labelled dataset is now copied to the
%substruct `InsightData` through the `Source data` GUI component.
%Downstream analysis code, including this function, now operate directly
%on this dedicated substruct. This greatly simplifies and generalises the
%analysis codebase, enabling functions such as this one to operate on any
%labelled dataset defined dynamically during runtime. This also enables
%analysis of future labelling types without having to locally hardcode
%rules, and eliminates the need for state variables to keep track of the
%current analysis target.
%
%Input
%-----
%movie_data         (struct)    main data struct, originally inherited from LoColi
%state_times        (vec)       row vector containing the total time spent in each state, computed by computeTotalStateTimes(), units are in frames         ---- NO LONGER USED ----
%
%Output
%------
%transition_rates   (mat)       rates of transition between all possible state combinations in VisuallyLabelled data, units are in seconds
%state_transitions  (mat)       total number of transitions between all possible state combinations in VisuallyLabelled data
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeTotalStateTimes()
%condenseStateSequence()
    
    [state_times, ~] = computeTotalStateTimes(movie_data);
    
    %preallocate state transition matrices
    state_transitions   = zeros(size(movie_data.params.class_names,1), size(movie_data.params.class_names,1));
    transition_rates    = zeros(size(movie_data.params.class_names,1), size(movie_data.params.class_names,1));
    
    %raster scan through 2D state transition matrix
    for state1 = 1:size(movie_data.params.class_names,1)
        for state2 = 1:size(movie_data.params.class_names,1)
            count = 0;
            
            if state1 ~= state2
                %loop through all labelled mols counting the number of events
                for kk = 1:size(movie_data.results.InsightData.LabelledMols,1)
                    %get the state sequence, then count the number of transitions in the sequence
                    curr_sequence = condenseStateSequence(movie_data.results.InsightData.LabelledMols{kk, 1}.Mol(:,end));
                    occurrences = strfind(curr_sequence, [num2str(state1) num2str(state2)]);
                    count = count + size(occurrences,2);
%                    disp(num2str(state1) + "; " + num2str(state2) + "; state sequence: " + string(curr_sequence) + "; there were occurrences at positions " + num2str(occurrences) + "; total count so far is: " + num2str(count));    %testing only
                end
                %enter the count in the 2D state transition matrix
                state_transitions(state1, state2) = count;
            end
    
            %compute rates of transition between all states
            transition_rates(state1, state2) = state_transitions(state1, state2) ./ state_times(state1);
        end
    end
end
