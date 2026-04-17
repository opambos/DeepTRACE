function [] = loadDataset(app, input_pipeline)
%Load and prepare a new dataset, Oliver Pambos, 02/05/2024.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%This function integrates into the main GUI existing heatmapping functions
%that previously operated on saved analysis files, as well as my earlier
%SMLM image reconstruction code developed for SuperCell and tat-transport
%projects from 2019 - 2021. This code is integrated into the GUI here prior
%to public release to enable users to better explore spatial information in
%their data.
%
%There is some performance overhead in that heatmap data is processed for
%all heatmaps including those not requested by the user. As there is no lag
%in figure generation using typical datasets on a basic desktop machine,
%this has been retained in favour of code readability by eliminating
%multiple switch statements.
%This function generalises the data input formats to non-native pipelines
%beyond the StormTracker (localisation) - LoColi (tracking) pipeline for
%which DeepTRACE was originally designed.
%
%Prompts the user to load new data, which can be in the format of either a
%composite datafile from common pipelines, or as separate segmentation or
%tracking files. This code performs the bulk of restructuring of the
%various types of input data to make it compatible with the DeepTRACE
%pipeline.
%
%Current implementation enables input of StormTracker or TrackMate for
%localistion, and either LoColi or TrackMate for tracking. Future versions
%will expand support further to other popular pipelines.
%
%Inputs
%------
%app                (handle)    main GUI handle
%tracking_pipeline  (str)       type of tracking file,
%                                   "TrackMate"
%                                   "LoColi"
%                                   "TrackPy"
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
%loadPicassoDataset()       - local to this .m file
%genStructFromSegFile()     - local to this .m file
%genROIVertices()           - local to this .m file
%removeCollinearVertices()  - local to this .m file
%loadTrackMateData()        - local to this .m file
%assignTracksToCells()      - local to this .m file
%flipTracksInY()            - local to this .m file
%expandMesh()               - local to this .m file
%renumberTracksByCell()     - local to this .m file
%DataImportViewerGUI        - external pop-up GUI
    
     data_loaded = false;

    if isprop(app, "movie_data") && isfield(app.movie_data, "params") && isfield(app.movie_data.params, "user")
        user_name = app.movie_data.params.user;
    else
        user_name = "Default user";
    end
    
    %clear any existing data
    app.movie_data.cellROI_data = struct();
    
    %pipeline is initially unknown
    app.movie_data.params.pipeline = "Unknown";
    
    %load data according to user selection
    switch input_pipeline
        case 'LoColi'
            app.textout.Value = 'Loading LoColi data...';
            loadLoColiData(app);
            
        case {'TrackMate', 'TrackPy'}
            app.textout.Value = "You have selected to load tracking data from the " + input_pipeline + " tracking pipeline. Please provide the corresponding tracking, cell segmentation, and reference images for your dataset using the pop-up.";
            app.movie_data.params.pipeline = input_pipeline;
            data_loaded = loadSeparateSegTracks(app);
            if ~data_loaded 
                app.textout.Value = 'Data was not loaded successfully. Please try again.';
                return;
            end

        case 'Picasso'
            app.textout.Value = "You have selected to load localisation data from " + input_pipeline + ". Please provide the corresponding .hdf5 localisation file, cell segmentation, and reference images for your dataset using the pop-up GUI.";
            app.movie_data.params.pipeline = input_pipeline;
            data_loaded = loadPicassoDataset(app);

        otherwise
            app.textout.Value = "The input data type " + input_pipeline + " was not recognised";
            return;
    end
    
    if isprop(app, "movie_data") && isfield(app.movie_data, "params")
        app.movie_data.params.user = user_name;
        data_loaded = true;
    end
    
    if data_loaded == false
        app.textout.Value = "Data loading cancelled by the user. Please try again.";
        return;
    end
    
    %user confirms track filtering options
    popup = PrepareDataPopUp(app);
    waitfor(popup.PrepareDataUIFigure);
    if ~isfield(app.movie_data, 'state') || ~isfield(app.movie_data.state, 'cancel') || app.movie_data.state.cancel == true     %treat closing with X as cancel
        ClearanalysisMenuSelected(app, struct());
        app.textout.Value = "Data preparation was cancelled by the user. The loaded raw data has also been cleared.";
        return;
    end
    
    %prepare into the DeepTRACE format
    prepData(app);
    
    %apply missing defaults here
    fillMissingDefaults(app);
