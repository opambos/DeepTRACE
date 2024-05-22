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
%Note that currently this remains hardcoded without user control over which
%features to engineer. This will be heavily modified in a future update to
%enable user selection of engineered features, which will depend
%dynamically upon primary input features available in the input data.
%
%Note that the main data struct passed to this function contains a tracks
%substruct which always contains the columns ['x (px)', 'y (px)', 'Frame',
%'MolID'], followed by an optional block of primary features which are
%extracted from the localisation data (in the case of LoColi), or obtained
%from additional columns in the input tracking data (in the case of other
%pipelines).
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
%computeStepAngles()
%computeStepAnglesRelToCell()
%computeLocMemDists()
%computeLocPoleDists()
    
    %loop over cells, engineering features; a future update will replace this loop with conditional calls to the selected engineered features
    for ii = 1:size(app.movie_data.cellROI_data, 1)
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

                %add the new data for the current molecule to the data to be concatenated
                cat_list = cat(1, cat_list, new_cols);
            end
            %concatenate the new data for the current cell with the existing data in .tracks matrix
            app.movie_data.cellROI_data(ii).tracks = cat(2, app.movie_data.cellROI_data(ii).tracks, cat_list);
        end
    end
    
    %concatenate new column titles from feature engineering (temporarily hardcoded column headers for StormTracker-LoColi pipeline)
    engineered_col_titles = {'Time step interval from previous step (s)',...
                             'Time from start of trajectory (s)',...
                             'x (nm)',...
                             'y (nm)',...
                             'Step size (nm)',...
                             'Step angle relative to image (degrees)',...
                             'Step angle relative to previous step (degrees, absolute)',...
                             'Step angle relative to cell axis (degrees)',...
                             'Previous step size (nm)',...
                             'Second-to-last step size (nm)',...
                             'Following step size (nm)'};
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, engineered_col_titles];
    
    %compute distance-to-membrane for every tracked localisation in dataset
    computeLocMemDists(app);
    
    %compute distance-to-pole for every tracked localisation in dataset
    computeLocPoleDists(app);
    
    %set class labels for all mols to -1 (could have been done outside of this list)
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        app.movie_data.cellROI_data(ii).tracks = cat(2, app.movie_data.cellROI_data(ii).tracks, (-1).*ones(size(app.movie_data.cellROI_data(ii).tracks, 1), 1));
    end
    
    %concatenate the class label
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'class label'];
end