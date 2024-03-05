function [] = importGroundTruth(app)
%Import known ground truth, Oliver Pambos, 29/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: importGroundTruth
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
%Import a known ground truth for the loaded data. This primarily enables
%the use of simulated data for training and benchmarking/performance
%evaluation. The ground truth is provided via a user prompt in the form of
%a tab-separated plain text file (extension .tsv, .dat, .txt) containing
%only numeric data with the following four columns,
%
%   1. Class (ground truth label)
%   2. Frame number
%   3. mol_ID (mol_ID)  - currently unused as [cell_ID frame_num] are in our simulations unique
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
%then retrieve from class_map with O(1) time complexity. This avoids nested
%search, greatly improving performance, which is important for extremely
%large synthetic datasets that may be used for benchmarking the ML models.
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
%None
    
    %obtain frame number column
    [frame_col] = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Frame');
    if frame_col == 0
        error('Error in importGroundTruth(): column ID not found');
    end
    
    %get file containing ground truth from the user; note all data must be numeric
    [file, path] = uigetfile({'*.tsv;*.dat;*.txt', 'Data Files (*.tsv, *.dat, *.txt)'}, 'Select the data file');
    if isequal(file, 0)
        disp('User selected Cancel');
    else
        fullPath        = fullfile(path, file);
        opts            = detectImportOptions(fullPath, 'Delimiter', '\t');
        dataTbl         = readtable(fullPath, opts);
        ground_truth    = table2array(dataTbl);
    end
    
    %clear any existing ground truth data
    if isfield(app.movie_data, "results")
        app.movie_data.results = rmfield(app.movie_data.results, 'GroundTruth');
    end
    
    
    %if class names already exist, ask the user if they want to overwrite
    update_class_names = true;
    if isfield(app.movie_data.params, "class_names")
        choice = questdlg('Do you want to use existing class names?', 'Class Name Selection', 'Yes', 'No', 'Yes');
        switch choice
            case 'Yes'
                % << do nothing >> %update_class_names = true;
            case 'No'
                update_class_names = false;
            otherwise
                app.textout.Value = "User clicked cancel, ground truth data not loaded.";
                return;
        end
    end
    
    %update class names with user prompt if required
    if update_class_names
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
    
    %compute and store the event sequences and labelling times
    timestamp = string(datetime);
    for ii = 1:size(app.movie_data.cellROI_data,1)
        app.movie_data.results.GroundTruth.LabelledMols{ii,1}.EventSequence     = condenseStateSequence(app.movie_data.results.GroundTruth.LabelledMols{ii,1}.Mol(:,end));
        app.movie_data.results.GroundTruth.LabelledMols{ii,1}.DateClassified = timestamp;
    end
    
end