end


function [] = loadLoColiData(app)
%Load a LoColi file, populating the cell struct, Oliver Pambos, 02/05/2024.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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
            focus(app.DeepTRACEUIFigure);
            app.textout.Value = "Please choose a sensible name for the dataset";
            app.movie_data.params.title = inputdlg({'Please choose a sensible name for the dataset'}, 'Name this dataset', [1 80], {temp_file});
            app.movie_data.params.pipeline = "LoColi";
            
            focus(app.DeepTRACEUIFigure);
            app.textout.Value = "A data file from the LoColi analysis pipeline has been loaded successfully. Please follow the instructions that will appear in the pop-up windows.";
        end
    catch ME
        warning(ME.identifier, 'Error loading LoColi file: %s', ME.message);
        app.textout.Value = "An error occurred while loading the LoColi file. Please ensure the file is valid and try again.";
    end
end


function [data_loaded] = loadSeparateSegTracks(app)
%Load separate segmentation and tracking files, Oliver Pambos, 02/05/2024.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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
%app            (handle)    main GUI handle
%
%Output
%------
%data_loaded    (bool)      flag tracking successful data loading
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%genStructFromSegFile()     - local to this .m file
%loadTrackMateData()        - local to this .m file
%assignTracksToCells()      - local to this .m file
%renumberTracksByCell()     - local to this .m file
%DataImportViewerGUI        - external pop-up GUI
    
    data_loaded = false;
    
    popup = RequestSourceFiles(app.movie_data.params.pipeline);
    uiwait(popup.SelectfilesUIFigure);
    
    %exit if user kills window
    if ~isvalid(popup)
        data_loaded = false;
        return;
    end
    
    %exit if file gathering was unsuccessful
    if ~isprop(popup, "success") || ~popup.success
        data_loaded = false;
        delete(popup);
        return;
    end
    
    %store filepaths
    ref_file                                = char(popup.reference_path);
    seg_file                                = char(popup.segmentation_path);
    tracking_data                           = popup.tracking_pathnames;
    app.movie_data.params.frame_rate        = popup.frame_rate;
    app.movie_data.params.frames_per_file   = popup.frames_per_file;
    app.movie_data.params.frame_offsets     = popup.frame_offsets;
    app.movie_data.params.ffPath            = popup.fluor_path;
    app.movie_data.params.ffFile            = popup.fluor_file;
    
    %popup no longer req'd
    delete(popup);
    
    %load the image and average it
    [~, ~, ext] = fileparts(ref_file);
    if strcmpi(ext, '.fits')
        app.movie_data.brightfield_image = fitsread(ref_file);
    else
        app.movie_data.brightfield_image = imread(ref_file);
    end
    
    %average the image if it has multiple channels/timepoints
    if ndims(app.movie_data.brightfield_image) > 2
        app.movie_data.brightfield_image = mean(app.movie_data.brightfield_image, 3);
    end
    
    %get file extension and read segmentation data
    [~, ~, ext] = fileparts(seg_file);
    try
        switch lower(ext)
            case '.mat'
                seg_data = load(seg_file);
            case {'.dat', '.csv'}
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
    
    %keep track of tracking file type
    app.movie_data.params.tracks_type = "Unknown";
    
    %load the data
    % << placeholder for inference of tracking file type >>
    
    %currently hardcoded to TrackMate
    try
        tracks_data = loadTrackMateData(app, tracking_data);
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
        data_loaded       = true;
        app.textout.Value = "Data was loaded successfully. Please now follow the data preparation instructions.";
    end
    
    [~, suggested_name, ~] = fileparts(app.movie_data.params.ffFile(1));
    suggested_name = suggested_name + " DeepTRACE analysis";
    app.textout.Value = "Please choose a sensible name for the dataset";
    app.movie_data.params.title = inputdlg({'Please choose a sensible name for the dataset'}, 'Name this dataset', [1 80], suggested_name);
end


