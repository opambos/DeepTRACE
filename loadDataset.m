function [] = loadDataset(app)
%Load new dataset, Oliver Pambos, 02/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: loadDataset
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
%This function generalises the data input formats to non-native pipelines
%beyond the StormTracker (localisation) - LoColi (tracking) pipeline for
%which DeepTRACKS was originally designed.
%
%Prompts the user to load new data, which can be in the format of either a
%composite datafile from common pipelines, or as separate segmentation or
%tracking files. This code performs the bulk of restructuring of the
%various types of input data to make it compatible with the DeepTRACKS
%pipeline.
%
%Current implementation enables input of StormTracker or TrackMate for
%localistion, and either LoColi or TrackMate for tracking. Future versions
%will expand support further to other popular pipelines.
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
%findColumnIdx()
%loadLoColiData()           - local to this .m file
%loadSeparateSegTracks()    - local to this .m file
%genStructFromSegFile()     - local to this .m file
%genROIVertices()           - local to this .m file
%removeCollinearVertices()  - local to this .m file
%loadTrackMateData()        - local to this .m file
%assignTracksToCells()      - local to this .m file
%flipTracksInY()            - local to this .m file
%expandMesh()               - local to this .m file
%renumberTracksByCell()     - local to this .m file
    
    %prompt user for source data type
    options = {'LoColi', 'Separate segmentation and tracking files'};
    [index, value] = listdlg('PromptString', 'Choose your data file handling method. (If you have a data type not listed here please contact us via the Help tab to the right.)',...
        'SelectionMode', 'single', 'ListString', options, 'ListSize', [600 100]);   %'ListSize' effectively defines the width of the dialog window
    
    %check user makes selection; otherwise exit
    if value == 0
        app.textout.Value = 'No option selected. Please try again.';
        return;
    end
    
    %clear any existing data
    app.movie_data.cellROI_data = struct();
    
    %pipeline is initially unknown
    app.movie_data.params.pipeline = "Unknown";

    %load data according to user selection
    switch options{index}
        case 'LoColi'
            app.textout.Value = 'Loading LoColi data...';
            loadLoColiData(app);

        case 'Separate segmentation and tracking files'
            app.textout.Value = 'Please select a valid segmentation file (.dat, .csv, .mat)';
            loadSeparateSegTracks(app);
    end
end


function [] = loadLoColiData(app)
%Load a LoColi file, populating the cell struct, Oliver Pambos, 02/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: loadLoColiData
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
%Loads data from the LoColi SMLM analysis pipeline native to the Gene
%Machines group at Oxford. This code was moved from the main GUI file to
%modularise the code, enabling generalisation prior to public release.
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
    
    %user provides LoColi file
    app.textout.Value = 'Please select the LoColi data file';
    [temp_file, temp_path] = uigetfile({'*.mat', 'Select a LoColi file (*.mat)'}, 'Load a LoColi data file');
    if isequal(temp_file, 0) || isequal(temp_path, 0)
        app.textout.Value = "No LoColi file was provided by user.";
        return;
    end
    
    temp_struct = load(fullfile(temp_path, temp_file));
    
    try
        %verify file is a valid LoColi output
        if ~isstruct(temp_struct) || isempty(fieldnames(temp_struct)) || ~isfield(temp_struct, "movie_data") ||...
                ~isfield(temp_struct.movie_data, "cellROI_data") || ~isfield(temp_struct.movie_data.cellROI_data, "tracks")
            
            errordlg('This is not a valid LoColi file. Please try again.', 'Invalid LoColi file');
            app.textout.Value = "This is not a valid LoColi file. Please try again.";
            return;
        else
            %if file is valid, load into app handles
            app.movie_data  = temp_struct.movie_data;
            focus(app.InVivoKineticsUIFigure);
            app.textout.Value = "Please choose a sensible name for the dataset";
            app.movie_data.params.title = inputdlg({'Please choose a sensible name for the dataset'}, 'Name this dataset', [1 80], {temp_file});
            app.movie_data.params.pipeline = "LoColi";
            app.CurrentlyloadeddatasetTextArea.Value = app.movie_data.params.title;
            
            focus(app.InVivoKineticsUIFigure);
            app.textout.Value = "A data file from the LoColi analysis pipeline has been loaded successfully. Please now proceed to data preparation via the [Prepare] tab.";
        end
    catch ME
        warning(ME.identifier, 'Error loading LoColi file: %s', ME.message);
        app.textout.Value = "An error occurred while loading the LoColi file. Please ensure the file is valid and try again.";
    end
