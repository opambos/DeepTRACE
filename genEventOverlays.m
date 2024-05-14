function [data_in, data_out, t] = genEventOverlays(h_axes, mols, state, frame_rate, featureID, feature_name, entry_exit, style, display_range, max_val)
%Generate event overlays for all labelled molecules, Oliver Pambos,
%25/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genEventOverlays
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
%This function compiles all of the entries into, and exits out of, a
%specific state, aligning them in a matrix according to the moment of
%transition. The result is plotted either as individual lines (with an
%overlaid mean line) or by taking the mean and standard deviation for each
%frame in each trajectory relative to the event. The data for the entries
%and exits are also returned as separate matrices together with the
%corresponding time data associated with each frame. This exported data is
%used by other external functions such as genAlignedVideo().
%
%The current implementation plots the data in an external figure window as
%there are currently limitations on subplots within UIAxes in MATLAB's App
%Designer, and this also provides more flexibility to save the figure.
%
%Input
%-----
%h_axes         (handle)    axis handle for plotting, currently unused as figure is currently set as external
%mols           (cell)      cell array of the labelled mols, some of which may not yet be labelled
%                               for example this could be the contents of app.movie_data.results.VisuallyLabelled
%                               this has been left generalised in case I later want to classify algorithmically
%state          (int)       state being studied
%width          (int)       width of the matrix to store the events
%centre         (int)       column number where the first localisation of the new event should be placed
%featureID      (int)       column number to extract from molecule data (i.e. each column represents a different feature; step size (nm), or step angle, etc.)
%feature_name   (str)       name of the feature being plotted
%entryexit      (str)       'Entry' or 'Exit', currently unused as both plots are generates a subplots of a single figure
%style          (str)       plot style, options are
%                               'lines': all trajectories in grey, with median overlayed
%display_range  (vec)       row vector of the time range to display in the plots
%                               [t_before t_after]
%max_val        (float)     maximum value to display; this sets the upper limit in y-axis in static plots and x-axis in the histogram video
%
%Output
%------
%data_in    (mat)   aligned tracks
%data_out   (mat)       
%t          (vec)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%condenseStateSequence()
%reformatMolWithGaps()  - required only by local .m function findLongestMol()
%getStateExits()
%getStateEntrances()
%plotMedianStd()        - local to this .m file
%findLongestMol()       - local to this .m file
    
    %find the longest molecule, and use this to pre-allocate the matrices
    %with the minimum possible size such that any alignment is unable to
    %cause an out-of-bounds access error
    [len_max] = findLongestMol(mols, state);
    
    [N_in, N_out] = countStateTransitions(mols, state);
    
    %pre-allocation, for more details see header of findLongestMol() f'n
    data_in  = zeros(N_in, 2*len_max + 1);
    data_out = zeros(N_out, 2*len_max + 1);
    
    %write time base information, each entry is associated with corresponding column of data_in & data_out
    %last step before transition is always set at len_max; first step after transition is always set at len_max + 1
    t = linspace((-len_max+1)*(1/frame_rate), (len_max+1)*(1/frame_rate), 2*len_max + 1);
    
    count_in = 1;
    count_out = 1;
    
    for ii = 1:size(mols,1)
        %get the current molecule data with gaps caused by memory parameter
        curr_mol = reformatMolWithGaps(mols{ii, 1}.Mol);
        
        %compute all movements out of the state of interest
        curr_events = getStateExits(curr_mol, state);
        
        %write state exits to data_out aligned at the len_max + 1
        for jj = 1:size(curr_events, 1)
            data_out(count_out, (len_max + 1 - curr_events(jj,2) + curr_events(jj,1)):(len_max + 1 + curr_events(jj,3) - curr_events(jj,2))) =...
                curr_mol(curr_events(jj,1):curr_events(jj,3),featureID)';
            count_out = count_out + 1;
        end
        
        %compute all movements into the state of interest
        curr_events = getStateEntrances(curr_mol, state);
        
        %write the entrances to data_in aligned at the len_max + 1
        for jj = 1:size(curr_events, 1)
            data_in(count_in, (len_max - curr_events(jj,2) + curr_events(jj,1)):(len_max + curr_events(jj,3) - curr_events(jj,2))) =...
                curr_mol(curr_events(jj,1):curr_events(jj,3),featureID)';
            count_in = count_in + 1;
        end
    end
    
    %currently only plots into an external figure
    fig_handle = figure('Position', [100, 100, 1200, 800]);
    
    %plot entrances and exits from state into an external figure
    switch style
        case 'Lines'
            tiles = tiledlayout(fig_handle,1,2);
            tiles.TileSpacing = 'tight'; tiles.Padding = 'none';
            
            h_axes = nexttile(tiles);
            hold(h_axes, 'on');
            box(h_axes, 'on');
            h_axes.LineWidth=2;
            h_axes.FontSize = 16;

            for ii = 1:size(data_in,1)
                %ignore all data points which have a zero
                curr_plot = [t;data_in(ii,:)];
                zero_cols = curr_plot(2,:) == 0;
                curr_plot(:,zero_cols) = [];
                plot(h_axes, curr_plot(1,:), curr_plot(2,:), 'color', [.3 .3 .3], 'linewidth', 1);
                xlabel(h_axes, 'Time relative to event (s)', 'FontSize', 18);
                ylabel(h_axes, feature_name, 'FontSize', 18);
            end
            median_std_plot = plotMedianStd(data_in, t);
            plot(h_axes, median_std_plot(1,:), median_std_plot(3,:), 'r', 'LineWidth', 3);
            title(h_axes, [num2str(size(data_in,1)), ' entries, from ', num2str(size(mols,1)), ' molecules']);
            xlim(h_axes, display_range);
            ylim(h_axes, [0 max_val]);
            %legend(h_axes, [num2str(size(data_in,1)), ' events, from ', num2str(size(mols,1)), ' molecules'], 'Location', 'northeast', 'Box', 'off');
            
            h_axes = nexttile(tiles);
            hold(h_axes, 'on');
            box(h_axes, 'on');
            h_axes.LineWidth=2;
            h_axes.FontSize = 16;

            for ii = 1:size(data_out,1)
                %ignore all data points which have a zero
                curr_plot = [t;data_out(ii,:)];
                zero_cols = curr_plot(2,:) == 0;
                curr_plot(:,zero_cols) = [];
                plot(h_axes, curr_plot(1,:), curr_plot(2,:), 'color', [.3 .3 .3], 'linewidth', 1);
                xlabel(h_axes, 'Time relative to event (s)', 'FontSize', 18);
                ylabel(h_axes, feature_name, 'FontSize', 18);
            end
            median_std_plot = plotMedianStd(data_out, t);
            plot(h_axes, median_std_plot(1,:), median_std_plot(3,:), 'r', 'LineWidth', 3);
            title(h_axes, [num2str(size(data_out,1)), ' exits, from ', num2str(size(mols,1)), ' molecules']);
            %legend(h_axes, [num2str(size(data_out,1)), ' events, from ', num2str(size(mols,1)), ' molecules'], 'Location', 'northwest', 'Box','off');
            xlim(h_axes, display_range);
            ylim(h_axes, [0 max_val]);
            
        case 'Points'
            tiles = tiledlayout(fig_handle,1,2);
            tiles.TileSpacing = 'tight'; tiles.Padding = 'none';
            
            h_axes = nexttile(tiles);
            hold(h_axes, 'on');
            box(h_axes, 'on');
            h_axes.LineWidth=2;
            h_axes.FontSize = 16;

            median_std_plot = plotMedianStd(data_in, t);
            errorbar(h_axes, median_std_plot(1,:),median_std_plot(2,:), median_std_plot(6,:), '-square', 'LineWidth', 2.5);
            xlabel('Time relative to event (s)', 'FontSize', 18);
            ylabel(feature_name, 'FontSize', 18);
            title(h_axes, [num2str(size(data_in,1)), ' entries, from ', num2str(size(mols,1)), ' molecules']);
            xlim(h_axes, display_range);
            ylim(h_axes, [0 max_val]);
            

            h_axes = nexttile(tiles);
            hold(h_axes, 'on');
            box(h_axes, 'on');
            h_axes.LineWidth=2;
            h_axes.FontSize = 16;

            median_std_plot = plotMedianStd(data_out, t);
            errorbar(h_axes, median_std_plot(1,:),median_std_plot(2,:), median_std_plot(6,:), '-square', 'LineWidth', 2.5);
            xlabel('Time relative to event (s)', 'FontSize', 18);
            ylabel(feature_name, 'FontSize', 18);
            title(h_axes, [num2str(size(data_out,1)), ' exits, from ', num2str(size(mols,1)), ' molecules']);
            xlim(h_axes, display_range);
            ylim(h_axes, [0 max_val]);

        otherwise

    end