function [] = genStructFromSegFile(app, seg_data)
%Generate the main struct from the loaded segmentation file, Oliver Pambos,
%02/05/2024.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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
%                                   DeepTRACE downstream pipeline
%
%Dependent functions
%-------------------
%findColumnIdx()
%flipTracksInY()    - local to this .m file
    
    %read in tracks_data; loop over tracks pathnames concatenating tables
    try
        if numel(tracks_pathname) > 1
            tracks_data = readtable(string(tracks_pathname(1)));
            
            %load each successive chunk, correct for frame offsets, concat
            for ii = 2:numel(tracks_pathname)
                 curr_tracks = readtable(string(tracks_pathname(ii)));
                
                %find the start of the numeric frame number data
                frame_num       = str2double(string(curr_tracks.FRAME));
                first_numeric   = find(~isnan(frame_num), 1, 'first');
                if isempty(first_numeric)
                    error("No numeric FRAME data found.");
                end
                
                %add the offsets
                frame_num(first_numeric:end) = frame_num(first_numeric:end) + app.movie_data.params.frame_offsets(ii);
                curr_tracks.FRAME = frame_num;

                %increase the track ID numbers to start at the range of numbers above those in previous file(s)
                track_IDs = str2double(string(curr_tracks.TRACK_ID));
                track_IDs(first_numeric:end) = track_IDs(first_numeric:end) + max(tracks_data.TRACK_ID) + 1;
                curr_tracks.TRACK_ID = track_IDs;
                
                %check the column titles are identical (I do not trust TrackMate's lack of native batch processing, which introduces potential risks here)
                if ~isequal(tracks_data.Properties.VariableNames, curr_tracks.Properties.VariableNames)
                    error("TrackMate tables have mismatched columns; cannot concatenate safely.");
                end

                %concat
                tracks_data = vertcat(tracks_data, curr_tracks(first_numeric:end, :));
            end
        else
            tracks_data = readtable(string(tracks_pathname));
        end
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
    
    %drop any cols that are entirely non-numeric
    isNumVar  = varfun(@isnumeric, tracks_data, 'OutputFormat','uniform');
    tracks_data = tracks_data(:, isNumVar);
    
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
    
    %reorder core data columns; position core feat at start (no core columns should be left within arb feature range without code update to engineerArbitraryFeatures())
    first_cols      = {'POSITION_X', 'POSITION_Y', 'FRAME', 'TRACK_ID', 'MAX_INTENSITY_CH1', 'TOTAL_INTENSITY_CH1'};
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
        {'Position_x', 'Position_y', 'Frame', 'Track_id', 'Total_intensity_ch1',       'Max_intensity_ch1'}, ...
        {'x (px)',     'y (px)',     'Frame', 'MolID',    'Brightness from TrackMate', 'Peak intensity'});
    
    %replace relevant titles with those in the map
    for ii = 1:size(app.movie_data.params.column_titles.tracks,2)
        current_title = app.movie_data.params.column_titles.tracks{ii};
        if replacement_map.isKey(current_title)
            app.movie_data.params.column_titles.tracks{ii} = replacement_map(current_title);
        end
    end
    
    %generate registry of arbitrary and core feature names
    titles   = app.movie_data.params.column_titles.tracks;
    core     = {'x (px)', 'y (px)', 'Frame', 'MolID', 'Cell ID', 'Peak intensity', 'Brightness from TrackMate'};       %note: Cell ID doesn't yet exist, but this is in place so that when it is appended later, this is present
    isCore   = ismember(titles, core);
    app.movie_data.params.column_titles.tracks   = titles(isCore);
    app.movie_data.params.arbitrary_features     = titles(~isCore);
    app.movie_data.params.arbitrary_feature_cols = find(~isCore);
    
    %obtain pixel scale in order to display information
    app.movie_data.params.px_scale = str2double(inputdlg('Enter pixel scale in nm:', 'Pixel Scale', [1 50]));
    
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
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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
%Performance here for larger datasets will be improved by pre-selecting
%candidate meshes using bounding boxes before running isinterior.
%
%Inputs
%------
%app                (handle)    main GUI handle
%tracks_data        (mat)       tracks formatted for consistency with
%                                   DeepTRACE downstream pipeline
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
    h_progress      = waitbar(0, "Assigning " + num2str(N_tracks) + " tracks to cells...", 'Name', "Assigning tracks to cells");
    %loop over tracks, and assign to ROIs where appropriate
    for ii = 1:size(track_IDs, 1)
        if mod(ii, update_interval) == 0 || ii == N_tracks
            waitbar(ii/N_tracks, h_progress, "Assigning track " + num2str(ii) + "/" + num2str(N_tracks) + " to the most appropriate cell");
        end
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
    end
    
    close(h_progress);
