function [] = extractAllStates(app)
%Extract every possible state from every molecule labelled with the event
%labeller, Oliver Pambos, 29/10/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: extractAllStates
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
%This function repeatedly calls extractLabelledState() to construct a
%matrix for each state in the system which contains information of the
%nature of each event involving that state, including its duration, and how
%truncated (if at all). This data is used to compile aggregated statistics.
%
%This is currently efficient for typical SMLM datasets (10 - 20 ms / run).
%If dataset sizes expand much faster than available processing power then
%performance here could be improved by only running this for the requested
%class, as this is only ever called from the
%DisplaystatisticsButtonPushed() callback which only interrogates a single
%class a time. Note that the extracted states matrices are copied to the
%results sub-struct inside the DisplaystatisticsButtonPushed() callback for
%saving later, so if writing to file is to be used after splitting the
%events there needs to remain an option to process all states, or a
%separate subroutine that calls this individually for all states before
%export.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle containing a new cell array,
%                       app.movie_data.results.InsightData.extractedStates
%                       which contains the list of events for each state in
%                       the entire dataset, each entry in the cell array
%                       contains an Nx6 matrix with the columns,
%                           col 1: cell_ID
%                           col 2: mol_ID
%                           col 3: state_ID
%                           col 4: duration, in seconds
%                           col 5: left truncated?  (1 yes, 0 no)
%                           col 6: right truncated? (1 yes, 0 no)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%extractLabelledState()
    
    %generate a struct to store the results for each class
    for jj = 1:size(app.movie_data.params.class_names,1)
        curr_events{jj} = [];   %haven't pre-allocated
    end
    
    %loop over every labelled molecule
    for ii = 1:size(app.movie_data.results.InsightData.LabelledMols,1)
        if ~any(app.movie_data.results.InsightData.LabelledMols{ii, 1}.Mol(:,end) == -1)
            %loop over all of the possible classes in the dataset
            for jj = 1:size(app.movie_data.params.class_names,1)
                %get any events in the current trajectory that match the current class
                new_events = extractLabelledState(app.movie_data.results.InsightData.LabelledMols{ii, 1}.Mol, jj);
                if ~isempty(new_events)
                    %concatenate each event entry with the cell and mol IDs,
                    %then concatenate it with the previous entries for that
                    %class from molecules that have already been interrogated
                    cell_mol_IDs = repmat([app.movie_data.results.InsightData.LabelledMols{ii, 1}.CellID, app.movie_data.results.InsightData.LabelledMols{ii, 1}.MolID], size(new_events,1), 1);
                    new_events = cat(2, cell_mol_IDs, new_events);
                    curr_events{jj} = cat(1, curr_events{jj}, new_events);
                end
            end
        end
    end
    app.movie_data.results.InsightData.extractedStates = curr_events;
end