end


function [] = loadSeparateSegTracks(app)
%Load separate segmentation and tracking files, Oliver Pambos, 02/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: loadSeparateSegTracks
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
%This function covers scenarios where the dataset was processed with
%segmentation and tracking performed with different tools. It attempts to
%create a mapping between the two. It is also the stage at which reference
%images (currently referred to as 'brightfield_image') are acquired when
%not using the LoColi pipeline.
%
%Note that this function begins with the user providing a reference image;
%this is necessary because some pipelines such as those based on imageJ
%index image coordinates from the bottom left, rather than top right, and
%so subsequent localisation and tracking data must be reflected across the
%horizontal mid-line, which can only be obtained from knowledge of the FOV
%dimensions.
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
%genStructFromSegFile()     - local to this .m file
%loadTrackMateData()        - local to this .m file
%assignTracksToCells()      - local to this .m file
%renumberTracksByCell()     - local to this .m file
    
    %user provides reference image
    app.textout.Value = "Please provide a reference image for the full field of view. Typically this is a phase contrast or brightfield image. " + ...
        "If you do not have one, please provide a single frame image from the fluorescence movie";
    [temp_file, temp_path] = uigetfile({'*.tif;*.tiff;*.fits', 'Select a reference image (*.tif, *.tiff, *.fits)'},  'Select a reference image for the field of view');
    if isequal(temp_file, 0) || isequal(temp_path, 0)
        app.textout.Value = "No reference image was provided by user.";
        return;
    end
    
    %load the image and average it
    [~, ~, ext] = fileparts(temp_file);
    if strcmpi(ext, '.fits')
        app.movie_data.brightfield_image = fitsread(fullfile(temp_path, temp_file));
    else
        app.movie_data.brightfield_image = imread(fullfile(temp_path, temp_file));
    end
    
    %average the image if it has multiple channels/timepoints
    if ndims(app.movie_data.brightfield_image) > 2
        app.movie_data.brightfield_image = mean(app.movie_data.brightfield_image, 3);
    end
    
    %user provides segmentation file
    app.textout.Value = "Please provide a file containing segmented cell boundaries.";
    [temp_file, temp_path] = uigetfile({'*.dat;*.csv;*.mat', 'Segmented cell boundaries (*.dat, *.csv, *.mat)'},  'Select a segmentation file');
    if isequal(temp_file, 0) || isequal(temp_path, 0)
        app.textout.Value = "No segmentation file was provided by user.";
        return;
    end
    
    %get file extension and read segmentation data
    [~, ~, ext] = fileparts(temp_file);
    try
        switch lower(ext)
            case '.mat'
                seg_data = load(fullfile(temp_path, temp_file));
            case {'.dat', '.csv'}
                seg_data = readtable(fullfile(temp_path, temp_file));
            otherwise
                error('Unsupported file format.');
        end
    catch ME
        warning(ME.identifier, 'Error loading segmentation file: %s', ME.message);
        errordlg("There was a problem loading the selected file. Please ensure the file is valid and try again.", "File Load Error");
        app.textout.Value = "Error: Please start again with loading the file.";
        return;
    end
    
    %keep track of segmentation type
    app.movie_data.params.seg_type = "Unknown";
    
    %check whether file is a MicrobeTracker file, Oufti file, or pixel mask
    if isstruct(seg_data) && isfield(seg_data, "cellList")
        app.movie_data.params.seg_type = "MicrobeTracker";
        N_cells = length(seg_data.cellList{1,1});
        
    elseif isstruct(seg_data) && isfield(seg_data, "meshData")
        app.movie_data.params.seg_type = "Oufti";
        
    elseif isnumeric(seg_data) && ismatrix(seg_data)
        app.movie_data.params.seg_type = "Pixel mask";
        
    else
        app.textout.Value = "The segmentation file provided is not valid. Please load data again.";
        errordlg("The segmentation file provided was not recognised, please try again.", "Invalid segmentation file");
        return;
    end
    
    %check the loaded data actually contains cells
    if N_cells == 0
        app.textout.Value = "The segmentation file was recognised as being of the type " + app.movie_data.params.seg_type +...
            ", and was loaded successfully, however it appears to contain no cells. If you believe this to be incorrect please consult the manual.";
        return;
    end
    
    %construct main data struct
    genStructFromSegFile(app, seg_data);
    
    %prompt user to input tracking data
    app.textout.Value = "Please select a valid tracks file (e.g. *.csv)";
    [temp_file, temp_path] = uigetfile({'*.tracks;*.csv;*.mat', 'Tracking data (*.tracks, *.csv, *.mat)'},  'Select a tracking file');
    if isequal(temp_file, 0) || isequal(temp_path, 0)
        app.textout.Value = "No tracking file was provided by user.";
        return;
    end
    
    %load the data
    tracks_pathname = fullfile(temp_path, temp_file);    
    
    %keep track of segmentation type
    app.movie_data.params.tracks_type = "Unknown";
    
    % << placeholder for track filetype decision code >>
    
    
    %currnetly hardcoded to TrackMate
    try
        tracks_data = loadTrackMateData(app, tracks_pathname);
    catch ME
        app.textout.Value = "There was a error loading the selected tracking file. Please check the file carefully and try again.";
        warning(ME.identifier, 'Error loading tracking data: %s', ME.message);
        errordlg('There was an error with the selected tracking file. Please check the file carefully and try again.', 'Error loading tracking file');
        return;
    end
    
    %call pop-up GUI for human correction of drift between reference image and localisations
    popup = DataImportViewerGUI(app, tracks_data);
    uiwait(popup.DataImportViewerUIFigure);
    
    %replace local tracks with drift-corrected versions
    tracks_data = app.movie_data.state.temp_tracks;
    
    %assign all tracks in in dataset into appropriate cell
    assignTracksToCells(app, tracks_data);
    
    %renumber mol_IDs such that they are local to each cell as the combination [cell_ID molID] is unique
    renumberTracksByCell(app);
    
    %append a cell_ID feature
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, ii .* ones(size(app.movie_data.cellROI_data(ii).tracks, 1), 1)];
    end
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, {'Cell ID'}];
    
    if ~isempty(app.movie_data)
        app.textout.Value = "Data was loaded successfully. Please now proceed to data preparation via the [Prepare] tab.";
    end
