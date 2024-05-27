function [] = engineerCellCoords(app)
%Feature engineering of the cellcular coordinates for all cells, Oliver
%Pambos, 23/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeCellCoords
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
%This function obtains cellular spatial coordinates for every tracked
%localisation in the dataset through repeated calls to
%convertToCellCoords(), as part of the feature engineering process. This
%engineered feature is considered obligatory as it is necessary for
%downstream analysis such as heatmaps, projections, and visualisation of
%the flow of states.
%
%Cell mesh manipulations are performed once for each cell in this handling
%function to minimise repetition within convertToCellCoords().
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
%convertToCellCoords()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing cellular coordinates for all molecules');
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing cellular coordinates for cell %d of %d', ii, N_cells));
        
        %obtain the midline
        midline = app.movie_data.cellROI_data(ii).mesh(1, 1:2);
        midline = [midline; (app.movie_data.cellROI_data(ii).mesh(2:end-1, 1) + app.movie_data.cellROI_data(ii).mesh(2:end-1, 3))/2, (app.movie_data.cellROI_data(ii).mesh(2:end-1,2) + app.movie_data.cellROI_data(ii).mesh(2:end-1,4))/2];
        midline = [midline; app.movie_data.cellROI_data(ii).mesh(end, 1:2)];
        
        %compute its total contour length
        contour_len = 0;
        for jj = 1:size(midline, 1) - 1
            contour_len = contour_len + pdist([midline(jj,:); midline(jj+1,:)]);
        end
        
        %obtain left and right hittest regions of the cell mesh
        mesh_left = [midline(2:end-1,:); flipud(app.movie_data.cellROI_data(ii).mesh(:, 1:2))];
        mesh_right = [app.movie_data.cellROI_data(ii).mesh(:, 3:4); flipud(midline(2:end-1,:))];
        
        %pre-allocate matrix to hold all coordinate data for current track [longitude, latitude, longitude_abs, latitude_abs]
        track_coord_data = zeros(size(app.movie_data.cellROI_data(ii).tracks, 1), 4);
        
        %get cellular coordinates for entire track
        for jj = 1:size(app.movie_data.cellROI_data(ii).tracks, 1)
            [track_coord_data(jj,1), track_coord_data(jj,2), track_coord_data(jj,3), track_coord_data(jj,4), ~] = ...
                convertToCellCoords(app.movie_data.cellROI_data(ii).tracks(jj,1), app.movie_data.cellROI_data(ii).tracks(jj,2), app.movie_data.cellROI_data(ii).mesh, mesh_left, mesh_right, midline, contour_len);
        end
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, track_coord_data];
    end
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, {'Longitude', 'Latitude', 'Longitude (absolute)', 'Latitude (absolute)'}];
    close(h_progress);
end