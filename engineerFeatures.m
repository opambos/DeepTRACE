function [] = engineerFeatures(app)
%Perform feature engineering, Oliver Pambos, 22/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerFeatures
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
%This function enables generalisation of feature engineering to all input
%pipelines, and provides user control over the generation of engineered
%features. This function replaces the hardcoded feature engineering LoColi
%data that was previously part of the function prepData().
%
%Note that currently all features are computed without user control over
%This will be modified in a future update to enable user selection of
%engineered features, which will depend dynamically upon primary input
%features available in the input data.
%
%Note that the main data struct passed to this function contains a tracks
%substruct which always contains the columns ['x (px)', 'y (px)', 'Frame',
%'MolID'], followed by an optional block of primary features which are
%extracted from the localisation data (in the case of LoColi), or obtained
%from additional columns in the input tracking data (in the case of other
%pipelines).
%
%For performance, this code was previously executed in a single loop, with
%all changes being performed on a cell-by-cell basis. However as selective
%feature engineering was introduced, the individual functions were
%modularised into individual functions for clarity, robustness, and to
%avoid complex conditional statements.
%
%Many of the local functions that perform operations on a track-by-track
%basis uses a variable called new_col which is formed by multiple
%concatenation operations of individual tracks. This is an obvious place
%where pre-allocation and use of a running index could improve performance
%if needed.
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
%engineerCellCoords()
%engineerShiftedStepSizes()
%computeLocMemDists()
%computeLocPoleDists()
%computeStepAngles()
%compileMSDMatrixFast()
%engineerPosInNm()                      - local to this .m file
%engineerTimeStep()                     - local to this .m file
%engineerExperimentTime()               - local to this .m file
%engineerTimeFromTrackStart()           - local to this .m file
%engineerTimeFromReferencePoints()      - local to this .m file
%engineerStepSize()                     - local to this .m file
%engineerDistanceFromTrackStart()       - local to this .m file
%engineerCumulativeDistanceTravelled()  - local to this .m file
%engineerRelativeStepAngle()            - local to this .m file
%engineerStepAngleRelImage()            - local to this .m file
%engineerStepAngleRelCell()             - local to this .m file
%engineerSpotSize()                     - local to this .m file
%engineerSpotArea()                     - local to this .m file
%engineerLocalDStar()                   - local to this .m file
%engineerRollingDStarDelta()            - local to this .m file
%engineerRollingMeanStepSizeDelta()     - local to this .m file
%engineerRollingStdDevStepSizeDelta()   - local to this .m file
%engineerRollingStdDevPosnDelta()       - local to this .m file
    
    
    %==============================
    %Obligatory engineered features
    %==============================
    %compute cell coordinates for all tracked localisations in dataset
    engineerCellCoords(app);
    
    %convert localisation data to nm
    engineerPosInNm(app);
    

    %============================
    %Optional engineered features
    %============================
    %compute step sizes between localisations in all tracks
    engineerStepSize(app);

    %compute the time steps between localisations in all tracks
    engineerTimeStep(app);
    
    %compute time from start of experiment
    engineerExperimentTime(app);
    
    %compute the time from start of track for all tracked localisations
    engineerTimeFromTrackStart(app);
    
    %compute time from all reference points
    engineerTimeFromReferencePoints(app);
    
    %compute distance of current point from start of track
    engineerDistanceFromTrackStart(app);
    
    %compute cumulative distance travelled since start of track
    engineerCumulativeDistanceTravelled(app);
    
    %compute all shifted step sizes requested by user
    engineerShiftedStepSizes(app);
    
    %compute distance-to-membrane for every tracked localisation in dataset
    computeLocMemDists(app);
    
    %compute distance-to-pole for every tracked localisation in dataset
    computeLocPoleDists(app);
    
    %compute spot size
    engineerSpotSize(app);
    
    %compute spot area
    engineerSpotArea(app);
    
    %compute step angle relative to previous step for all steps in dataset
    engineerRelativeStepAngle(app);
    
    %compute step angle relative to image for all steps in dataset
    engineerStepAngleRelImage(app);
    
    %compute step angle relative to cell major axis for all steps in dataset
    engineerStepAngleRelCell(app);
    
    %compute the local diffusion coefficient around every tracked localisation
    engineerLocalDStar(app);
    
    %compute rolling window delta for local D*
    engineerRollingDStarDelta(app);

    %compute rolling window delta for mean step size
    engineerRollingMeanStepSizeDelta(app);
    
    %compute rolling window delta for standard deviation of step size
    engineerRollingStdDevStepSizeDelta(app);
    
    %compute rolling window delta for standard deviation of position
    engineerRollingStdDevPosnDelta(app);
    
    
    %============
    %Class labels
    %============
    %set class labels for all mols to -1 (could have been done outside of this list)
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        app.movie_data.cellROI_data(ii).tracks = cat(2, app.movie_data.cellROI_data(ii).tracks, (-1).*ones(size(app.movie_data.cellROI_data(ii).tracks, 1), 1));
    end
    
    %concatenate the class label
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'class label'];
end


