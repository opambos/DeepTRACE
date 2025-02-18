function [feature_data, class_data] = concatTracks(track_data)
%Concatenate all tracks into a single matrix, Oliver Pambos, 12/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: concatTracks
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
%This function is extremely inefficient, and needs to be reworked with
%pre-allocation.
%
%Inputs
%------
%track_data (cell)  cell array of tracks, where each cell contains a struct
%                       with a matrix named '.Mol' of dimensions Ax(B+1)
%                       where A is the number of localisations and B is the
%                       number of features; the final column containing the
%                       assigned class ID
%
%Output
%------
%feature_data       (mat)   NxM matrix of all all feature data from all
%                               tracks concatenated into a single matrix
%class_data         (vec)   Nx1 column vector of all class IDs associated
%                               with feature data in combined_features from
%                               all tracks in the dataset
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    feature_data    = [];
    class_data      = [];
    
    for ii = 1:numel(track_data)
        curr_track      = track_data{ii, 1}.Mol;
        feature_data    = [feature_data; curr_track(:, 1:end-1)];
        class_data      = [class_data; curr_track(:, end)];
    end
end