end


function [tracks_data] = flipTracksInY(tracks_data, im_height, col)
%Flip the y-axis of tracks about the midline of the FOV, Oliver Pambos,
%16/05/2024.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
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


function [data_loaded] = loadPicassoDataset(app)
%Load a new dataset localised by Picasso, Oliver Pambos, 30/03/2026.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%Much of this function is identical to loadSeparateSegTracks(); a future
%refactoring can modularise and simplify both f'ns.
%
%Inputs
%------
%app            (handle)    main GUI handle
%
%Output
%------
%data_loaded    (bool)      true when data has been successfully loaded
%
%Dependent functions
%-------------------
%RequestSourceFiles         - external .mlapp
%DataImportViewerGUI        - external .mlapp
%loadPicassoLocs()          - local to this .m file
%renamePicassoFeatures()    - local to this .m file
%assignLocsToCells()        - local to this .m file
%linkIntoTracks()           - local to this .m file
%renumberTracksByCell()     - local to this .m file
    
    data_loaded = false;
    
    popup = RequestSourceFiles(app.movie_data.params.pipeline);
    uiwait(popup.SelectfilesUIFigure);
    
    %exit if user kills window
    if ~isvalid(popup)
        data_loaded = false;
        return;
    end
    
    %exit if file gathering was unsuccessful
    if ~isprop(popup, "success") || ~popup.success
        data_loaded = false;
        delete(popup);
        return;
    end
    
    %store filepaths
    ref_file                                = char(popup.reference_path);
    seg_file                                = char(popup.segmentation_path);
    tracking_data                           = popup.tracking_pathnames;
    app.movie_data.params.frame_rate        = popup.frame_rate;
    app.movie_data.params.frames_per_file   = popup.frames_per_file;
    app.movie_data.params.frame_offsets     = popup.frame_offsets;
    app.movie_data.params.ffPath            = popup.fluor_path;
    app.movie_data.params.ffFile            = popup.fluor_file;
    
    delete(popup);
    
    %load ref image
    [~, ~, ext] = fileparts(ref_file);
    if strcmpi(ext, '.fits')
        app.movie_data.brightfield_image = fitsread(ref_file);
    else
        app.movie_data.brightfield_image = imread(ref_file);
    end
    
    %average ref image if it has multiple channels/timepoints
    if ndims(app.movie_data.brightfield_image) > 2
        app.movie_data.brightfield_image = mean(app.movie_data.brightfield_image, 3);
    end
    
    %get file extension and read segmentation data
    [~, ~, ext] = fileparts(seg_file);
    try
        switch lower(ext)
            case '.mat'
                seg_data = load(seg_file);
            case {'.dat', '.csv'}
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
    
    %keep track of tracking file type
    app.movie_data.params.tracks_type = "DeepTRACE internal linker";
    
    %load the picasso localisation data
    [picasso_data, column_titles]               = loadPicassoLocs(tracking_data);
    app.movie_data.params.column_titles.tracks  = renamePicassoFeatures(column_titles);
    
    %call pop-up GUI for human correction of drift between reference image and localisations
    popup = DataImportViewerGUI(app, picasso_data);
    uiwait(popup.DataImportViewerUIFigure);
    
    %replace local locs with drift-corrected versions (temp_tracks var name is historical as TrackMate implementation came first)
    drift_corrected_locs = app.movie_data.state.temp_tracks;
    
    %get meshes in 2-column looping format
    meshes = cell(N_cells, 1);
    for ii = 1:N_cells
        meshes{ii, 1} = [app.movie_data.cellROI_data(ii).mesh(:,1:2); flipud(app.movie_data.cellROI_data(ii).mesh(1:end-1,3:4))];
    end
    
    %assign locs to cells
    locs_by_cell = assignLocsToCells(drift_corrected_locs, meshes);
    
    %assignLocsToCells() adds the Cell ID column at position 4; update column titles
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks(1:3), {'Cell ID'}, app.movie_data.params.column_titles.tracks(4:end)];
    
    %prompt the user to provide a memory parameter and maximum track linking distance
    user_input = inputdlg({'Memory parameter (max missing frames):', 'Maximum linking distance (pixels):'}, 'Tracking Parameters', [1 45], {'1', '7'});
    if isempty(user_input)
        app.movie_data.params.mem_param = 1;
        app.movie_data.params.link_dist = 7;
    else
        app.movie_data.params.mem_param = str2double(user_input{1});
        app.movie_data.params.link_dist = str2double(user_input{2});
    end
    
    %link localisations into tracks
    linkIntoTracks(app, locs_by_cell);
    
    %renumber mol_IDs such that they are local to each cell as the combination [cell_ID molID] is unique
    renumberTracksByCell(app);
    
    %generate registry of arbitrary and core feature names to match TrackMate-style output
    titles = app.movie_data.params.column_titles.tracks;
    core   = {'x (px)', 'y (px)', 'Frame', 'MolID', 'Cell ID', 'Background (photons/px)', 'Photons', 'PSF width x axis (px)', 'PSF width y axis (px)',...
        'Localisation precision in x (px)', 'Localisation precision in y (px)', 'Net gradient', 'Ellipticity'};
    isCore = ismember(titles, core);
    
    app.movie_data.params.column_titles.tracks   = titles(isCore);
    app.movie_data.params.arbitrary_features     = titles(~isCore);
    app.movie_data.params.arbitrary_feature_cols = find(~isCore);
    
    if ~isempty(app.movie_data)
        data_loaded       = true;
        app.textout.Value = "Data was loaded successfully. Please now follow the data preparation instructions.";
    end
    
    [~, suggested_name, ~] = fileparts(app.movie_data.params.ffFile(1));
    suggested_name = suggested_name + " DeepTRACE analysis";
    app.textout.Value = "Please choose a sensible name for the dataset";
    app.movie_data.params.title = inputdlg({'Please choose a sensible name for the dataset'}, 'Name this dataset', [1 80], suggested_name);