function [] = engineerPosInNm(app)
%Feature engineering for conversion of position units to nm for all tracked
%localisations in dataset, Oliver Pambos, 24/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerPosInNm
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
%This code was moved from engineerFeatures() to modularise the code.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Converting localisation data to nm');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Converting localisation data for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %compute x and y in nm
            new_cols = app.movie_data.cellROI_data(ii).tracks(:,1:2) .* app.movie_data.params.px_scale;

            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_cols];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, {'x (nm)', 'y (nm)'}];
    close(h_progress);
end


function [] = engineerStepSize(app)
%Feature engineering for step size from the previous localisation in a
%track, Oliver Pambos, 24/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerStepSize
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing for all time steps in all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing time steps for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];

            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute time steps
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                
                %compute distances between consecutive points
                curr_steps = [0; sqrt(sum(diff(curr_track(:, 1:2)).^2, 2)) .* app.movie_data.params.px_scale];
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = [new_col; curr_steps];
            end

            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
       
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step size (nm)'];
    close(h_progress);
end


function [] = engineerTimeStep(app)
%Feature engineering for the time step from the previous localisation in a
%track, Oliver Pambos, 24/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerTimeStep
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing all time steps in all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing time steps for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];

            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute time steps
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_time_steps = [0; diff(curr_track(:, 3)) ./ app.movie_data.params.frame_rate];
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = cat(1, new_col, curr_time_steps);
            end

            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Time step interval from previous step (s)'];
    close(h_progress);
end


function [] = engineerExperimentTime(app)
%Feature engineering for the time elapsed from start of experiment, Oliver
%Pambos, 30/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerTimeFromTrackStart
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
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing elapsed time for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing elapsed time for tracks in cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %compute times and append to tracks matrix
            new_col = app.movie_data.cellROI_data(ii).tracks(:, 3) ./ app.movie_data.params.frame_rate;
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Time (s)'];
    close(h_progress);
end


function [] = engineerTimeFromTrackStart(app)
%Feature engineering for the time elapsed from start of track, Oliver
%Pambos, 30/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerTimeFromTrackStart
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing elapsed time for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing elapsed time for tracks in cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];

            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track and compute the time from start
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_intervals = (curr_track(:, 3) - curr_track(1, 3)) ./ app.movie_data.params.frame_rate;
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = cat(1, new_col, curr_intervals);
            end

            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
        
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Time from start of track (s)'];
    close(h_progress);
end


