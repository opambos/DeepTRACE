function [state_times, state_proportions] = computeTotalStateTimes(movie_data)
%Computes the total time spent in each of the states, Oliver Pambos,
%20/07/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeTotalStateTimes
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
%Cycles through all molecules keeping track of the total number of frames
%assigned to each state globally. This is then scaled by the inter-frame
%time to obtain the total residence time in each state. Molecules
%containing any unassigned or erroneous state IDs are ignored.
%
%This method currently introduces a negligible error in cases where the
%memory parameter is used because a step of two frames will be added to the
%statistics as one. This negligible effect may be handled in a future
%update by computing compute the time between frames - this would be less
%computationally efficient but could be achieved by introducing logic
%operating on a call to diff() which passes the 'time from start of track'
%column.
%
%Inputs
%------
%movie_data         (struct)    main data struct, inherited originally from LoColi
%label_type         (char)      location of substruct containing labelled data;
%                               currently restricted to 'VisuallyLabelled' as
%                               app is primarily used for manual 1D segmentation;
%                               future versions may re-introduce previously used
%                               changepoint-labelled and ML-labelled data as a 
%                               separate substruct;
%
%Outputs
%-------
%state_times        (vec)       row vector containing the total time spent in each state
%state_proportions  (vec)       row vector containing the proportion of the total observation time of all labelled molecules spent in each state
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_classes   = size(movie_data.params.class_names,1);
    state_times = zeros(1,N_classes);
    
    %loop over all molecules
    for ii = 1:size(movie_data.results.InsightData.LabelledMols,1)
        %check all labels are valid
        if all(movie_data.results.InsightData.LabelledMols{ii,1}.Mol(:,end) > 0 & movie_data.results.InsightData.LabelledMols{ii,1}.Mol(:,end) <= N_classes)
            %increment counters for each class
            for kk = 1:N_classes
                state_times(kk) = state_times(kk) + sum(movie_data.results.InsightData.LabelledMols{ii, 1}.Mol(:, end) == kk);
            end     
        end
    end
    
    %convert to seconds
    state_times = state_times ./ movie_data.params.frame_rate;

    %compute the fraction of time spent in each state
    state_proportions = state_times / sum(state_times);
    
end