end


function [picasso_data, column_titles] = loadPicassoLocs(file_pathname)
%Load a Picasso localisation file, Oliver Pambos, 30/03/2026.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%
%
%Inputs
%------
%file_pathname  (str)   string holding filepath for picasso loc file
%
%Output
%------
%picasso_data   (mat)   localisation data from Picasso formated into a
%                           matrix
%column_titles  (cell)  cell array of column names in which each cell
%                           contains a char arr
%
%Dependent functions
%-------------------
%None
    
    %=======================
    %import the picasso data
    %=======================
    picassofile   = h5read(file_pathname{1}, "/locs");
    column_titles = fieldnames(picassofile)';
    
    %convert all vectors to double, concat into single mat
    picassofile = struct2cell(picassofile);
    tmp = cellfun(@double, picassofile, 'UniformOutput', false);
    picasso_data = horzcat(tmp{:});
    
    %error check for missing data, and number of titles matches data cols
    if isempty(picasso_data)
        errordlg("The Picasso localisation data is empty.", "Error loading Picasso data");
        return;
    end
    if numel(column_titles) ~= size(picasso_data, 2)
        errordlg("The Picasso localisation data was incorrectly loaded.", "Error loading Picasso data");
        return;
    end
    
    %==================================================
    %re-order columns to [x, y, frame, everything else]
    %==================================================
    x_idx     = find(strcmp(column_titles, 'x'));
    y_idx     = find(strcmp(column_titles, 'y'));
    frame_idx = find(strcmp(column_titles, 'frame'));
    
    if isempty(x_idx) || isempty(y_idx) || isempty(frame_idx)
        errordlg("Required Picasso columns 'x', 'y', and/or 'frame' were not found.", "Error loading Picasso data");
        return;
    end
    
    new_order = [x_idx, y_idx, frame_idx, setdiff(1:numel(column_titles), [x_idx, y_idx, frame_idx], 'stable')];
    
    %apply to mat and col titles
    picasso_data = picasso_data(:, new_order);
    column_titles = column_titles(new_order);
    
    %==========================================
    %set frame numbers to start at one not zero
    %==========================================
    picasso_data(:, 3) = picasso_data(:, 3) + 1;