function [] = engineerTimeFromReferencePoints(app)
%Feature engineering for the time elapsed from reference point(s) provided
%by user, Oliver Pambos, 29/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerTimeFromReferencePoints
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
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    
    %get reference point(s) from user
    popup = ReferencePointPopUp(app);
    uiwait(popup.ReferencetimepointentryUIFigure);
    
    h_progress  = waitbar(0,'Preparing....','Name','Computing reference time(s) for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing reference time(s) for tracks in cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %pre-allocate
            curr_ref_times = zeros(size(app.movie_data.cellROI_data(ii).tracks, 1), size(app.movie_data.params.t_ref_points, 1));

            %get delay from each custom reference point, and concatenate columns with existing tracks matrix
            for kk = 1:size(app.movie_data.params.t_ref_points, 1)
                curr_ref_times(:,kk) = (app.movie_data.cellROI_data(ii).tracks(:, 3) ./ app.movie_data.params.frame_rate) - app.movie_data.params.t_ref_points{kk, 1};
            end
            
            %append new data
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, curr_ref_times];
        end
    end
    
    %write the new column titles
    t_ref_points = cellfun(@(x) ['Time from ' x ' (s)'], app.movie_data.params.t_ref_points(:, 2), 'UniformOutput', false);
    app.movie_data.params.column_titles.tracks  = [app.movie_data.params.column_titles.tracks, t_ref_points'];

    close(h_progress);
end


function [] = engineerDistanceFromTrackStart(app)
%Feature engineering for the distance of position from start of track,
%Oliver Pambos, 30/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerDistanceFromTrackStart
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
%This feature is particularly powerful for scenarios involving fluorogenic
%probes which encode the start of a process. For example in experiments
%involving smFISH the start of each track encodes the point at which a
%transcript is produced, and all downstream processes of motion from this
%initial target follows a pattern that is to be investigated. The allows
%for detailed analysis for insight into motion following the triggering
%event. Another example may be fluorogenic probes that bind in the
%periplasm following cytoplasmic-periplasmic transport. It could
%also be used to study the stability of binding partners.
%
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing distance travelled for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing distance travelled in cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track and compute the time from start
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_dists = sqrt(sum((curr_track(:, 1:2) - curr_track(1, 1:2)).^2, 2)) .* app.movie_data.params.px_scale;
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = cat(1, new_col, curr_dists);
            end

            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Current distance from start of track (nm)'];
    close(h_progress);
end


function [] = engineerCumulativeDistanceTravelled(app)
%Feature engineering for the cumulative distance travelled from start of
%track, Oliver Pambos, 30/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerDistanceTravelled
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
%Keeps track of how far the particle has moved since it first appeared.
%This is particularly useful for fluorogenic probes, for example studying
%the degradation rate of transcripts imaged with smFISH.
%
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing distance from start for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing distance from start of track in cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track and compute all distances between consecutive points
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_steps = [0; sqrt(sum(diff(curr_track(:, 1:2)).^2, 2)) .* app.movie_data.params.px_scale];
                
                %compute the cumulative sum for each step in track, and concatenate this for the current molecule into the new column
                new_col = cat(1, new_col, cumsum(curr_steps));
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Cumulative distance travelled from start of track (nm)'];
    close(h_progress);
end


function [] = engineerRelativeStepAngle(app)
%Feature engineering for step angles relative to previous step, Oliver
%Pambos, 24/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerRelativeStepAngle
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeStepAngles()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing step angles for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing step angles relative to previous step for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];

            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute step angles
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_angles = rad2deg(computeStepAngles(curr_track(:,1:2)));
                curr_angles = abs(curr_angles(:, 2));    %only want the magnitude of the step angle - direction is irrelevant
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = [new_col; curr_angles];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step angle relative to previous step (degrees, absolute)'];
    close(h_progress);
end


function [] = engineerStepAngleRelImage(app)
%Feature engineering for step angles relative to the image axis, Oliver
%Pambos, 24/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerStepAngleRelImage
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeStepAngles()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing step angles relative to image');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing step angles relative to image for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];

            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute step angles
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_angles = rad2deg(computeStepAngles(curr_track(:,1:2)));
                curr_angles = abs(curr_angles(:, 1));    %only want the magnitude of the step angle - direction is irrelevant
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = [new_col; curr_angles];
            end

            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step angle relative to image (degrees)'];
    close(h_progress);
end


function [] = engineerStepAngleRelCell(app)
%Feature engineering for step angles relative to the cell major axis,
%Oliver Pambos, 24/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerStepAngleRelCell
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeStepAnglesRelToCell()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing step angles relative to cell');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing step angles relative to cell for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];

            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute step angles relative to cell major axis
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_angles = computeStepAnglesRelToCell(curr_track(:,1:2), [app.movie_data.cellROI_data(ii).mesh(1,1:2); app.movie_data.cellROI_data(ii).mesh(end,1:2)]);
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = [new_col; curr_angles];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
        
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step angle relative to cell axis (degrees)'];
    close(h_progress);
end