end


function [] = genStructFromSegFile(app, seg_data)
%Generate the main struct from the loaded segmentation file, Oliver Pambos,
%02/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genStructFromSegFile
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
%The loaded segmentation data (seg_data) is used to generate the main data
%structure on which all downstream data processing is performed.
%
%For the Oufti case it is possible to compact the code further and remove
%repetition by moving the contents of seg_data.cellList.meshData to
%seg_data.cellList, and then execute the MicrobeTracker case, but I prefer
%the clarity of this being laid out explicitly for each case.
%
%Inputs
%------
%app        (handle)    main GUI handle
%seg_data   (struct)    MicrobeTracker or Oufti seg data struct
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%genROIVertices()   - local to this .m file
    
    switch app.movie_data.params.seg_type
        case "MicrobeTracker"
            %remove any empty entries in cell array, any cells missing .mesh, or any with an empty mesh
            seg_data.cellList{1,1} = seg_data.cellList{1,1}(cellfun(@(x) isfield(x, "mesh") && ~isempty(x.mesh), seg_data.cellList{1,1}));
            N_cells = length(seg_data.cellList{1,1});
            
            %transfer the meshes, and any other relevant parameters
            for ii = 1:N_cells
                app.movie_data.cellROI_data(ii,1).mesh = seg_data.cellList{1,1}{1,ii}.mesh;

                if isfield(seg_data.cellList{1,1}{1,ii}, "length")
                    app.movie_data.cellROI_data(ii,1).length = seg_data.cellList{1,1}{1,ii}.length;
                end
                if isfield(seg_data.cellList{1,1}{1,ii}, "lengthvector")
                    app.movie_data.cellROI_data(ii,1).lengthvector = seg_data.cellList{1,1}{1,ii}.lengthvector;
                end

                app.movie_data.cellROI_data(ii,1).tracks = [];
            end
            
            %generate ROI vertices by expanding segmented meshes
            genROIVertices(app);
            
        case "Oufti"
            %remove any empty entries in cell array, or any cells missing .mesh, or any with an empty mesh
            seg_data.cellList.meshData{1,1} = seg_data.cellList.meshData{1,1}(cellfun(@(x) isfield(x, "mesh") && ~isempty(x.mesh), seg_data.cellList.meshData{1,1}));
            
            %transfer the meshes, and any other relevant parameters
            for ii = 1:N_cells
                app.movie_data.cellROI_data(ii,1).mesh = seg_data.cellList.meshData{1,1}{1,ii}.mesh;

                if isfield(seg_data.cellList.meshData{1,1}{1,ii}, "length")
                    app.movie_data.cellROI_data(ii,1).length = seg_data.cellList.meshData{1,1}{1,ii}.length;
                end
                if isfield(seg_data.cellList.meshData{1,1}{1,ii}, "lengthvector")
                    app.movie_data.cellROI_data(ii,1).lengthvector = seg_data.cellList.meshData{1,1}{1,ii}.lengthvector;
                end
            end
            
        case "Pixel mask"
            % << placeholder for future implementation of pixel mask formats >>
    end
    