end


function [len_max] = findLongestMol(mols, state)
%Find longest lasting molecule in the dataset to pre-allocate the data,
%Oliver Pambos, 26/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findLongestMol
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
%The output is used to pre-allocate a matrix to store aligned data which
%enables the calling function to pre-allocate the smallest dimension empty
%matrix that can store all possible alignments of molecules. In practice
%the resulting matrix is quite sparse as the maximum size is set such that
%the longest lived molecule could be aligned such that the step could occur
%in its first or last localisation, so no alignment could result in an out
%of bounds access error.
%
%Inputs
%------
%mols   (cell)  the contents of a labelled dataset substruct of results,
%                   for manually labelled molecules this is
%                   movie_data.results.VisuallyLabelled.LabelledMols
%state  (int)   index of the state being studied
%
%Outputs
%-------
%len_max    (int)   length of the longest lasting molecule, in frames (including empty frames)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    len_max = 0;
    for ii = 1:size(mols,1)
        %get length of current molecule with gaps caused by memory parameter
        %this step is critical as it ensures that the preallocated matrices
        %data_in and data_out are the correct minimum size accounting for
        %molecule blinking; a missing localisation would otherwise cause an
        %out of range error in another function
        curr_mol_len = size(reformatMolWithGaps(mols{ii, 1}.Mol),1);
        
        %only consider molecules which have been labelled fully (no -1 labels), which contain at least one entry matching the desired state, and at least one other entry
        if curr_mol_len > len_max && ~any(mols{ii, 1}.Mol(:,end) == -1) && any(mols{ii, 1}.Mol(:,end) == state) && any(mols{ii, 1}.Mol(:,end) ~= state)
            len_max = curr_mol_len;
        end
    end