function [] = engineerSpotSize(app)
%Feature engineering for spot size of all tracked localisations, Oliver
%Pambos, 31/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerSpotSize
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
%Computes double the square root of the sum of the squares of the standard
%deviation in the major an minor axes of the Gaussian fitting process
%during localisation.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %find the required columns
    col_std_major = findColumnIdx(app.movie_data.params.column_titles.tracks, "Standard deviation major axis");
    col_std_minor = findColumnIdx(app.movie_data.params.column_titles.tracks, "Standard deviation minor axis");
    if col_std_minor == 0 || col_std_major == 0
        warndlg("Warning: Unable to find suitable columns in tracks file for standard deviation of localisations. Feature engineering for spot size has been skipped.", 'Warning: unable to engineer feature', 'modal');
        return;
    end
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing spot size for all tracked localisations');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing spot sizes in cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %compute spot sizes and append to tracks matrix
            new_col = 2 .* (sqrt((app.movie_data.cellROI_data(ii).tracks(:, col_std_major) .* app.movie_data.params.px_scale).^2 + (app.movie_data.cellROI_data(ii).tracks(:, col_std_minor) .* app.movie_data.params.px_scale).^2));
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Spot size (nm)'];
    close(h_progress);
end


function [] = engineerSpotArea(app)
%Feature engineering for spot area of all tracked localisations, Oliver
%Pambos, 31/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerSpotArea
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
%Computes the spot area using the formula A = pi * a * b, where a and be
%are the standard deviation in the major an minor axes of the Gaussian
%fitting process during localisation.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    col_std_major = findColumnIdx(app.movie_data.params.column_titles.tracks, "Standard deviation major axis");
    col_std_minor = findColumnIdx(app.movie_data.params.column_titles.tracks, "Standard deviation minor axis");
    
    if col_std_minor == 0 || col_std_major == 0
        warndlg("Warning: Unable to find suitable columns in tracks file for standard deviation of localisations. Feature engineering for spot area has been skipped.", 'Warning: unable to engineer feature', 'modal');
        return;
    end
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    h_progress  = waitbar(0,'Preparing....','Name','Computing spot size for all tracked localisations');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing spot sizes in cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %compute spot sizes and append to tracks matrix
            new_col = pi .* (app.movie_data.cellROI_data(ii).tracks(:, col_std_major) .* app.movie_data.params.px_scale) .* (app.movie_data.cellROI_data(ii).tracks(:, col_std_minor) .* app.movie_data.params.px_scale);
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Spot area (nm^2)'];
    close(h_progress);
end




