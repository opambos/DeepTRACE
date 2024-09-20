function [] = computeLocPoleDists(app)
%Compute distance to membrane for every frame of every tracked molecule,
%Oliver Pambos, 22/05/2021.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeLocPoleDists
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
%This was separated from computeLocMemDists() on 22/05/2024 to enable users
%to separately select feature engineering for distance to membrane, and
%distance to pole.
%
%Input
%-----
%movie_data (struct)    main data struct, inherited originally from LoColi
%
%Output
%------
%movie_data (struct)    main data struct, inherited originally from LoColi, now containing distance to membrane
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    h_progress  = waitbar(0,'Preparing....','Name','Computing distances to cell poles');
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    
    %loop over every cell
    for ii = 1:N_cells
        curr_mesh = app.movie_data.cellROI_data(ii).mesh;
        curr_tracks = app.movie_data.cellROI_data(ii).tracks;

        N_cols = size(curr_tracks, 2);
        waitbar(ii/N_cells, h_progress, sprintf('Computing distances for cell %d of %d', ii, N_cells));
        %loop over all tracked localisations
        for jj = 1:size(curr_tracks, 1)
            %compute distance to nearest pole for every localisation
            poledists = [ pdist([curr_tracks(jj,1:2); curr_mesh(1,1:2)]);...
                          pdist([curr_tracks(jj,1:2); curr_mesh(end,1:2)]) ];
            curr_tracks(jj, N_cols+1) = min(poledists) .* px_scale;
        end
        
       app.movie_data.cellROI_data(ii).tracks = curr_tracks;
    end
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Distance to pole'];
    close(h_progress);
end