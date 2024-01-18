function [movie_data] = computeLocMemDists(movie_data)
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
%Uses the distance-to-membrane code I wrote for my SuperCell in 2018. This
%function computes the distance of each localistion to the nearest point of
%any line within the associated cell mesh by repeatedly calling
%findPiontToMeshDist(), also developed for SuperCell in 2018.   
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
%findPointToMeshDist()

    %loop over every cell
    for i = 1:size(movie_data.cellROI_data, 1)
        %loop over all tracked localisations
        for j = 1:size(movie_data.cellROI_data(i).tracks, 1)
            %compute distance to nearest membrane for every localisation
            movie_data.cellROI_data(i).tracks(j,5) = findPointToMeshDist(movie_data.cellROI_data(i).tracks(j,1), movie_data.cellROI_data(i).tracks(j,2), movie_data.cellROI_data(i).ROIVertices);
            %compute distance to nearest pole for every localisation
            poledists = [ pdist([movie_data.cellROI_data(i).tracks(j,1:2); movie_data.cellROI_data(i).mesh(1,1:2)]);...
                          pdist([movie_data.cellROI_data(i).tracks(j,1:2); movie_data.cellROI_data(i).mesh(end,1:2)]) ];
            movie_data.cellROI_data(i).tracks(j,6) = min(poledists);
        end
    end
end