function [] = engineerLocalDStar(app)
%Feature engineering for local apparent diffusion coefficient for all
%tracked localisations, Oliver Pambos, 17/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerLocalDStar
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
%This algorithm computes D* from an MSD using all available points within
%the a user-defined range of frames either side of the reference point.
%
%In not requiring a full set of points in the MSD curve, this approach
%enables the system to trade accuracy at the start and end points of the
%track in order to obtain values even towards the ends of the track.
%
%The feature name in column titles has intentionally not included the
%window size enabling the user to choose the region over which the MSD is
%computed independently between different experiments; combining the
%results.
%
%A future version of this code may introduce weighting of the fitting
%process to increase the relative impact of smaller time shifts, as the
%goal here is changepoint detection/segmentation. Another future change may
%be to introduce imputation of NaN values, which would be replaced by the
%next nearest known value, or an average of the nearest known value before
%and after.
%
%Note that this replaces an earlier prototype version which obtained local
%diffusion coefficient using only step sizes between the reference point
%and all available other points in the frame window, but not allowing the
%pairwise contributions from non-reference points. The initial idea was to
%consider only the distance of the reference point to all other points in
%the small window. However this new version considers temporally-proximal
%pairwise steps to contain more useful information, particularly when exact
%changepoint detection is not the main goal, as is the case for separating
%bound particles from very slowly moving but mobile whose step sizes are
%smaller than the localisation precision. I may later re-introduce my
%earlier, deprecated code as an option here.
%
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%compileMSDMatrixFast()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    app.movie_data.state.local_dstar_win_size = 0;

    %obtain window size from user
    popup = SelectLocalDiffusionParamsPopUp(app);
    uiwait(popup.SelectLocalDiffusionParamsFigure);
    window_size = app.movie_data.state.local_dstar_win_size;
    
    h_progress = waitbar(0, 'Preparing...', 'Name', 'Computing local D* for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local D* for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                curr_Dstar  = zeros(size(curr_track, 1), 1);
                
                for kk = 1:size(curr_track, 1)
                    %obtain local window of track
                    lim_lo = curr_track(kk, 3) - window_size;
                    lim_hi = curr_track(kk, 3) + window_size;

                    curr_window         = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    curr_window(:, 1:2) = curr_window(:, 1:2) .* (app.movie_data.params.px_scale / 1000);
                    
                    %compute the MSD matrix
                    msd_result = compileMSDMatrixFast(curr_window, 1/app.movie_data.params.frame_rate, window_size);
                    
                    %calculate D* = MSD / 4t; also adding a point at (0, 0)
                    p = polyfit([0; msd_result(:, 3)], [0; msd_result(:, 4)], 1);
                    curr_Dstar(kk, 1) = p(1) / 4;
                end
                new_col = [new_col; curr_Dstar];
            end
            
            %a future version may impute NaNs here by taking the mean of nearest known values
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Local D* (um^2/s)'];
    close(h_progress);
end


function [] = engineerRollingDStarDelta(app)
%Feature engineering for the rolling difference of window pairs of local
%D* values, Oliver Pambos, 19/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerRollingDStarDelta
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
%This function computes the difference between D* from MSDs in two small
%adjacent windows around each localisation in all tracks of the dataset.
%The D* value is D* = MSD/4t, with no correction applied for localisation
%error. Note that the fit is performed by a linear fit to the MSD-lag time
%data including and additonal point at the origin, (t, MSD) = (0, 0).
%
%In cases where there is insufficient data due to the at least one window
%not having enough points to form an MSD-lag time plot, the corresponding
%entry in the outputs, Dstar_ratio, and Dstar_delta, are set to zero.
%If there is a scenario in which one window contains only a single lag
%time, such as at the start or end of a track, then the D* value is
%calculated as described above, but using trigonometry as this produces the
%same output with higher performance than a call to polyfit.
%
%Note that the overall design of this function is not optimal; it would
%have been better to have processed the left and right windows separately,
%both within a conditional statement for a minimum window size. This would
%produce the same funcitonal output, but with higher performance. This
%implementation would however require careful thought of how all possible
%combinations of missing values from the memory parameter might affect the
%available lag times.
%
%Missing values are set as zero; in a future version I may update this to
%impute sensible values from neibouring data.
%
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%compileMSDMatrixFast()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    app.movie_data.state.local_dstar_win_size = 0;

    %obtain window size from user
    popup = SelectLocalDiffusionParamsPopUp(app);
    uiwait(popup.SelectLocalDiffusionParamsFigure);
    window_size = app.movie_data.state.local_dstar_win_size;
    
    h_progress = waitbar(0, 'Preparing...', 'Name', 'Computing local D* for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing rolling D* for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_Dstar_ratio = [];
            cell_Dstar_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                Dstar_ratio = zeros(size(curr_track, 1), 1);
                Dstar_delta = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first and last point
                for kk = 3:size(curr_track, 1) - 2
                    %obtain frame number limits for the window pair
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3) - 1];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size - 1];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);

                    %scale the position data to nm
                    win_left(:, 1:2)  = win_left(:, 1:2) .* (app.movie_data.params.px_scale / 1000);
                    win_right(:, 1:2) = win_right(:, 1:2) .* (app.movie_data.params.px_scale / 1000);
                    
                    %compute the MSD matrices
                    msd_left  = compileMSDMatrixFast(win_left, 1/app.movie_data.params.frame_rate, window_size);
                    msd_right = compileMSDMatrixFast(win_right, 1/app.movie_data.params.frame_rate, window_size);
                    
                    %remove empty MSD entries
                    msd_left  = msd_left(msd_left(:,1) ~= 0, :);
                    msd_right = msd_right(msd_right(:,1) ~= 0, :);
                    
                    if size(msd_left, 1) > 0 && size(msd_right, 1) > 0
                        %calculate for both windows D* = MSD / 4t; also adding a point at (0, 0)
                        if size(msd_left, 1) == 1
                            fit_left = [msd_left(1,4)/msd_left(1,3), 0];
                        elseif size(msd_left, 1) == 0
                            fit_left = [0, 0];
                        else
                            fit_left  = polyfit([0; msd_left(:, 3)], [0; msd_left(:, 4)], 1);
                        end
    
                        if size(msd_right, 1) == 1
                            fit_right = [msd_right(1,4)/msd_right(1,3), 0];
                        elseif size(msd_right, 1) == 0
                            fit_right = [0, 0];
                        else
                            fit_right = polyfit([0; msd_right(:, 3)], [0; msd_right(:, 4)], 1);
                        end
                        
                        Dstar_left  = fit_left(1) / 4;
                        Dstar_right = fit_right(1) / 4;
                        
                        %compute ration and difference between windows
                        Dstar_ratio(kk) = Dstar_right / Dstar_left;
                        Dstar_delta(kk) = Dstar_right - Dstar_left;
                    else
                        %rolling D* comparisons set to zero if insufficient data
                        Dstar_ratio(kk) = 0;
                        Dstar_delta(kk) = 0;
                    end
                end

                %append ratio and delta for current track to others in same cell
                cell_Dstar_ratio = [cell_Dstar_ratio; Dstar_ratio];
                cell_Dstar_delta = [cell_Dstar_delta; Dstar_delta];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_Dstar_ratio, cell_Dstar_delta];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling D* ratio', 'Rolling D* delta (um^2/s)'];
    close(h_progress);
