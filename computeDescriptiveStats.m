function [] = computeDescriptiveStats(app)
%Compute the descriptive stats for the current analysis and update the
%descriptive stats table in GUI, Oliver Pambos, 20/07/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeDescriptiveStats
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
%%Update 07/03/2024: the active labelled dataset is now copied to the
%substruct `InsightData` through the `Source data` GUI component.
%Downstream analysis code, including this function, now operate directly
%on this dedicated substruct. This greatly simplifies and generalises the
%analysis codebase, enabling functions such as this one to operate on any
%labelled dataset defined dynamically during runtime. This also enables
%analysis of future labelling types without having to locally hardcode
%rules, and eliminates the need for state variables to keep track of the
%current analysis target.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeTotalObsTime()
%computeTotalStateTimes()
%computeTransitionRates()
%computeTotalObsTime() - local to this .m file
    
    %there's a lot of conversion to string, rounding, etc. here before displaying because
    %the table GUI element cannot handle different precisions, alignments, etc.
    
    %move data from labelled dataset to Insights substruct
    data_available = copyLabelsToInsights(app);
    if ~data_available
        return;
    end
    
    %get data
    [t_obs, N_labelled, N_filtered, pc_progress, N_prefilter,...
        pc_filtered, t_experiment]          = computeTotalObsTime(app.movie_data, 'InsightData');
    [state_times, state_proportions]        = computeTotalStateTimes(app.movie_data);
    [transition_rates, state_transitions]   = computeTransitionRates(app.movie_data);
    
    %construct table
    table_data = {'Number of molecules before filtering', strcat(num2str(floor(N_prefilter)))};
    table_data = [table_data; {'Number of filtered molecules', [num2str(N_filtered), ' (', sprintf('%.1f', pc_filtered), '% filtered)']}];
    table_data = [table_data; {'Number of molecules labelled', num2str(N_labelled)}];
    table_data = [table_data; {'Labelling progress (%)', num2str(floor(pc_progress))}];
    table_data = [table_data; {'Runtime of experiment (hh:mm:ss)', char(duration(seconds(t_experiment), 'Format', 'hh:mm:ss'))}];
    table_data = [table_data; {'Total molecule observation time (hh:mm:ss)', char(duration(seconds(t_obs), 'Format', 'hh:mm:ss'))}];
    
    %compile table entries for state transition information
    for state1 = 1:size(transition_rates,1)
        for state2 = 1:size(transition_rates,2)
            if state1 ~= state2
                entry1 = char(strcat("Transition rate from ", app.movie_data.params.class_names(state1), " to ", app.movie_data.params.class_names(state2), " (Hz)"));
                entry2 = char([num2str(transition_rates(state1,state2)), ' (', num2str(state_transitions(state1, state2)), ' events)']);
                table_data = [table_data; {entry1, entry2}];
            end
        end
    end
    
    for ii = 1:size(state_times,2)
        name    = char(strcat('Time in state', {' '}, app.movie_data.params.class_names(ii), ' (hh:mm:ss)'));
        value   = strcat(char(duration(seconds(state_times(ii)), 'Format', 'hh:mm:ss')), ' (', sprintf('%.1f', state_proportions(ii)*100), '%)');
        table_data = [table_data; {name, value}];
    end
    
    %display the statistics in the GUI
    app.DescriptivestatsTable.Data = table_data;
end


function [t_obs, N_labelled, N_filtered, pc_progress, N_prefilter, pc_filtered, t_experiment] = computeTotalObsTime(movie_data, label_type)
%Computes the total observation time of molecules that have been labelled,
%Oliver Pambos, 20/07/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeTotalObsTime
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
%Update: this now also counts the number of labelled states
%
%Input
%-----
%movie_data (struct)    main struct derived from LoColi
%label_type (char)      location of substruct containing labelled data;
%                           currently restricted to 'VisuallyLabelled' as
%                           app is primarily used for manual 1D segmentation;
%                           future versions may re-introduce previously used
%                           changepoint-labelled and ML-labelled data as a 
%                           separate substruct;
%
%Output
%------
%t_obs          (float)     total observation time for all labelled molecules, in seconds
%N_labelled     (int)       total number of labelled molecules
%N_filtered     (int)       total number of filtered molecules
%pc_progress    (float)     progress through labelling (%), this value is the number of labelled molecules divided by the number filtered, note that molecules can be removed from the filtered list when discarded in the human annotation system;
%N_prefilter    (int)       total number of molecules in the original tracking data generated by the tracking algorithm prior to filtering by prepData
%pc_filtered    (float)     percentrage of tracks in original tracking file that have been filtered
%t_experiment   (float)     total length of experiment (original video recording), in seconds
    
    t_obs       = 0;
    N_labelled  = 0;
    N_prefilter = 0;
    N_filtered  = size(movie_data.results.InsightData.LabelledMols,1);

    switch label_type
        case 'InsightData'
            for ii = 1:size(movie_data.results.InsightData.LabelledMols,1)
                if ~strcmp(movie_data.results.InsightData.LabelledMols{ii, 1}.EventSequence, 'pending')
                    N_labelled  = N_labelled + 1;
                    t_obs       = t_obs + size(movie_data.results.InsightData.LabelledMols{ii, 1}.Mol, 1);
                end
            end
        otherwise
    end
    
    t_obs       = t_obs ./ movie_data.params.frame_rate;
    pc_progress = 100* N_labelled / N_filtered;
    
    %compute the number of tracks filtered during the analysis
    for ii = 1:size(movie_data.cellROI_data,1)
        if isempty(movie_data.cellROI_data(ii).tracks)
            continue;
        else
            N_prefilter = N_prefilter + size(unique(movie_data.cellROI_data(ii).tracks(:,4)),1);
        end
    end
    pc_filtered = 100*(N_prefilter - N_filtered)/N_prefilter;
    
    %compute the total length of the recording
    if isfield(movie_data.params, 'frames_per_file')
        t_experiment = sum(movie_data.params.frames_per_file) ./ movie_data.params.frame_rate;
    else
        t_experiment = fitsinfo(fullfile(movie_data.params.ffPath, movie_data.params.ffFile)).PrimaryData.Size(3) ./ movie_data.params.frame_rate;
    end
end


