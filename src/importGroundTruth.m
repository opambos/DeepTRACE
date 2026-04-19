function [] = importGroundTruth(app)
%Import known ground truth, 29/02/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
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
%Import a known ground truth for the loaded data. This primarily enables
%the use of simulated data for training and benchmarking/performance
%evaluation. The ground truth is provided via a user prompt in the form of
%a tab-separated plain text file (extension .tsv, .dat, .txt) containing
%only numeric data with the following four columns,
%
%   1. Class (ground truth label)
%   2. Frame number
%   3. mol_ID (mol_ID)  - currently unused as [cell_ID frame_num] are in
%                           our simulations unique
%   4. cell_ID (cell_ID)
%
%Note that all entries (including class label) are integers. In the case of
%the class label this is a reference to the entry in the class strings held
%in the main app.movie_data.params.class_names sub-struct.
%
%Due to the nature of the SMLM localisation, tracking, and filtering
%processes not all entries in ground_truth will have a corresponding entry
%in the GroundTruth results substruct. This is handled effectly by the
%lookup process.
%
%Method: This function updates the labeled class for each frame of each
%molecule and in doing so constructs the ground truth results substruct.
%The class label for each entry is written into the final column of
%app.movie_data.results.GroundTruth.LabelledMols{ii, 1}.Mol by matching it
%to the unique entry in the supplied ground truth data.
%
%The source data (ground_truth) is preprocessed into a map (class_map)
%using the unique combination of cell_ID, mol_ID, and frame number as keys,
%and mapped to the labelled class. The class label for each timepoint is
%then retrieved from class_map with O(1) time complexity. This avoids
%nested search, greatly improving performance, which is important for
%extremely large synthetic datasets that may be used for benchmarking the
%ML models.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle, now containing ground truth substruct
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%eliminateFalseLocsUsingGT()    - local to this .m file
    
    if ~isprop(app, "movie_data") || ~isfield(app.movie_data, "params")
        warndlg("There is currently no data loaded. Please either open an existing analysis file or load new data before continuing.", "Cannot import ground truth", "modal")
        app.textout.Value = "There is currently no data loaded. Please either open an existing analysis file or load new data before continuing.";
        return;
    end
    if ~isfield(app.movie_data.params, "data_prepared") || ~app.movie_data.params.data_prepared
        warndlg("The currently loaded data has not been correctly prepared. If you have just loaded data, you must complete data preparation in the [Prepare] tab before importing ground truth data.", "Cannot import ground truth", "modal")
        app.textout.Value = "The currently loaded data has not been correctly prepared. If you have just loaded data, you must complete data preparation in the [Prepare] tab before importing ground truth data.";
        return;
    end
    
    %obtain frame number column
    if isfield(app.movie_data.params, "column_titles") && isfield(app.movie_data.params.column_titles, "tracks")
        [frame_col] = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Frame');
        if frame_col == 0
            frame_col = 3;
        end
    else
        frame_col = 3;
    end
    
    %user provides files containing ground truth; note all data must be numeric
    app.textout.Value = "Please select the file(s) containing ground truth data.";
    [file_list, path] = uigetfile({'*.tsv;*.dat;*.txt', 'Ground truth data (*.tsv, *.dat, *.txt)'}, ...
                                  'Select the data file', 'MultiSelect', 'on');
    if isequal(file_list, 0)
        disp('User selected Cancel');
        return;
    end

    %ensure file_list is cell array when only one file selected
    if ischar(file_list)
        file_list = {file_list};
    end
    
    if size(file_list,2) ~= size(app.movie_data.params.frame_offsets,2)
        app.textout.Value = "The number of ground truth files does not match the number of videos, please try again.";
        warning("Number of ground truth files provided by user did not match the number of videos");
        errordlg("Number of selected files does not match the number of videos, please try again", "Mismatch Error");
        return;
    end
    
    %prompt user to verify file order
    file_list = confirmVideoOrder(file_list);
    
    %print the file order to screen
    message = {'Ground truth files in the following order:'};
    
    %append each entry to the message, and display file order
    for idx = 1:numel(file_list)
        message{end+1} = sprintf('%d. ''%s''', idx, file_list{idx});
    end
    app.textout.Value = message;
    
    %read data from each file and apply frame_offsets
    all_data = [];
    for i = 1:size(file_list,2)
        full_path = fullfile(path, file_list{i});
        opts = detectImportOptions(full_path, 'FileType', 'text', 'Delimiter', '\t');
        dataTbl = readtable(full_path, opts);
        curr_ground_truth = table2array(dataTbl);
        
        %add frame_offsets to column 2
        curr_ground_truth(:,2) = curr_ground_truth(:,2) + app.movie_data.params.frame_offsets(i);
        
        %concatenate all the data
        all_data = [all_data; curr_ground_truth];
    end
    ground_truth = all_data;
    
    %clear any existing ground truth data
    if isfield(app.movie_data, "results") && isfield(app.movie_data.results, "GroundTruth")
        app.movie_data.results = rmfield(app.movie_data.results, 'GroundTruth');
    end
    
    % %if class names already exist, ask the user if they want to overwrite
    % update_class_names = true;
    % if isfield(app.movie_data.params, "class_names")
    %     choice = questdlg('Do you want to use existing class names?', 'Class Name Selection', 'Yes', 'No', 'Yes');
    %     switch choice
    %         case 'Yes'
    %             update_class_names = false;
    %         case 'No'
    %             % << do nothing >>
    %         otherwise
    %             app.textout.Value = "User clicked cancel, ground truth data not loaded.";
    %             return;
    %     end
    % end
    
    %update class names with user prompt if required
    if ~isfield(app.movie_data.params, "class_names") || isempty(app.movie_data.params.class_names)
        class_names_input = inputdlg('Enter a list of class names for each of the diffusive states, separated by commas');
        
        %exit early if user either presses cancel, closes the dialogue box, or doesn't enter anything
        if isempty(class_names_input) || isempty(class_names_input{1})
            error("Warning in labelFromScratch: Either user cancelled or closed the class name definition dialogue, or they entered an empty input.");
        else
            app.movie_data.params.class_names = class_names_input;
        end

        %parsing user input: separates the user inputs by the comma delimiter, then strips out any of the white space at beginning and end
        app.movie_data.params.class_names = strip(split(app.movie_data.params.class_names, ','));
    end
    
    %define the default class colours
    preset_colours = [1,       0,       0           %red            %0.7843,  0.2157,  0.2157;     %DeepTRACE red
                      0,       0.4471,  0.7412;     %DeepTRACE blue
                      0,       1,       0;          %green
                      133/255, 176/255, 154/255;    %Cambridge blue
                      87/255,  188/255, 240/255;    %light blue
                      243/255, 69/255,  107/255     %light red
                      ];
    %if there are more states than the currently described number of colours, then use the colours available, followed by randomly-selected colours
    if size(app.movie_data.params.class_names,1) > size(preset_colours, 1)
        app.movie_data.params.event_label_colours = zeros(size(app.movie_data.params.class_names,1),3);
        app.movie_data.params.event_label_colours(1:size(preset_colours, 1),:) = preset_colours;
        app.movie_data.params.event_label_colours(size(preset_colours,1)+1:size(app.movie_data.params.class_names,1),:) = rand(size(app.movie_data.params.class_names,1) - size(preset_colours,1), 3);
    else
        %otherwise use the available colours
        app.movie_data.params.event_label_colours(1:size(app.movie_data.params.class_names,1),:) =  preset_colours(1:size(app.movie_data.params.class_names,1),:);
    end
    
    
    %copy over every track to the ground truth struct
    count = 1;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs,1)
            %write the LoColi tracks data to the LabelledMols struct
            app.movie_data.results.GroundTruth.LabelledMols{count,1}.Mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj), :);
            
            %update the GroundTruth results substruct
            app.movie_data.results.GroundTruth.LabelledMols{count,1}.CellID             = ii;
            app.movie_data.results.GroundTruth.LabelledMols{count,1}.MolID              = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj);
            app.movie_data.results.GroundTruth.LabelledMols{count,1}.MoleculeDuration   = size(app.movie_data.results.GroundTruth.LabelledMols{count}.Mol,1) / app.movie_data.params.frame_rate;    %in seconds
            
            count = count + 1;
        end
    end
    
    %generate a unique key for each entry in ground_truth and map it to the class
    key_set     = cell(size(ground_truth, 1), 1);
    value_set   = zeros(size(ground_truth, 1), 1);
    for ii = 1:size(ground_truth, 1)
        key             = sprintf('%d_%d', ground_truth(ii, 4), ground_truth(ii, 2)); %cellID_frame (mol_ID currently unused due to nature of existing simulations)
        key_set{ii}     = key;
        value_set(ii)   = ground_truth(ii, 1); %class label for this entry
    end
    class_map = containers.Map(key_set, value_set);
    
    %loop over molecules
    for ii = 1:size(app.movie_data.results.GroundTruth.LabelledMols, 1)
        curr_mol    = app.movie_data.results.GroundTruth.LabelledMols{ii, 1}.Mol;
        cell_ID     = app.movie_data.results.GroundTruth.LabelledMols{ii, 1}.CellID;
        %mol_ID      = app.movie_data.results.GroundTruth.LabelledMols{ii, 1}.MolID;    %currently unused due to nature of existing simulations
        
        %loop over frames
        for jj = 1:size(curr_mol, 1)
            frame_num   = curr_mol(jj, frame_col);
            key         = sprintf('%d_%d', cell_ID, frame_num);  %mol_ID removed as [cell_ID frame_num] is currently unique
            
            %if the key exists write class label
            if isKey(class_map, key)
                curr_mol(jj, end) = class_map(key);
            end
        end
        
        %update matrix in the original cell array
        app.movie_data.results.GroundTruth.LabelledMols{ii, 1}.Mol = curr_mol;
    end
    
    %use ground truth data to identify and eliminate false localisations in all tracks
    eliminateFalseLocsUsingGT(app);

    %compute and store the event sequences and labelling times
    timestamp = string(datetime);
    for ii = 1:size(app.movie_data.results.GroundTruth.LabelledMols, 1)
        app.movie_data.results.GroundTruth.LabelledMols{ii,1}.EventSequence  = condenseStateSequence(app.movie_data.results.GroundTruth.LabelledMols{ii,1}.Mol(:,end));
        app.movie_data.results.GroundTruth.LabelledMols{ii,1}.DateClassified = timestamp;
    end

    app.textout.Value = ("Completed import of ground truth data.");
