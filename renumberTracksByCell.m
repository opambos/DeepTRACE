function [] = renumberTracksByCell(app)
%Renumber tracks by cell, Oliver Pambos, 17/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: renumberTracksByCell
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
%Most pipelines define track IDs that are unique globally across the FOV,
%and many are removed during various filtering processes resulting in track
%IDs that appear to jump by hundred or thousands of tracks. This can be
%confusing to the user. Given that [cell_ID mol_ID] are unique across the
%set of all tracks, and are consistently used throughout the app, here we
%reassign all track IDs with an ID local to each cell.
%
%Note that this function may be better called from or after filterTracks
%during data preparation; in a later version this function may move locally
%to that function, or be separated to make it accessible in both scopes.
%
%Update: this code has been moved to a discrete function to provide access
%inside the filterTracks.m scope, enabling re-numbering of tracks following
%the filtering by tracks process.
%
%Inputs
%------
%app        (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findColumnIdx()
    
    %loop over all cells
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        if ~isempty(app.movie_data.cellROI_data(ii,1).tracks)
            %identify the track_id column
            col = findColumnIdx(app.movie_data.params.column_titles.tracks, "MolID");
            
            %extract unique values and their original indices
            [~, ~, ic] = unique(app.movie_data.cellROI_data(ii,1).tracks(:, col), 'stable');
            
            %replace track IDs with their mapped consecutive integers
            app.movie_data.cellROI_data(ii,1).tracks(:, col) = ic;
        end
    end
end