end


function [] = engineerRollingMeanStepSizeDelta(app)
%Feature engineering for the rolling difference of window pairs of local
%mean step sizes, Oliver Pambos, 19/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerRollingMeanStepSizeDelta
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
%This function computes the difference between mean step sizes in two small
%adjacent windows around each localisation in all tracks of the dataset.
%The localisation itself is included in the second (right hand) window. The
%ratio and difference are calculated as right/left and right - left
%respectively.
%
%Note that the window ranges for data used to compute step sizes are one
%frame larger than those used to compute other parameters due to step size
%being a difference between frames rather than a static property.
%
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    app.movie_data.state.local_dstar_win_size = 0;

    %obtain window size from user
    popup = SelectLocalDiffusionParamsPopUp(app);
    uiwait(popup.SelectLocalDiffusionParamsFigure);
    window_size = app.movie_data.state.local_dstar_win_size;
    
    h_progress = waitbar(0, 'Preparing...', 'Name', 'Computing rolling mean step size for all tracks');
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing rolling mean step size for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_mean_ratio = [];
            cell_mean_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                mean_ratio = zeros(size(curr_track, 1), 1);
                mean_delta = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first and last point
                for kk = 2:size(curr_track, 1) -1
                    %obtain frame number limits for the window pair - see header notes
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3)];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %if enough points exist compute mean ratio and delta
                    if size(win_left, 1) > 1 && size(win_right, 1) > 1
                        %compute the mean 2D step sizes in units of nm
                        mean_left  = mean(sqrt(sum(diff(win_left(:, 1:2)).^2, 2)) .* app.movie_data.params.px_scale);
                        mean_right = mean(sqrt(sum(diff(win_right(:, 1:2)).^2, 2)) .* app.movie_data.params.px_scale);
                        
                        %compute the ratio and delta
                        mean_ratio(kk) = mean_right / mean_left;
                        mean_delta(kk) = mean_right - mean_left;
                    else
                        %if there aren't enough points in one of the windows set ratio and delta to zero; this may be later replaced with interpolation/imputation
                        mean_ratio(kk) = 0;
                        mean_delta(kk) = 0;
                    end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_mean_ratio     = [cell_mean_ratio; mean_ratio];
                cell_mean_delta     = [cell_mean_delta; mean_delta];
            end
            
            %compute the absolute mean delta (inidicates singificance of changepoint)
            cell_mean_delta_abs = abs(cell_mean_delta);
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_mean_ratio, cell_mean_delta, cell_mean_delta_abs];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling mean step size ratio', 'Rolling mean step size delta (nm)', 'Rolling mean step size delta absolute'];
    close(h_progress);
end


