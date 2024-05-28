function [] = computeLocMemDists(app)
%Compute distance to membrane for every frame of every tracked molecule,
%Oliver Pambos, 19/12/2021.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeLocMemDists
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
%Uses distance-to-membrane code I wrote for a previous project in 2018.
%This function computes the distance of each localistion to the nearest
%point of any line within the associated cell mesh by repeatedly calling
%findPiontToMeshDist(), also developed for the same project in 2018.
%
%Note that the mesh used here is reformattted from a microbeTracker mesh to
%an Nx2 matrix of (x,y) coordinates which links back to its start point.
%Manipulation of this mesh is performed prior to passing to call to
%findPointToMeshDist() such that this matrix manipulation occurs only once
%for each cell/mesh in order to minimise computational overhead.
%
%Input
%-----
%movie_data (struct)    main data struct, inherited originally from LoColi
%
%Output
%------
%movie_data (struct)    main data struct, inherited originally from LoColi,
%                           now containing distance to membrane (in nm)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findPointToMeshDist()
    
    h_progress  = waitbar(0,'Preparing....','Name','Computing distances to membrane');
    N_cells     = size(app.movie_data.cellROI_data, 1);
    
    %loop over every cell
    for ii = 1:N_cells
        N_cols = size(app.movie_data.cellROI_data(ii).tracks, 2);

        %reformat mesh into Nx2 format looping back to first vertex
        mesh = [app.movie_data.cellROI_data(ii).mesh(:,1:2); flipud(app.movie_data.cellROI_data(ii).mesh(1:end-1,3:4))];

        waitbar(ii/N_cells, h_progress, sprintf('Computing distances for cell %d of %d', ii, N_cells));
        %loop over all tracked localisations
        for jj = 1:size(app.movie_data.cellROI_data(ii).tracks, 1)
            %compute distance to nearest membrane for every localisation in nm
            app.movie_data.cellROI_data(ii).tracks(jj, N_cols+1) = findPointToMeshDist(app.movie_data.cellROI_data(ii).tracks(jj,1), app.movie_data.cellROI_data(ii).tracks(jj,2), mesh) .* app.movie_data.params.px_scale;
        end
        
    end
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Distance to nearest membrane (nm)'];
    close(h_progress);
end