function [] = engineerShiftedStepSizes(app, h_progress)
%Feature engineering of time-shifted step sizes for use with ML models that
%lack temporal context, Oliver Pambos, 24/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerShiftedStepSize
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
%This function constructs a new feature by computed a time-shifted version
%of step size for all trajectories in the dataset. This enables ML models
%that do not natively handle temporal context to obtain context from steps
%prior to or after the frame being classified.
%
%This function enables the user to produce a range of time shifts by
%prompting for a temporal range over which to compute shifted steps.
%
%Note that step sizes are handled here in nm.
%
%Note that this only performs a time-delayed version of step size, and will
%possibly be updated in future versions to perform time-delayed versions of
%any requested feature(s). This is not a priority as the models which lack
%native temporal context are currently of the lowest utility.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%engineerStepSize()
    
    if isfield(app.movie_data.state, "frames_before") && isfield(app.movie_data.state, "frames_after")
        %get range of contextual frames before and after from user
        frames_before   = int32((-1) .* app.movie_data.state.frames_before);
        frames_after    = int32(app.movie_data.state.frames_after);
    else
        app.textout.Value = "Skipping feature engineering for time shift.";
        return;
    end
    
    %if the user provides no time shift in either direction, notify them, and skip remaining actions
    if frames_before == 0 && frames_after == 0
        warndlg("You have selected no relative time shift in either direction; feature engineering for time shift will not be implemented.", "Skipping time shift feature engineering", "modal");
        return;
    end

    N_cells = size(app.movie_data.cellROI_data, 1);
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing shifted step sizes for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_cols = [];

            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                
                %compute distances between consecutive points
                curr_steps = [0; sqrt(sum(diff(curr_track(:, 1:2)).^2, 2)) .* app.movie_data.params.px_scale];
                
                %pre-allocate shifted_steps matrix
                N_shifts = frames_after - frames_before - 1;
                N_rows = size(curr_steps, 1);
                shifted_steps = zeros(N_rows, N_shifts);
                
                col_idx = 0;

                %process each shift amount from frames_before to frames_after
                for shift_amount = frames_before:frames_after
                    % Skip the zero shift
                    if shift_amount == 0
                        continue;
                    end
                    
                    col_idx = col_idx + 1;
                    
                    if shift_amount < 0
                        %-ve shift: move data down
                        down_shift = -shift_amount;
                        if down_shift < N_rows
                            shifted_steps((down_shift+1):end, col_idx) = curr_steps(1:(end-down_shift));
                        end
                    else
                        %+ve shift: move data up
                        up_shift = shift_amount;
                        if up_shift < N_rows
                            shifted_steps(1:(end-up_shift), col_idx) = curr_steps((up_shift+1):end);
                        end
                    end
                end
                
                %add the new data to be concatenated to the current cell's tracks data
                new_cols = [new_cols; shifted_steps];
            end

            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_cols];
        end
    end
    
    %generate column titles to add
    frame_shifts = frames_before:frames_after;
    frame_shifts = frame_shifts(frame_shifts ~= 0);
    labels = arrayfun(@(x) sprintf('Step size (nm) at t%+d frames', x), frame_shifts, 'UniformOutput', false);
    
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, labels];
end