function [] = reformatToSpans(app)
%Reformats training, validation, and test datasets into segments or sliding
%window spans, Oliver Pambos, 01/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: reformatToSpans
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
%Note that this function also adds a bool to the results substruct called
%`padding`, which keeps track of whether the data has been padded with
%zeros and contains the masking feature (as the final row). When the models
%are trained on spans of trajectories (segments or sliding windows) the
%padding and masking is no longer necessary, and so it is important to keep
%track of the non-existance of both the padding and the masking feature,
%which will not be present in the model's training. This variable is
%deliberately keps in the results substruct to be local to the training
%data.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%reformatDataset()   - local to this .m file

%create_sliding_windows processes the trajectories with a sliding window.
    
    span_len    = app.SpanlengthSpinner.Value;
    
    %good practice: overlap assigned inside the switch statement
    overlap = true;
    
    switch app.SpantypeDropDown.Value
        case "Whole trajectories"
            return;
        case "Segments"
            overlap = false;
        case "Sliding window"
            overlap = true;
        otherwise
            
    end
    
    %reformat training data
    original_data   = app.movie_data.results.train_data;
    original_labels = app.movie_data.results.train_labels;
    
    [windowed_data, windowed_labels] = reformatDataset(original_data, original_labels, span_len, overlap);
    
    app.movie_data.results.train_data   = windowed_data;
    app.movie_data.results.train_labels = windowed_labels;
    
    %reformat validation data
    if isfield(app.movie_data.results, "val_data") && isfield(app.movie_data.results, "val_labels")
        original_data   = app.movie_data.results.val_data;
        original_labels = app.movie_data.results.val_labels;

        [windowed_data, windowed_labels] = reformatDataset(original_data, original_labels, span_len, overlap);
        
        app.movie_data.results.val_data     = windowed_data;
        app.movie_data.results.val_labels   = windowed_labels;
    end
    
    %reformat test data
    if isfield(app.movie_data.results, "test_data") && isfield(app.movie_data.results, "test_labels")
        original_data   = app.movie_data.results.test_data;
        original_labels = app.movie_data.results.test_labels;
        
        [windowed_data, windowed_labels] = reformatDataset(original_data, original_labels, span_len, overlap);
        
        app.movie_data.results.test_data    = windowed_data;
        app.movie_data.results.test_labels  = windowed_labels;
    end
    
end


function [windowed_data, windowed_labels] = reformatDataset(original_data, original_labels, span_len, overlap)
%Reformat an individual dataset, Oliver Pambos, 01/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: reformatDataset
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
%Note that this function also removes the padding zeros, and then removes
%the padding feature in each trajectory.
%
%This function currently operates by increasing the size of reformated cell
%array dynamically inside the loop. It would be better practice to
%pre-allocate this cell array, however this is not currently necessary as
%the overhead for this operation with the current datasets is very small.
%
%Inputs
%------
%original_data      (cell)  original data; each entry in the cell array
%                               contains a single full trajectory, in the
%                               form of an NxM numeric matrix, where N is
%                               the number of features (final feature being
%                               the padding mask), and M is the trajectory
%                               length (including padding zeros)
%original_labels    (cell)  original labels; a cell array of the same
%                               dimensions as original data, where each
%                               cell contains a 1xM numeric row vector
%                               which holds the labels for each frame in
%                               the trajectory (including padding zeros)
%span_len           (int)   size of window/span (in frames)
%overlap            (bool)  determines if the trajectory is broken up into
%                               non-overlapping chunks, or whether to use
%                               the sliding window, moving with single
%                               frame increments
%
%Output
%------
%windowed_data      (cell)  the original data now reformatted into smaller
%                               windows (either discrete or overlapping)
%windowed_labels    (cell)  the labels corresponding to windowed_data
%                               reformatted into smaller windows
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %initializing the new cell arrays for windowed data and labels
    windowed_data = {};
    windowed_labels = {};
    
    %loop over trajectories
    for ii = 1:length(original_data)
        %copy the trajectory, remove padding columns, then remove masking feature
        trajectory = original_data{ii};
        trajectory(:, trajectory(end, :) == 0) = [];
        trajectory(end, :) = [];
        
        labels = original_labels{ii};
        labels = removecats(labels, '0');   %critical; removes the now non-existent '0' class which would otherwise confuse use of the ML model
        
        %set initial window
        start_idx   = 1;
        end_idx     = start_idx + span_len - 1;
        
        %loop over trajectory with the window
        while end_idx <= size(trajectory, 2)
            %add windowed data and labels to the new cell arrays
            windowed_data{end+1, 1}     = trajectory(:, start_idx:end_idx);
            windowed_labels{end+1, 1}   = labels(start_idx:end_idx);
            
            %update indices for next window
            if overlap
                start_idx = start_idx + 1;
            else
                start_idx = start_idx + span_len;
            end
            end_idx = start_idx + span_len - 1;
        end
    end

end