function [] = engineerRollingStdDevStepSizeDelta(app)
%Feature engineering for the rolling difference of window pairs of local
%standard deviation in step sizes, Oliver Pambos, 20/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerRollingStdDevStepSizeDelta
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
%This function computes the difference between mean step sizes in two small
%adjacent windows around each localisation in all tracks of the dataset.
%The reference localisation itself is used in both windows. The ratio and
%difference are calculated as right/left and right - left respectively.
%
%Note that the window ranges for data used to compute step sizes are one
%frame larger than those used to compute other parameters due to step size
%being a difference between frames rather than a static property.
%
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    app.movie_data.state.local_dstar_win_size = 0;
    
    %obtain window size from user
    popup = SelectLocalDiffusionParamsPopUp(app);
    uiwait(popup.SelectLocalDiffusionParamsFigure);
    window_size = app.movie_data.state.local_dstar_win_size;
    
    h_progress = waitbar(0, 'Preparing...', 'Name', 'Computing rolling stdev step size');
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing rolling stdev step size for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_std_ratio = [];
            cell_std_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                std_ratio = zeros(size(curr_track, 1), 1);
                std_delta = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first two and last two points
                for kk = 3:size(curr_track, 1) - 2
                    %obtain frame number limits for the window pair - see header notes
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3)];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %if enough points exist compute stdev ratio and delta
                    if size(win_left, 1) > 2 && size(win_right, 1) > 2
                        %scale the position data to nm
                        win_left(:, 1:2)  = win_left(:, 1:2) .* app.movie_data.params.px_scale;
                        win_right(:, 1:2) = win_right(:, 1:2) .* app.movie_data.params.px_scale;
                        
                        %compute the mean 2D step sizes
                        std_left  = std(sqrt(sum(diff(win_left(:, 1:2)).^2, 2)));
                        std_right = std(sqrt(sum(diff(win_right(:, 1:2)).^2, 2)));
                        
                        %compute the ratio and delta
                        std_ratio(kk) = std_right / std_left;
                        std_delta(kk) = std_right - std_left;
                    else
                        %if there aren't enough points in one of the windows set ratio and delta to zero; this may be later replaced with interpolation/imputation
                        std_ratio(kk) = 0;
                        std_delta(kk) = 0;
                    end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_std_ratio = [cell_std_ratio; std_ratio];
                cell_std_delta = [cell_std_delta; std_delta];
            end
            
            %compute the absolute mean ratio (inidicates singificance of changepoint)
            cell_std_delta_abs = abs(cell_std_delta);
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_std_ratio, cell_std_delta, cell_std_delta_abs];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling stdev step size ratio', 'Rolling stdev step size delta (nm)', 'Rolling stdev step size delta absolute'];
    close(h_progress);
end


function [] = engineerRollingStdDevPosnDelta(app)
%Feature engineering for the rolling difference of window pairs of local
%standard deviation in coordinates, Oliver Pambos, 20/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: engineerRollingStdDevPosnDelta
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
%This function computes the difference between mean step sizes in two small
%adjacent windows around each localisation in all tracks of the dataset.
%The localisation itself is included in the second (right hand) window.
%The ratio and difference are calculated as right/left and right - left
%respectively.
%
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    app.movie_data.state.local_dstar_win_size = 0;
    
    %obtain window size from user
    popup = SelectLocalDiffusionParamsPopUp(app);
    uiwait(popup.SelectLocalDiffusionParamsFigure);
    window_size = app.movie_data.state.local_dstar_win_size;
    
    h_progress = waitbar(0, 'Preparing...', 'Name', 'Computing rolling stdev in position');
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing rolling stdev position for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_std_ratio = [];
            cell_std_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                std_ratio = zeros(size(curr_track, 1), 1);
                std_delta = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first and last two points
                for kk = 3:size(curr_track, 1) - 1
                    %obtain frame number limits for the window pair
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3) - 1];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size - 1];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %if enough points exist compute mean ratio and delta
                    if size(win_left, 1) > 1 && size(win_right, 1) > 1
                        %scale the position data to nm
                        win_left(:, 1:2)  = win_left(:, 1:2) .* app.movie_data.params.px_scale;
                        win_right(:, 1:2) = win_right(:, 1:2) .* app.movie_data.params.px_scale;
                        
                        %compute standard deviation in pos'n
                        std_left  = mean(std(win_left(:, 1:2)));
                        std_right = mean(std(win_right(:, 1:2)));
                        
                        %compute the ratio and delta
                        std_ratio(kk) = std_right / std_left;
                        std_delta(kk) = std_right - std_left;
                    else
                        %if there aren't enough points in one of the windows set ratio and delta to zero; this may be later replaced with interpolation/imputation
                        std_ratio(kk) = 0;
                        std_delta(kk) = 0;
                    end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_std_ratio = [cell_std_ratio; std_ratio];
                cell_std_delta = [cell_std_delta; std_delta];
            end
            
            %compute the absolute mean ratio (inidicates singificance of changepoint)
            cell_std_delta_abs = abs(cell_std_delta);
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_std_ratio, cell_std_delta, cell_std_delta_abs];
        end
        
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling stdev position ratio', 'Rolling stdev position delta (nm)', 'Rolling stdev position delta absolute'];
    close(h_progress);
end