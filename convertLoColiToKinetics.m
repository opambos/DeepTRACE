function [movie_data] = convertLoColiToKinetics(movie_data)
%Processes LoColi struct to incorporate the StormTracker data discarded by
%LoColi into the tracks matrices, Oliver Pambos, 25/04/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: convertLoColiToKinetics
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
%Modifies the data struct to re-incorporate data from the StormTracker
%localisation data into the tracks matrix for each cell. LoColi is a
%non-public data pipeline local to the Kapanidis lab, Oxford. This software
%performs SMLM tracking of a localised data file, and discards from the
%tracks matrices useful features related to the Gaussian fitting process
%used by the localistion algorithm, however this data is retained inside 
%'.localizationData'. This function searches for that data and
%re-incorporates it into the tracks matrices.
%
%Input
%-----
%movie_data (struct)    main struct from LoColi
%
%Output
%------
%movie_data (struct)    main struct from LoColi with modifications for use in kinetics software
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%appendLocsToTracks() - local to this .m file
    
    h_convert_waitbar = waitbar(0, "Preparing to translate data from LoColi to DeepTRACE format....");
    set(h_convert_waitbar, 'WindowStyle', 'modal');
    
    N_cells = size(movie_data.cellROI_data, 1);
    single_cell = false;
    if N_cells == 1
        single_cell = true;
    end
    %loop over all cells
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_convert_waitbar, sprintf('Translating data from LoColi to DeepTRACE format for cell %d/%d', ii, N_cells));
        %check track data exists, then append the relevant data to each row in tracks file
        if ~isempty(movie_data.cellROI_data(ii).tracks)
            movie_data.cellROI_data(ii).tracks = appendLocsToTracks(movie_data.cellROI_data(ii).tracks, movie_data.cellROI_data(ii).localizationData, single_cell, h_convert_waitbar);
        end
    end
    
    close(h_convert_waitbar);
    
    %generate the standard LoColi column titles
    movie_data.params.column_titles.tracks = { 'x (px)',...
                                               'y (px)',...
                                               'Frame',...
                                               'MolID',...
                                               'Brightness from stormtracker',...
                                               'Background',...
                                               'Peak intensity',...
                                               'Standard deviation major axis',...
                                               'Standard deviation minor axis',...
                                               'Theta (angle of elliptical Gauss fit relative to image)',...
                                               'Eccentricity of elliptical Gauss fit',...
                                               'Cell ID'};
end


function [new_tracks] = appendLocsToTracks(tracks, locs, single_cell, h_convert_waitbar)
%Identifies and concatenates removed localisation data to the corresponding
%track, Oliver pambos, 25/04/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: appendLocsToTracks
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
%tracks             (mat)       individual track data
%locs               (mat)       all localisation data in the current cell
%single_cell        (bool)      holds true if there is a single cell (as
%                                   with some simulation types, allowing
%                                   finer updates
%h_convert_waitbar  (handle)    waitbar handle - used here if there is only
%                                   a single cell to provide finer updates
%
%Output
%------
%new_tracks (mat)   individual track data concatenated with missing localisation data
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %new matrix to store the appended data
    new_tracks = tracks;
    
    N_rows = size(tracks, 1);
    
    %duplicate code here is intentional: single_cell bool test outside loops ensures granular mod()
    %tests are not applied to typical datasets in which progress is displayed per-cell
    if single_cell
        waitbar(0, h_convert_waitbar, sprintf('Integrating localisation fitting data (0/%d)', N_rows));

        %loop over rows in tracks
        for ii = 1:N_rows
            %update waitbar in groups of 1,000 rows
            if mod(ii, 1000) == 0
                waitbar(ii/N_rows, h_convert_waitbar, sprintf('Integrating localisation fitting data (%d/%d)', ii, N_rows));
            end
            
            %create a logical index for the rows in locs that match the current row in tracks
            locs_rows = (locs(:, 2) == tracks(ii, 1)) & (locs(:, 3) == tracks(ii, 2)) & (locs(:, 1) == tracks(ii, 3));
            
            %append the contents of columns 4 to 10 of locs to the current row in new_tracks
            new_tracks(ii, 5:12) = locs(locs_rows, 4:11);
        end
    else
        %loop over rows in tracks
        for ii = 1:N_rows
            %create a logical index for the rows in locs that match the current row in tracks
            locs_rows = (locs(:, 2) == tracks(ii, 1)) & (locs(:, 3) == tracks(ii, 2)) & (locs(:, 1) == tracks(ii, 3));
            
            %append the contents of columns 4 to 10 of locs to the current row in new_tracks
            new_tracks(ii, 5:12) = locs(locs_rows, 4:11);
        end
    end
end