end


function [column_titles] = renamePicassoFeatures(column_titles)
%Updates Picasso feature names to match the strings expected by DeepTRACE,
%Oliver Pambos, 30/03/2026.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%Simply reformats the column/feature names to match expected strings used
%by downstream DeepTRACE functions.
%
%Inputs
%------
%column_titles  (cell)  cell array of column names in which each cell
%                           contains a char arr
%
%Output
%------
%column_titles  (cell)  cell array of column names in which each cell
%                           contains a char arr
%
%Dependent functions
%-------------------
%None
    
    %rename columns for consistency between tracking file types using a map
    replacement_map = containers.Map({'x',       'y',      'frame', 'bg',                      'photons', 'sx',                    'sy',                    'lpx',                              'lpy',                              'net_gradient', 'ellipticity'}, ...
                                     {'x (px)',  'y (px)', 'Frame', 'Background (photons/px)', 'Photons', 'PSF width x axis (px)', 'PSF width y axis (px)', 'Localisation precision in x (px)', 'Localisation precision in y (px)', 'Net gradient', 'Ellipticity'});
    
    %replace relevant titles
    for ii = 1:numel(column_titles)
        current_title = column_titles{ii};
        if replacement_map.isKey(current_title)
            column_titles{ii} = replacement_map(current_title);
        end
    end
end


function [locs_by_cell] = assignLocsToCells(locs, meshes)
%Assigns each localisation to a cell, Oliver Pambos, 31/03/2026.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%To improve performance, hittests are performed initially against bounding
%boxes, eliminating the vast majority of more computationally expensive
%comparisons to cell mesh polygons.
%
%To handle cases of overlapping meshes, the algorithm computes the furthest
%distance to cell boundary to determine in which cell the localisation is
%most inside. In the unlikely event of a tie for distance to cell boundary
%the cell with the lowest index is chosen (set in the case of
%MicrobeTracker this is set by the order in which cells are identified).
%
%Performance can be further improved through parallelisation in a future
%refactoring if this f'n becomes a bottleneck for very large datasets.
%
%Input
%-----
%locs           (mat)   NxM matrix of N localisations with M features, for
%                           which the first two columns are (x, y)
%meshes         (cell)  cell array of matrices containing
%                           MicrobeTracker-formatted meshes
%
%Output
%------
%locs_by_cell   (cell)      cell array of localisations for each cell
%                               segmented in the input MicrobeTracker file
%
%Dependent functions
%-------------------
%findPointToMeshDist()
%genHitboxes()          - local to this .m file
    
    N_locs = size(locs, 1);
    N_cells = numel(meshes);
    
    %preallocate outputs
    locs_to_cell = zeros(N_locs, 1);
    locs_by_cell = cell(N_cells, 1);
    
    %obtain bounding boxes for all meshes
    boxes = genHitboxes(meshes);
    
    for ii = 1:N_locs
        %find candidate cells whose hitbox contains current loc
        candidate_cells = find(locs(ii, 1) >= boxes(:, 1) & locs(ii, 2) >= boxes(:, 2) & locs(ii, 1) <= boxes(:, 3) & locs(ii, 2) <= boxes(:, 4));
        
        %skip if no hitbox match
        if isempty(candidate_cells)
            continue;
        end
        
        %confirm candidates using full polygon hit test
        mesh_hits = false(numel(candidate_cells), 1);
        for jj = 1:numel(candidate_cells)
            curr_cell = candidate_cells(jj);
            curr_mesh = meshes{curr_cell};
            
            mesh_hits(jj) = inpolygon(locs(ii, 1), locs(ii, 2), curr_mesh(:, 1), curr_mesh(:, 2));
        end
        
        matched_cells = candidate_cells(mesh_hits);
        
        %assign loc to cell
        if numel(matched_cells) == 1
            %only one valid mesh hit
            locs_to_cell(ii) = matched_cells;
            
        elseif numel(matched_cells) > 1
            %multiple valid mesh hits, assign to cell it is most inside
            d_all = zeros(numel(matched_cells), 1);
            
            %loop over the mesh matches, and compute distance from membrane for each
            for jj = 1:numel(matched_cells)
                curr_cell = matched_cells(jj);
                d_all(jj) = findPointToMeshDist(locs(ii, 1), locs(ii, 2), meshes{curr_cell});
            end
            
            %take the mesh it is most inside to be the assigned cell
            [~, best_idx]    = max(d_all);
            locs_to_cell(ii) = matched_cells(best_idx);
        end
    end
    
    %insert cell_ID col (data only, col titles later added as app handle is currently out of scope here)
    locs = [locs(:,1:3), locs_to_cell, locs(:,4:end)];
    
    %split localisations into cell array
    for ii = 1:N_cells
        locs_by_cell{ii} = locs(locs_to_cell == ii, :);
    end
