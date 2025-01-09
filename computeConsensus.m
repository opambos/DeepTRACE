function [tracks_cell_array] = computeConsensus(tracks_cell_array, probabilities, source_track)
%Compute the consensus scores for each localisation from scores in multiple
%windows, Oliver Pambos, 21/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeConsensus
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
%Computes a confidence score per class for every unqiue localisation from
%class probabilities as observed from multiple observations in different
%sliding windows, and writes this back into the cell array of annotations.
%
%Note that in the current form this effectively computes confidence as the
%mean of the prediction from all windows in which each localisation
%appears. However, it may be better to instead use median here to minimise
%the influence of outliers on the final prediction, which may be leading to
%some of the flickering of classes in model-annotated data.
%
%Note: this function was moved from labelWithSlidingWindow.m to a discrete
%.m file for use in feature permutation analysis.
%
%Performance here could be slightly further improved by pre-computing track
%windows, and logical indexing to remove further overhead, but this is
%currently unnecessary as total runtime is < 250 ms for an entire live cell
%dataset.
%
%Input
%-----
%tracks_cell_array  (cell)      Nx1 cell array containing N tracks
%probabilities      (dlarray)   CxWxF dlarray of probabilties assigned to
%                                   each localisation in each window to
%                                   each class, with dimensions of,
%                                       C: number of classes
%                                       W: number of windows in dataset
%                                       F: number of features used by model
%source_track       (vec)       Wx1 column vector containing an int for
%                                   each classified window that holds the
%                                   original track index to which that
%                                   window belongs; this enables the
%                                   probabilities for each window to be
%                                   inserted re-assigned to the correct
%                                   track in the original cell array
%
%Output
%------
%tracks_cell_array  (cell)      Nx1 cell array containing N tracks, now
%                                   containing model annotations
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %convert dlarray to matrix for faster computation
    probabilities = extractdata(probabilities);
    
    N_tracks    = max(source_track);
    window_size = size(probabilities, 3);
    N_classes   = size(probabilities, 1);
    
    %cell array to store final predictions and norm probabilities
    final_predictions_cell = cell(N_tracks, 1);
    
    for ii = 1:N_tracks
        %get section of array corresponding to current track
        track_window = find(source_track == ii);
        
        %get number of timepoints in the current track
        curr_track_len = size(tracks_cell_array{ii, 1}.Mol, 1);
        
        class_counts        = zeros(curr_track_len, N_classes);
        confidence_scores   = zeros(curr_track_len, N_classes);
        
        %loop over windows in the current track
        for jj = 1:size(track_window, 1)
            window_idx = track_window(jj);
            
            %extract probs for window, and predict classes
            curr_probabilities = reshape(probabilities(:, window_idx, :), [N_classes, window_size]);
            [~, predicted_labels] = max(curr_probabilities, [], 1);
            
            %calc start and end indices for current window relative to track
            start_idx = window_idx - min(track_window) + 1;
            end_idx = start_idx + window_size - 1;
            
            %ensure indices don't exceed track length
            valid_indices = start_idx:end_idx;
            valid_indices = valid_indices(valid_indices <= curr_track_len);
            valid_timepoints = 1:length(valid_indices);
            
            %update confidence scores
            confidence_scores(valid_indices, :) = confidence_scores(valid_indices, :) + curr_probabilities(:, valid_timepoints)';
            
            %update class counts
            for tt = 1:length(valid_timepoints)
                timepoint_idx = valid_indices(tt);
                class_counts(timepoint_idx, predicted_labels(tt)) = class_counts(timepoint_idx, predicted_labels(tt)) + 1;
            end
        end
        
        window_counts = sum(class_counts, 2);
        
        %calc consensus annotation, and normalized probability for each timepoint
        final_predictions = zeros(curr_track_len, 2);
        for tt = 1:curr_track_len
            [~, consensus_label] = max(confidence_scores(tt, :));
            normalized_confidence = confidence_scores(tt, consensus_label) / sum(confidence_scores(tt, :));
            final_predictions(tt, 1) = consensus_label;
            final_predictions(tt, 2) = normalized_confidence;
        end
        
        %store the final predictions in cell array
        final_predictions_cell{ii} = final_predictions;
        tracks_cell_array{ii, 1}.Mol(:, end) = final_predictions(:, 1);
        tracks_cell_array{ii, 1}.consensus_prediction = [final_predictions, window_counts];
        tracks_cell_array{ii, 1}.confidence_scores = confidence_scores;
    end
end