end


function [] = genROIVertices(app)
%Generates ROIVertices for each cell by manipulating segmented meshes,
%Oliver Pambos, 16/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genROIVertices
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
%Note that this expands the segmented mesh by the absolute distance listed,
%not by a percentage. Scaling is performed by movement of the mesh a
%distance along the surface normal to the mesh.
%
%Inputs
%------
%app        (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%expandMesh()               - local to this .m file
%removeCollinearVertices()  - local to this .m file
    
    %size in standard units (pixels) to expand the meshes
    expansion_factor = -1.2;

    %loop over all segmented cells
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        %manipulate MicrobeTracker mesh format into 2 cols without repeats
        app.movie_data.cellROI_data(ii,1).ROIVertices = [app.movie_data.cellROI_data(ii,1).mesh(:,1:2); flipud(app.movie_data.cellROI_data(ii,1).mesh(2:end-1,3:4))];

        %expand the mesh
        app.movie_data.cellROI_data(ii,1).ROIVertices = expandMesh(app.movie_data.cellROI_data(ii,1).ROIVertices, expansion_factor);
        
        %remove collinear points (unneccessary mesh detail)
        app.movie_data.cellROI_data(ii,1).ROIVertices = removeCollinearVertices(app.movie_data.cellROI_data(ii,1).ROIVertices, 1);
        
    end
end


function [mesh] = removeCollinearVertices(mesh, threshold_angle)
%Remove colinear points from mesh, Oliver Pambos, 17/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: removeCollinearVertices
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
%Segmented cell meshes often contain multiple points in an almost perfect
%straight line (collinear). These points reduce performance of the
%algorithm during both feature engineering and assigning localisations and
%tracks to cells. These collinear regions of segmented meshes can be
%downsampled in many of these contexts, which is the role of this function.
%
%A threshold angle of about 2 degrees works well for E.coli meshes.
%
%This function is not well optimised due to new_x and new_y which grow
%inside loop; a future update could involve pre-allocation and direct
%indexing of all access from the matrix mesh. This is not a priority.
%
%
%Inputs
%------
%mesh               (mat)   Nx2 matrix of (x,y) coordinates of mesh
%                               vertices
%threshold_angle    (float) minimum angle away from 180 degrees, below
%                               which vertices are discarded
%
%Outputs
%-------
%mesh               (mat)   Nx2 mat of N vertices of the downsampled mesh
%                               with collinear points removed
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    x = mesh(:,1);
    y = mesh(:,2);
    new_x = x(1,1);
    new_y = y(1,1);

    for ii = 2:size(x,1)-1
        %calc angle
        A = [x(ii-1,1), y(ii-1,1)];
        B = [x(ii,1), y(ii,1)];
        C = [x(ii+1,1), y(ii+1,1)];
        AB = B - A;
        BC = C - B;
        cosine_angle = dot(AB, BC) / (norm(AB) * norm(BC));
        angle = acosd(cosine_angle);
        
        %only keep points whose angle is more than threshold tolerance angle away from 180
        if abs(angle) > threshold_angle
            new_x(end+1,1) = x(ii,1);
            new_y(end+1,1) = y(ii,1);
        end
    end

    %add final point
    new_x(end+1,1) = x(end,1);
    new_y(end+1,1) = y(end,1);

    mesh = [new_x, new_y];
end


function [reformatted_tracks] = loadTrackMateData(app, tracks_pathname)
%Load tracking data from a TrackMate CSV file, Oliver Pambos, 16/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: loadTrackMateData
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
%This function loads a TrackMate tracks file and performs various
%manipulations on the imported data to make it consistent with downstreap
%data preparation code originally designed for the incoming data from the
%LoColi pipeline.
%
%Inputs
%------
%app                (handle)    main GUI handle
%tracks_pathname    (str)       filepath and name of TrackMate data file to
%                                   be loaded
%
%Outputs
%-------
%reformatted_tracks (mat)       tracks formatted for consistency with
%                                   DeepTRACKS downstream pipeline
%
%Dependent functions
%-------------------
%findColumnIdx()
%flipTracksInY()    - local to this .m file
    
    %read in tracks_data
    try
        tracks_data = readtable(tracks_pathname);
    catch ME
        warning(ME.identifier, 'Error loading TrackMate data: %s', ME.message);
        errordlg('There was a problem loading the selected tracks file. Please start again with loading the file(s).', 'File Load Error');
        
        %return an empty value to indicate failure
        reformatted_tracks = [];
        return;
    end
    
    %delete any completely empty columns
    tracks_data = tracks_data(:, any(~ismissing(tracks_data)));
    
    %delete irrelevant columns by name
    rm_cols = {'LABEL', 'RADIUS', 'POSITION_T', 'VISIBILITY', 'ID'};
    tracks_data(:, ismember(tracks_data.Properties.VariableNames, rm_cols)) = [];
    
    %anonymous function to check if each cell contains valid numeric data
    isValidNumeric = @(x) isnumeric(x) && ~isempty(x) && ~isnan(x);
    
    %extract first row as cell array
    first_row = table2cell(tracks_data(1, :));
    
    %repeatedly delete the first row if it contains any invalid (e.g. non-numeric) data
    rm_rows = 0;
    while any(~cellfun(isValidNumeric, first_row))
        tracks_data(1, :) = [];
        
        %update first row and counter
        first_row = table2cell(tracks_data(1, :));
        rm_rows = rm_rows + 1;
        
        %TrackMate files are notoriously badly formatted; this return
        %condition prevents the computationally expensive process of
        %erasing all rows of any large corrupt tracking file.
        if rm_rows > 10
            app.textout.Value = "TrackMate tracks file cannot be read correctly as it contains non-numeric data, or excessive number of column header rows.";
            return;
        end
    end
    
    %delete 'POSITION_Z' if it only contains 0.0 - occurs when tracking is
    %performed in 2D; this must be performed after removing non-numeric
    if all(tracks_data.POSITION_Z == 0)
        tracks_data.POSITION_Z = [];
    end
    
    %reorder first four columns
    first_cols      = {'POSITION_X', 'POSITION_Y', 'FRAME', 'TRACK_ID'};
    remaining_cols  = setdiff(tracks_data.Properties.VariableNames, first_cols, 'stable');
    new_order       = [first_cols, remaining_cols];
    tracks_data     = tracks_data(:, new_order);
    
    %adjust header case
    formatted_headers = lower(tracks_data.Properties.VariableNames);
    formatted_headers = regexprep(formatted_headers, '(^)(\w)', '${upper($2)}');
    tracks_data.Properties.VariableNames = strtrim(formatted_headers);
    
    %separate headers to cell array, and numeric data to matrix
    app.movie_data.params.column_titles.tracks = tracks_data.Properties.VariableNames;
    reformatted_tracks = table2array(tracks_data(2:end,:));
    
    %sort rows of the numeric data by frame number
    reformatted_tracks = sortrows(reformatted_tracks, 3);
    
    %rename columns for consistency between tracking file types using a map
    replacement_map = containers.Map( ...
        {'Position_x', 'Position_y', 'Frame', 'Track_id'}, ...
        {'x (px)',     'y (px)',     'Frame', 'MolID'});
    
    %replace relevant titles with those in the map
    for ii = 1:size(app.movie_data.params.column_titles.tracks,2)
        current_title = app.movie_data.params.column_titles.tracks{ii};
        if replacement_map.isKey(current_title)
            app.movie_data.params.column_titles.tracks{ii} = replacement_map(current_title);
        end
    end
    
    %obtain pixel scale in order to display information
    app.movie_data.params.px_scale = str2double(inputdlg('Enter pixel scale in nm:','Pixel Scale',[1 50]));
    
    %convert x and y coordinates from um to pixels for downstream compatibility
    reformatted_tracks(:, 1:2) = reformatted_tracks(:, 1:2) .* 1000 ./ app.movie_data.params.px_scale;
    
    %adjust all frame numbers to start from 1 (TrackMate indexes from zero)
    reformatted_tracks(:,findColumnIdx(app.movie_data.params.column_titles.tracks, "Frame")) = reformatted_tracks(:,findColumnIdx(app.movie_data.params.column_titles.tracks, "Frame")) + 1;
    
    %flip coordinates of all y-positions vertically
    %reformatted_tracks = flipTracksInY(reformatted_tracks, size(app.movie_data.brightfield_image,1), findColumnIdx(app.movie_data.params.column_titles.tracks, "y (px)"));
    
    app.movie_data.params.tracks_type = "TrackMate";
end


function [] = assignTracksToCells(app, tracks_data)
%Assign tracks to their corresponding cell ROIs read from segmentation
%data, Oliver Pambos, 16/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: assignTracksToCells
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
%This rough preliminary first version of this function simply checks
%whether more than a fixed number of localisations of each trajectory
%falling within each exceeds a threshold (frac_in_mesh); typically set to
%~0.5. This simple first approach has a great deal of scope for performance
%improvements in terms of both speed (if it proves to be slowon large
%datasets), and in terms of accuracy (for example in context with
%overlapping ROIs when handling cell peripheral-localised data). Simple
%improvements, for example breaking out of the assignment loop, have been
%avoided as this rough algorithm will likely be replaced in future
%versions.
%
%This also requires a waitbar for large datasets.
%
%Inputs
%------
%app                (handle)    main GUI handle
%tracks_data        (mat)       tracks formatted for consistency with
%                                   DeepTRACKS downstream pipeline
%
%Outputs
%-------
%None
%
%Dependent functions
%-------------------
%None
    
    min_track_len   = 5;
    frac_in_mesh    = 0.5;
    FOV_height      = size(app.movie_data.brightfield_image, 1);
    
    %get the unique track IDs
    track_IDs   = unique(tracks_data(:,4));
    N_tracks    = size(track_IDs, 1);
    
    %generate an array of poly objects to hold all segmented cell meshes
    %this should actually be done with expanded ROIs
    arr_polys = cell(size(app.movie_data.cellROI_data, 1), 1);
    if app.movie_data.params.flipped
        for ii = 1:numel(arr_polys)
            vertices = app.movie_data.cellROI_data(ii).ROIVertices;
            arr_polys{ii, 1} = polyshape([vertices(:,1), FOV_height - vertices(:,2) + 1]);
        end
    else
        for ii = 1:size(app.movie_data.cellROI_data, 1)
            arr_polys{ii, 1} = polyshape(app.movie_data.cellROI_data(ii,1).ROIVertices);
        end        
    end
    
    update_interval = max(1, floor(N_tracks / 100));
    h_progress      = waitbar(0, 'Assigning tracks to cells...');
    %loop over tracks, and assign to ROIs where appropriate
    for ii = 1:size(track_IDs, 1)
        curr_track = tracks_data(tracks_data(:, 4) == track_IDs(ii,1), :);
        
        %eliminate track if there any two locs have the same frame number (a known issue with TrackMate outputs)
        frame_IDs = curr_track(:, 3);
        if numel(frame_IDs) ~= numel(unique(frame_IDs))
            continue;
        end
        
        curr_track_len = size(curr_track,1);
        
        if curr_track_len >= min_track_len
            for jj = 1:size(arr_polys, 1)
                %assign trajectories to current cell if the proportion of
                %localisations falling within current ROI exceeds threshold
                TFin = isinterior(arr_polys{jj,1}, curr_track(:,1:2));
                if sum(TFin) > frac_in_mesh*curr_track_len
                    app.movie_data.cellROI_data(jj,1).tracks = [app.movie_data.cellROI_data(jj,1).tracks; curr_track];
                    break;
                end
            end
        end
        
        if mod(ii, update_interval) == 0
            waitbar(ii / N_tracks, h_progress);
        end
    end
    
    close(h_progress);
end


function [tracks_data] = flipTracksInY(tracks_data, im_height, col)
%Flip the y-axis of tracks about the midline of the FOV, Oliver Pambos,
%16/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: flipTracksInY
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
%Different SMLM pipelines index the y-coorindates of images and therefore
%localisations in different directions; for instance MATLAB interprets
%image coordinates as starting from the top left, while imageJ starts from
%the bottom left.
%
%This function handles the discrepancy by flipping the y-coordinates about
%the image horizontal mid-line.
%
%Inputs
%------
%tracks_data    (mat)   tracks data formatted for pipeline
%im_height      (int)   height of the reference image that defines the
%                           size of the FOV; used to flip tracks data in Y
%col            (int)   index of the column in tracks_data which contains
%                           Y-axis position
%
%Output
%------
%tracks_data    (mat)   the flipped tracks data
%
%Dependent functions
%-------------------
%None
    
    tracks_data(:,col) = ((tracks_data(:,col) - (im_height/2)).*(-1)) + (im_height/2);
end


function [expanded_mesh] = expandMesh(mesh, expansion)
%Expand a mesh by a fixed distance, Oliver Pambos, 19/11/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: expandMesh
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
%This code was taken from my previous genetic algorithm-based analytics
%tool SuperCell written in 2020. It appears surface normals are defined
%inwards, so expansion factor must be -ve to expand mesh to ROIVertices.
%This will be reversed in a future version.
%
%Inputs
%------
%mesh       (mat)       (x,y) coordinates of mesh vertices
%expansion  (double)    distance (in same units as mesh) to expand mesh (-ve values expand, +ve values shrink)
%
%Output
%------
%mesh       (mat)       (x,y) coordinates of expanded mesh vertices (in same units as mesh input)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    expanded_mesh = zeros(size(mesh));
    
    for ii = 1:size(mesh,1)
        %zero reference point, and its two neighbours wrt point after reference point 
        if ii == 1
            new_mesh(1,1:2)     = mesh(end,1:2) - mesh(ii+1,1:2);
            new_mesh(1:2,1:2)   = mesh(ii:ii+1,1:2) - mesh(ii+1,1:2);
        elseif ii == size(mesh,1)
            new_mesh(1:2,1:2)   = mesh(ii-1:ii,1:2) - mesh(1,1:2);
            new_mesh(3,1:2)     = [0 0];
        else
            new_mesh(1:3,1:2) = mesh(ii-1:ii+1,1:2) - mesh(ii+1,1:2);
        end
        
        %find angle of normal to mesh at this point
        [alpha, ~] = cart2pol((new_mesh(1,2).*(-1)), new_mesh(1,1));
        
        %find expanded point along normal line, and convert to cartesians
        [temp(1), temp(2)] = pol2cart(alpha, expansion);
        
        %translate to original location
        expanded_mesh(ii,1:2) = temp + mesh(ii,1:2);
    end
end