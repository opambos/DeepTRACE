function [] = exportResAnDi2(app)
%Exports a copy of all data in the ResAnDi2 format, Oliver Pambos,
%28/06/2025.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: exportResAnDi2
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
%This function generates a new results struct to hold ResAnDi2 analysed
%data, and exports a copy of all tracks to the ResAnDi2 format.
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
%None
    
    %prompt user for an output path
    app.textout.Value = "Please select and output path in which to locate the ResAnDi2-formatted data. A new folder will be generated within this path containing the output tracks pre-processed by DeepTRACE.";
    resandi_path = uigetdir('', 'Select directory to save ResAnDi2-formatted data');
    if isequal(resandi_path, 0)
        disp('User canceled the operation. No output directory selected.');
        return;
    end
    
    %copy over every track to the ResAnDi struct
    count = 1;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs,1)
            %write the LoColi tracks data to the LabelledMols struct
            app.movie_data.results.ResAnDi.LabelledMols{count,1}.Mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj), :);
            
            %update the ResAnDi results substruct
            app.movie_data.results.ResAnDi.LabelledMols{count,1}.CellID             = ii;
            app.movie_data.results.ResAnDi.LabelledMols{count,1}.MolID              = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj);
            app.movie_data.results.ResAnDi.LabelledMols{count,1}.MoleculeDuration   = size(app.movie_data.results.ResAnDi.LabelledMols{count}.Mol,1) / app.movie_data.params.frame_rate;    %in seconds
            app.movie_data.results.ResAnDi.LabelledMols{count,1}.EventSequence     = 'Pending';
            
            %generate a unique ID for each track (require single number ID for use externally, and for use in pairing results back into local struct)
            app.movie_data.results.ResAnDi.LabelledMols{count,1}.external_ID        = count - 1;
            count = count + 1;
        end
    end
    
    %loop over all molecules, generating ResAnDi formatted outputs
    N_mols = numel(app.movie_data.results.ResAnDi.LabelledMols);
    all_tracks = [];
    for ii = 1:N_mols
        curr_track      = app.movie_data.results.ResAnDi.LabelledMols{ii}.Mol(:, 1:2);   %keep just (x, y)
        
        %reset all track data to origin and time zero (x = 0, y = 0, t = 0)
        curr_track = curr_track - curr_track(1, :);

        %append frame col
        curr_track(:,3) = (0:size(curr_track,1)-1)';
        
        %ensure all tracks are truncated to 200
        if size(curr_track, 1) > 200
            curr_track = curr_track(1:200, :);
        end

        %append external ID as column
        external_ID  = app.movie_data.results.ResAnDi.LabelledMols{ii}.external_ID;
        curr_track = [curr_track, ones(size(curr_track, 1), 1) .* external_ID];
        
        %append new track to matrix
        all_tracks = [all_tracks; curr_track];
    end
    
    T = table(all_tracks(:,4), all_tracks(:,3), all_tracks(:,1), all_tracks(:,2), 'VariableNames', {'traj_idx','frame','x','y'});
    
    %write CSV to ResAnDi2 folder tree
    out_path   = fullfile(resandi_path, 'exp_0');
    if ~exist(out_path,'dir')
        mkdir(out_path);
    end
    
    csv_file = fullfile(out_path, 'trajs_fov_0.csv');
    writetable(T, csv_file);
    
    app.textout.Value = "The ResAnDi2 csv-formatted data has been successfully exported as: " + csv_file;
end