end


function [] = eliminateFalseLocsUsingGT(app)
%Erase from tracks and ground truth tracks and tracks that don't appear in
%the ground truth annotation data, 29/02/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
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
%The ground truth data provides an excellent opportunity to identify and
%remove erroneous false localisations in the dataset. After annotating the
%ground truth track data (app.movie_data.results.GroundTruth), this
%function identifies all localisations for which there is a missing
%ground truth annotation (i.e. -1), and then eliminates this from both the
%ground truth track data, and also the global track data
%(app.movie_data.cellROI_data(jj).tracks).
%
%Eliminating these localisations from the source data is necessary because
%subsequent datasets for model annotation are taken from here prior to each
%model classificaiton process; if this were avoided there would be track
%length conflicts when computing metrics. Note that I have also implemented
%error checking for inconsistent track lengths, and
%computeAnnotationMetrics.m also contains advice on further improvements
%that will perform a direct lookup to the unique key (frame, or
%[x,y,frame]), however this would increase latency on large files.
%
%Update: this function also now eliminates missing tracks, for which the
%comparison to ground truth removed all rows, and also re-applies the
%minimum track length criteria. Note however that the length criteria is
%currently computed from total number of rows, not continuous tracks. A
%future update may also re-produce the memory parameter filtering.
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
    
    gt_data = app.movie_data.results.GroundTruth.LabelledMols;
    cellROI_data = app.movie_data.cellROI_data;
    
    h = waitbar(0, 'Eliminating data not present in ground truth...');
    
    N_tracks = numel(gt_data);
    
    %loop over tracks in ground truth annotations
    for ii = 1:N_tracks
        curr_gt_mol = gt_data{ii}.Mol;
        
        %identify error rows (with annotation -1) using first 3 cols
        error_mask = curr_gt_mol(:, end) == -1;
        error_rows = curr_gt_mol(error_mask, 1:3);
        
        %keep track of rows to be deleted in cellROI_data
        for jj = 1:numel(cellROI_data)
            cell_tracks = cellROI_data(jj).tracks;
            
            %pre-allocate rows to delete
            del_row_idx = false(size(cell_tracks, 1), 1);
            
            [~, idx] = ismember(cell_tracks(:, 1:3), error_rows, 'rows');
            del_row_idx(idx ~= 0) = true;
            
            %mark rows for deletion in the logical index
            if any(del_row_idx)
                cellROI_data(jj).tracks(del_row_idx, :) = [];
            end
        end
        
        %remove offending rows from gt results data
        gt_data{ii}.Mol = curr_gt_mol(~error_mask, :);
        
        waitbar(ii / N_tracks, h);
    end
    
    waitbar(1, h, "Removing empty tracks...");

    %pre-allocate empty indices del list
    empty_track_indices = false(N_tracks, 1);
    
    %work out which are empty, and re-apply the min track length criteria
    for ii = 1:N_tracks
        if isempty(gt_data{ii}.Mol) || size(gt_data{ii}.Mol, 1) < app.movie_data.params.min_track_len
            empty_track_indices(ii) = true;
        end
    end
    
    %erase empty tracks
    gt_data(empty_track_indices) = [];

    close(h);

    %write data back to app handles
    app.movie_data.results.GroundTruth.LabelledMols = gt_data;
    app.movie_data.cellROI_data = cellROI_data;
