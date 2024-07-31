function [] = genChangepointWeightedMask(app)
%Identifies all changepoints in the training data, and generates a mask for
%weighting the cost function using these regions, Oliver Pambos,
%30/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genChangepointWeightedMask
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
%This function generates a 1D binary mask for every track in the training
%data which is 1 in close proximity to each changepoint, and 0 elsewhere.
%This mask is subsequently used for downstream processes such as the
%changepoint-weighted loss function. The output masks are stored in,
%   app.movie_data.results.train_changepoint_masks
%
%Mask size in the current implementation is hardcoded, but this will change
%with a future update to provide user selection from the GUI during
%runtime.
%
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
%None
    
    %mask size
    N = 3;
    
    %generate the empty masks for each track
    changepoint_masks = cell(size(app.movie_data.results.train_labels, 1), 1);
    for ii = 1:size(changepoint_masks, 1)
        changepoint_masks{ii} = zeros(1, size(app.movie_data.results.train_labels{ii, 1}, 2));
    end
    
    %loop over annotated tracks
    for ii = 1:size(app.movie_data.results.train_labels, 1)
        %obtain changepoints
        changepoints = find(diff(double(app.movie_data.results.train_labels{ii, 1})) ~= 0);
        
        %generate the mask
        for jj = 1:length(changepoints)
            %ensure start idx >= 1 & end idx <= size of track
            idx_start = max(1, changepoints(jj) - N + 1);
            idx_end   = min(size(app.movie_data.results.train_labels{ii, 1}, 2), changepoints(jj) + N);
            
            %assign region around changepoint to be 1
            changepoint_masks{ii}(idx_start:idx_end) = 1;
        end
    end
    
    app.movie_data.results.train_changepoint_masks = changepoint_masks;
end