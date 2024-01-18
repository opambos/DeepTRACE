function [] = prepData(app)
%Load and modify the LoColi data struct, Oliver Pambos, 16/11/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: prepData
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
%This function is currently hardcoded to our existing unpublished
%StormTracker-LoColi data analysis pipeline, and incorporates a lot of
%functionality that will be updated in future versions. At the moment this
%works well for internal use on my own system, but this code will be
%radically overhauled in the near future.
%
%Performs a number of actions,
%   1. loads the LoColi data
%   2. sets up a new parameter sub-struct
%   3. launches all of the automatic pre-processing functions that can run
%       including,
%           identifies, orders, and indexes the video files
%           generates overlays and ROIs for all cells
%           filtering of valid trajectories
%           computes all step sizes, and converts step sizes and coordinates to nm
%           computes time intervals between localisations, and from start of trajectory
%           computes distance to membrane and cell poles
%           computes step angles relative to previous steps and cell axis
%           generates two time delayed versions of the the step sizes - to be removed in a future version
%           generates the column titles
%           initialises all class labels to -1 in preparation for labelling
%           extracts all available information from meta data (e.g. frame rate)
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
%confirmVideoOrder()
%getFITSMeta()
%genAllOverlays()
%computeLocMemDists()
%convertLoColiToKinetics()
%computeStepAngles()
%computeStepAnglesRelToCell()
    
    %obtain fluorescence videos and ask user to confirm chronological order
    [app.movie_data.params.ffFile, app.movie_data.params.ffPath] = uigetfile('*.fits', 'Select raw FITS video files:','MultiSelect', 'on');
    app.movie_data.params.ffFile = confirmVideoOrder(app.movie_data.params.ffFile);
    
    %obtain frame rate from KCT value in FITS file header
    if iscell(app.movie_data.params.ffFile)
        app.movie_data.params.frame_rate = 1/str2num(getFITSMeta(string(app.movie_data.params.ffFile(1)), app.movie_data.params.ffPath, 'KCT'));
    else
        app.movie_data.params.frame_rate = 1/str2num(getFITSMeta(string(app.movie_data.params.ffFile), app.movie_data.params.ffPath, 'KCT'));
    end
    
    %build frame offset index for all FITS files
    app.movie_data.params.frame_offsets(1) = 0;
    if iscell(app.movie_data.params.ffFile)
        for ii = 2:size(app.movie_data.params.ffFile, 2)
            app.movie_data.params.frame_offsets(ii) = str2num(getFITSMeta(string(app.movie_data.params.ffFile(ii-1)), app.movie_data.params.ffPath, 'NAXIS3'));
        end
        app.movie_data.params.frame_offsets = cumsum(app.movie_data.params.frame_offsets);

        for ii = 1:size(app.movie_data.params.ffFile, 2)
            app.movie_data.params.frames_per_file(ii) = str2num(getFITSMeta(string(app.movie_data.params.ffFile(ii)), app.movie_data.params.ffPath, 'NAXIS3'));
        end
    end
    
    %filter tracks
    filterTracks(app);
    
    %register all filtered track IDs
    f = waitbar(0,'1','Name','Preparing filtered data: registering filtered tracks');
    waitbar(1/3, f, 'Registering filtered tracks');
    for ii = 1:size(app.movie_data.cellROI_data)
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
            app.movie_data.cellROI_data(ii).filtered_track_IDs = unique(app.movie_data.cellROI_data(ii).tracks(:,4));
        end
    end
    
    %generate all inverted brightfield overlays
    waitbar(2/3, f, 'Generating overlays');
    app.movie_data = genAllOverlays(app.movie_data, app.movie_data.params.ill_border, 8);
    
    %compute localisation-to-membrane distance for every localisation in dataset
    waitbar(3/3, f, 'Computing distances to membrane for all localisations. Window will close automatically.');
    app.movie_data = computeLocMemDists(app.movie_data);
    
    %add all StormTracker data to the tracks matrix
    app.movie_data = convertLoColiToKinetics(app.movie_data);
    
    %loop over cells
    for ii = 1:size(app.movie_data.cellROI_data)
        %only consider cells that have track data
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
            %store the data to be concatenated with the current tracks matrix
            cat_list = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current molecule
                curr_mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                new_cols = zeros(size(curr_mol,1), 9);     %change this to include all columns (7 - 11), then concatenate with existing 6 columns
                for kk = 1:size(curr_mol,1)
                    if kk > 1
                        %compute time intervals
                        new_cols(kk,1) = (curr_mol(kk,3) - curr_mol(kk-1,3)) ./ app.movie_data.params.frame_rate;   %time step from previous localisation
                        new_cols(kk,2) = (curr_mol(kk,3) - curr_mol(1,3)) ./ app.movie_data.params.frame_rate;      %time step from start of molecule
                        
                        %compute step sizes in nm
                        new_cols(kk,5) = (pdist(curr_mol(kk-1:kk,1:2)) / (curr_mol(kk,3) - curr_mol(kk-1,3))) .* app.movie_data.params.px_scale;
                    end
                    
                    %compute x and y in nm
                    new_cols(kk,3) = curr_mol(kk,1).*app.movie_data.params.px_scale;
                    new_cols(kk,4) = curr_mol(kk,2).*app.movie_data.params.px_scale;

                end
                
                %compute step angles relative to x axis, and relative to previous step
                new_cols(:,6:7) = rad2deg(computeStepAngles(curr_mol(:,1:2)));
                new_cols(:,7) = abs(new_cols(:,7));    %only want the magnitude of the step angle - direction is irrelevant
                
                %compute step angles relative to cell axis
                new_cols(:,8) = computeStepAnglesRelToCell(curr_mol(:,1:2), [app.movie_data.cellROI_data(ii).mesh(1,1:2); app.movie_data.cellROI_data(ii).mesh(end,1:2)]);
                
                %add step sizes for the previous step, second-to-last step, and following step
                new_cols(:,9) = [0 ; new_cols(1:end-1, 5)];
                new_cols(:,10) = [0; 0; new_cols(1:end-2, 5)];
                new_cols(:,11) = [new_cols(2:end, 5); 0];

                %set class labels for all mols to -1 (could have been done outside of this list)
                new_cols(:,12) = -1;

                %add the new data for the current molecule to the data to be concatenated
                cat_list = cat(1, cat_list, new_cols);
            end
            %concatenate the new data for the current cell with the existing data in .tracks matrix
            app.movie_data.cellROI_data(ii).tracks = cat(2, app.movie_data.cellROI_data(ii).tracks, cat_list);
        end
    end
    
    %currently hardcoded column headers for our specific StormTracker-LoColi pipeline
    app.movie_data.params.column_titles.tracks = { 'x (px)',...
                                               'y (px)',...
                                               'Frame',...
                                               'MolID',...
                                               'Distance to nearest membrane',...
                                               'Distance to pole',...
                                               'Brightness from stormtracker',...
                                               'Background',...
                                               'Peak intensity',...
                                               'Standard deviation major axis',...
                                               'Standard deviation minor axis',...
                                               'Theta (angle of elliptical Gauss fit relative to image)',...
                                               'Eccentricity of elliptical Gauss fit',...
                                               'Cell ID',...
                                               'Time step interval from previous step (s)',...
                                               'Time from start of trajectory (s)',...
                                               'x (nm)',...
                                               'y (nm)',...
                                               'Step size (nm)',...
                                               'Step angle relative to image (degrees)',...
                                               'Step angle relative to previous step (degrees, absolute)',...
                                               'Step angle relative to cell axis (degrees)',...
                                               'Previous step size (nm)',...
                                               'Second-to-last step size (nm)',...
                                               'Following step size (nm)',...
                                               'class label'};
    
    close(f);
end