end


function [N_in, N_out] = countStateTransitions(mols, state)
%Counts the number of transitions into and out of the requested state,
%Oliver Pambos, 26/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: countStateTransitions
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
%Inputs
%------
%mols   (cell)  the contents of a labelled dataset substruct of results,
%                   for manually labelled molecules this is
%                   movie_data.results.VisuallyLabelled.LabelledMols
%state  (int)   index of the state being studied
%
%Output
%------
%N_in   (int)   number of entraces into the requested state
%N_out  (int)   number of exits from the requested state
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_in = 0;
    N_out = 0;
    %loop over molecules
    for ii = 1:size(mols, 1)
        %get the current event sequence, check it has at least two states
        sequence = mols{ii, 1}.EventSequence;
        if length(sequence) >= 2
            %scan through sequence comparing pairs of digits to count entries and exits
            for jj = 1:length(sequence) - 1
                if ~strcmp(sequence,'pending')
                    if (str2double(sequence(jj)) == state && str2double(sequence(jj + 1)) ~= state)
                        N_out = N_out + 1;
                    elseif (str2double(sequence(jj)) ~= state && str2double(sequence(jj + 1)) == state)
                        N_in = N_in + 1;
                    end
                end
            end
        end
    end
end


function [median_std_plot] = plotMedianStd(data, t)
%Obtain plotting data for the median and standard deviation of a matrix of
%events, which can contain zeros, Oliver Pambos, 26/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotMedianStd
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
%data   (mat)   data to be plotted, each row is a molecule,
%                   each column is a specific localisation, the
%                   content of the data depends upon what the user
%                   passed to it, e.g. step size, step angle, etc.
%t      (float) time data associated with the data in 'data'
%
%Output
%------
%median_std_plot   (mat)   matrix for plotting median and stddev data
%                             row 1: time
%                             row 2: median
%                             row 3: standard deviation
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None

    median_std_plot = [t; zeros(2,size(data,2))];

    for ii = 1:size(data,2)
        % if there are non-zero elements in column
        if ~all(data(:,ii) == 0)
            % current column, and delete the zeros
            A = data(:,ii);
            A(A==0) = [];
            % compute median and stddev, and insert into output data
            median_std_plot(2,ii) = mean(A);
            median_std_plot(3,ii) = median(A);
            median_std_plot(4,ii) = std(A);
            median_std_plot(5,ii) = var(A);
            median_std_plot(6,ii) = std(A)/sqrt(size(A,1));
        end
    end
end






