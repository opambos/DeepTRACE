function [data_dlarray, source_track] = reformatToDLArray(cell_array, window_size, feature_cols)
%Convert the cell array used to store tracks to be annotation into a matlab
%dlarray of sliding windows of those tracks, higher perfomance in
%classification, Oliver Pambos, 21/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: reformatToDLArray
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
%Converts the cell array in which the data is stored into a more efficient
%single dlarray for faster computation. This function also splits the
%tracks into windows such that the returned dlarray contains all of the
%windows for the dataset to be annotated. Finally, it also returns the
%vector 'source_track', which is a list of indices which keeps track of
%which slides in the dlarray correspond to which track, enabling the
%annotations to be correctly reassembled inside the original cell array
%after model classification.
%
%This function was moved from classification code to a discrete external
%function to enable access during permutation importance feature analysis.
%
%
%Input
%-----
%cell_array     (cell)  Nx1 cell array containing N tracks, where each
%                           cell contains a single track to be
%                           annotated
%window_size    (int)   size of each window used to break up tracks
%feature_cols   (vec)   row vector of column IDs of features to be used for
%
%
%Output
%------
%data_dlarray   (dlarray)   CxBxT dlarray containing all of the windowed
%                               data to be classified
%source_track  (vec)       Mx1 column vector of ints which identify the
%                               original track to which each of the M windows
%                               (i.e. each slice of data_dlarray) correspond
%                               to; this enables annotations to be written back
%                               correctly to each track.
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_tracks    = length(cell_array);
    N_features  = length(feature_cols);
    
    %calc total number of windows
    total_windows = 0;
    for ii = 1:N_tracks
        curr_track = cell_array{ii, 1}.Mol;
        N_timepoints = size(curr_track, 1);
        total_windows = total_windows + (N_timepoints - window_size + 1);
    end
    
    data_array   = zeros(N_features, total_windows, window_size, 'single');  %dimensions 'CBT' format
    source_track = zeros(total_windows, 1);
    
    %fill array and source_track
    window_idx = 1;
    for ii = 1:N_tracks
        curr_track = cell_array{ii, 1}.Mol;
        N_timepoints = size(curr_track, 1);
        
        %extract relevant features
        curr_track = curr_track(:, feature_cols);
        
        for start_idx = 1:(N_timepoints - window_size + 1)
            end_idx = start_idx + window_size - 1;
            
            %extract window, and insert into array
            window_data = curr_track(start_idx:end_idx, :)';
            data_array(:, window_idx, :) = window_data;
            source_track(window_idx) = ii;
            
            window_idx = window_idx + 1;
        end
    end
    
    %convert to dlarray with (class [feature], batch, time) format
    data_dlarray = dlarray(data_array, 'CBT');
end