end


function [boxes] = genHitboxes(meshes)
%Compiles a matrix of hittest boxes from an array of MicrobeTracker meshes,
%Oliver Pambos, 31/03/2026.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%Used once for each segmentation file. This function reduces computational
%overhead by providing a list of candidate boxes, eliminating the need to
%perform more expensive comparisons against polygons from cell
%segmentations.
%
%Input
%-----
%meshes (cell)  cell array of MicrobeTracker-formatted segmented cell
%                   meshes
%
%Output
%------
%boxes  (mat)   Nx4 matrix of hittest box key vertices, with columns:
%                   col 1: x-coordinate of lower left corner
%                   col 2: y-coordinate of lower left corner
%                   col 3: x-coordinate of upper right corner
%                   col 4: y-coordinate of upper right corner
%
%Dependent functions
%-------------------
%None
    
    boxes = zeros(numel(meshes), 4);
    
    %later replace with cellfun()
    for ii = 1:numel(meshes)
        boxes(ii, 1) = min(meshes{ii}(:, 1));
        boxes(ii, 2) = min(meshes{ii}(:, 2));
        boxes(ii, 3) = max(meshes{ii}(:, 1));
        boxes(ii, 4) = max(meshes{ii}(:, 2));
    end
end


function [] = linkIntoTracks(app, locs_by_cell)
%Link locasations grouped by cells into tracks, Oliver Pambos 31/03/2026.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%Perofrms linking into tracks of localisations in each cell using a simple
%nearest-neighbour algorithm.
%
%The algorithm uses two parameters:
%   mem_param: determines how many missing frames can be bridged by a
%               molecule temporarily disappearing.
%   link_dist: determines the maximum distance a molecule can move in the
%               next frame and still be linked.
%
%A future iteration of this algorithm may increase link_dist across missing
%frames to account for free diffusion when tracking is transiently lost,
%factoring in the distance the molecule would have moved while unobserved.
%
%Input
%-----
%app            (handle)    main GUI handle
%locs_by_cell   (cell)      cell array of localisations for each cell
%                               segmented in the input MicrobeTracker file
%
%Output
%------
%None
%
%Dependent functions
%-------------------
%None
    
    mem_param = app.movie_data.params.mem_param;
    link_dist = app.movie_data.params.link_dist;
    
    %loop over cells
    for ii = 1:numel(locs_by_cell)
        curr_locs = locs_by_cell{ii};
        
        %skip empty cells
        if isempty(curr_locs)
            app.movie_data.cellROI_data(ii).tracks = [];
            continue;
        end
        
        %sort by frame
        curr_locs = sortrows(curr_locs, 3);
        
        N_locs      = size(curr_locs, 1);
        track_ids   = zeros(N_locs, 1);
        
        %active track state (those currently being built)
        active_track_IDs      = [];
        active_track_x        = [];
        active_track_y        = [];
        active_track_frame    = [];
        
        %loop over loc-containing frames
        next_track_ID = 1;
        unique_frames = unique(curr_locs(:, 3))';
        for jj = unique_frames      %using unique frames here to avoid evaluating and then skipping empty frames
            %store row numbers for all locs in frame jj
            curr_idx = find(curr_locs(:, 3) == jj);
            
            %remove tracks that would exceed memory param if further linking were to take place
            keep_idx            = (jj - active_track_frame) <= (mem_param + 1);
            active_track_IDs    = active_track_IDs(keep_idx);
            active_track_x      = active_track_x(keep_idx);
            active_track_y      = active_track_y(keep_idx);
            active_track_frame  = active_track_frame(keep_idx);
            
            N_curr      = numel(curr_idx);          %number of locs in frame jj
            N_active    = numel(active_track_IDs);  %number of active tracks being built
            
            %loop over all locs in the curr frame, and compute dist each valid candidate would have to extend the currently active tracks
            candidate_pairs = [];
            for kk = 1:N_curr
                %current loc's row number, and (x,y) coords
                loc_row = curr_idx(kk);
                loc_x   = curr_locs(loc_row, 1);
                loc_y   = curr_locs(loc_row, 2);
                
                %loop over all active tracks, computing dist between curr loc and end of all active tracks being considered by linker
                for ll = 1:N_active
                    %if mem_param exceeded, skip this active track, the longest valid gap is (mem_param + 1), e.g. previous tracked loc was 2 frames earlier if mem_param == 1
                    frame_gap = jj - active_track_frame(ll);
                    if frame_gap > (mem_param + 1)
                        continue;
                    end
                    
                    %compute dist between curr loc and last loc in active track being considered for linking
                    d = hypot(loc_x - active_track_x(ll), loc_y - active_track_y(ll));  %I should replace findEuclidDist() elsewhere in code with this f'n to avoid external call overhead
                    
                    %if the linking dist is valid, record this as a candidate
                    if d <= link_dist
                        %array will grow over time but this isn't terribly costly in most SPT datasets
                        candidate_pairs = [candidate_pairs; kk, ll, d]; %#ok<AGROW>
                    end
                end
            end
            
            %============================
            %nearest-neighbour assignment
            %============================
            %keep track of whether each loc in curr frame, and each active track, has already been linked
            assigned_locs   = false(N_curr, 1);
            assigned_tracks = false(N_active, 1);
            
            if ~isempty(candidate_pairs)
                %sort by ascending distance
                candidate_pairs = sortrows(candidate_pairs, 3);
                
                %loop over candidate pairs
                for kk = 1:size(candidate_pairs, 1)
                    loc_local_idx = candidate_pairs(kk, 1);
                    track_local_idx = candidate_pairs(kk, 2);
                    
                    %skip if either of the loc-track candidate pair has already been linked
                    if assigned_locs(loc_local_idx) || assigned_tracks(track_local_idx)
                        continue;
                    end
                    
                    %assign track ID to identified loc
                    loc_row             = curr_idx(loc_local_idx);
                    track_ids(loc_row)  = active_track_IDs(track_local_idx);
                    
                    %update new end-point of currently active track
                    active_track_x(track_local_idx)     = curr_locs(loc_row, 1);
                    active_track_y(track_local_idx)     = curr_locs(loc_row, 2);
                    active_track_frame(track_local_idx) = jj;
                    
                    %mark loc and track as assigned
                    assigned_locs(loc_local_idx)        = true;
                    assigned_tracks(track_local_idx)    = true;
                end
            end
            
            %start new tracks for any locs in curr frame that were not unassigned
            unassigned_idx = curr_idx(~assigned_locs);
            for kk = 1:numel(unassigned_idx)
                loc_row = unassigned_idx(kk);
                
                track_ids(loc_row) = next_track_ID;
                
                %add new track to active track list
                active_track_IDs(end+1, 1) = next_track_ID;
                active_track_x(end+1, 1) = curr_locs(loc_row, 1);
                active_track_y(end+1, 1) = curr_locs(loc_row, 2);
                active_track_frame(end+1, 1) = curr_locs(loc_row, 3);
                
                next_track_ID = next_track_ID + 1;
            end
        end
        
        %append track IDs
        app.movie_data.cellROI_data(ii).tracks = [curr_locs(:, 1:3), track_ids, curr_locs(:, 4:end)];
    end
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks(1:3), {'MolID'}, app.movie_data.params.column_titles.tracks(4:end)];
end