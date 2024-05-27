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
%engineerStepSize()             - local to this .m file
%engineerPosInNm()              - local to this .m file
%engineerTimeStep()             - local to this .m file
%engineerTimeFromTrackStart()   - local to this .m file
%engineerRelativeStepAngle()    - local to this .m file
%engineerStepAngleRelImage()    - local to this .m file
%engineerStepAngleRelCell()     - local to this .m file
    
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
    %compute the time steps between localisations in all tracks
    engineerTimeStep(app);

    %compute the time from start of track for all tracked localisations
    engineerTimeFromTrackStart(app)

    %compute step sizes between localisations in all tracks
    engineerStepSize(app);

    %compute all shifted step sizes requested by user
    engineerShiftedStepSizes(app);

    %compute distance-to-membrane for every tracked localisation in dataset
    computeLocMemDists(app);

    %compute distance-to-pole for every tracked localisation in dataset
    computeLocPoleDists(app);
    
    %compute step angle relative to previous step for all steps in dataset
    engineerRelativeStepAngle(app);
    
    %compute step angle relative to image for all steps in dataset
    engineerStepAngleRelImage(app);
    
    %compute step angle relative to cell major axis for all steps in dataset
    engineerStepAngleRelCell(app);
    
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
        
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
            %compute x and y in nm
            new_cols = app.movie_data.cellROI_data(ii).tracks(:,1:2) .* app.movie_data.params.px_scale;
        end

        %append to tracks matrix
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_cols];
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, {'x (nm)', 'y (nm)'}];
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
        
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
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
        end
        
        %append to tracks matrix
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Time step interval from previous step (s)'];
    close(h_progress);
end


function [] = engineerTimeFromTrackStart(app)
%Feature engineering for the time elapsed from start of track, Oliver
%Pambos, 24/05/2024.
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
        
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
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
        end
        
        %append to tracks matrix
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Time from start of trajectory (s)'];
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
        
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
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
        end
        
        %append to tracks matrix
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
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
        
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
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
        end
        
        %append to tracks matrix
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
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
        
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
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
        end
        
        %append to tracks matrix
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step angle relative to cell axis (degrees)'];
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
    h_progress  = waitbar(0,'Preparing....','Name','Computing all time steps in all tracks');
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing time steps for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
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
        end
        
        %append to tracks matrix
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step size (nm)'];
    close(h_progress);
end