end


function [] = shiftGroundTruth(app)
%Shift ground truth annotations by one timepoint, 10/09/2024.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
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
%Depending on the definition of ground truth, and the indexing of initial
%frames, the sequence of annotations may have to be shifted by a single
%timepoint. This function performs this by moving all annotations down one
%row, leaving a copy of the initial datapoint in the first row. This
%function operates on the ground truth of all molecules with a single call.
%
%Note to any future editor of this code: if you edit this to move multiple
%frames, the initial frames into which no new annotations are moved will
%contain the original data, which is likely unwanted. Generally, at the
%start of the time series, you want the first known state to be replicated
%backwards into the missing data, not to have a copy of the original,
%unshifted data, so in this scenario you will have to either (i) add a
%statement to perform this operation, or (ii) repeatedly call this
%function. The former solution is obviously the more efficient.
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
    
    for ii = 1:numel(app.movie_data.results.GroundTruth.LabelledMols)
        %access matrix only once from nested structure
        mol = app.movie_data.results.GroundTruth.LabelledMols{ii, 1}.Mol;
        
        %if there is data shift down one row
        if ~isempty(mol)
            %shift class annotations down one row
            mol(2:end, end) = mol(1:end-1, end);
            app.movie_data.results.GroundTruth.LabelledMols{ii, 1}.Mol = mol;
        end
    end
end