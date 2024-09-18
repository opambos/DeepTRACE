function [success] = scaleLabelledFeatures(app)
%Scale features in labelled data, Oliver Pambos, 28/04/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: scaleLabelledFeatures
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
%This function scales user-selected features in the user-selected source
%data (currently either VisuallyLabelled or GroundTruth substruct), and
%saves this to a new substruct (FeatureScaledData). This function is called
%during the process of generating training datasets for ML models. To
%ensure seemless future classification using these models on unseen
%datasets, the parameters used in the transformation (e.g. mean and
%standard deviation in the case of Z-score) and the method used are saved
%alongside the model such that they remain with the trained model file.
%This simplifies the flow of execution outside of the scope of this
%function.
%
%Note that this function also removes any unlabelled trajectories, and
%where necessary also crops trajectories when feature-dependent misisng
%rows occur (e.g. step size, which has no meaningful value for the first
%localisation in a trajectory); this is implemented through a call to
%cropTrajectories() - see function for more details. Future versions may
%return to other methods of handling, such as imputation of the missing
%data.
%
%Update 20240610: FeatureScaledData is now constructed using only feature
%columns used for training models. This enables the concatenation of
%annotated data from multiple external files, which do not have to contain
%exactly the same features, only that they possess the features used for
%model training and classification. This is carried out while maintaining
%the flexibility to build on this later for data mining of unused features.
%Additionally, unique identifiers cell ID, and mol ID have a new identifier
%source data added to them which records which file in a new cell array
%(FeatureScaledData.source_file) the track was extracted from. This enables
%tracking of data, and easier implementation of unit testing, visualisation
%of data, and downstream analytics. In the current implementation this data
%is discarded when training data is formatted from FeatureScaledData, but
%is used heavily during internal testing.
%
%This .m file also contains two helper function (checkTrainingDataValid(),
%and repairFeatureOrder()) which were used in an earlier implementation of
%training data concatenation which worked by retaining all available
%feature columns, including those not used by the models. These functions
%are retained here temporarily while testing is ongoing, and likely removed
%before public release.
%
%This code is bulky, and in places repetitive, and will likely be
%refactored/modularised in a future update.
%
%Input
%-----
%app        (handle)    main GUI handle
%
%Output
%------
%success    (bool)  true if features successfully scaled; else false
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%cropTrajectories()
%findColumnIdx()
%SelectTrainingFilesPopUp   - discrete app
    
    success = false;
    
    %compile a list of features selected by the user (format is column IDs)
    app.movie_data.models.temp_params.feature_cols = [];
    for jj = 1:size(app.MLfeatures.CheckedNodes, 1)
        feature_name = app.MLfeatures.CheckedNodes(jj).Text;
        a = strcmp(string(app.movie_data.params.column_titles.tracks), feature_name);
        app.movie_data.models.temp_params.feature_cols = [app.movie_data.models.temp_params.feature_cols find(a,1)];
        
        %keep track of column titles of ref data for plotting
        app.movie_data.models.temp_params.feature_names{jj} = feature_name;
    end
    
    %get the user-selected method for feature scaling used to train model, and record in model params
    method = app.FeaturescalingDropDown.Value;
    app.movie_data.models.temp_params.feature_scaling = method;
    
    %intialise, or wipe existing data
    app.movie_data.results.FeatureScaledData.LabelledMols = {};
    
    %copy over all labelled data to be used for training, validation, and testing
    switch app.SourcedataDropDown.Value
        case 'Human annotations'
            %find column indices of feature cols
            feature_cols = zeros(1, size(app.movie_data.models.temp_params.feature_names, 2));
            for jj = 1:size(app.movie_data.models.temp_params.feature_names, 2)
                feature_cols(jj) = findColumnIdx(app.movie_data.params.column_titles.tracks, app.movie_data.models.temp_params.feature_names(jj));
            end
            
            %keep record of data souce being current file
            app.movie_data.results.FeatureScaledData.source_file{1, 1} = 'Currently loaded data';
            
            %transfer only training feature cols and label col from currently loaded human annotated data to FeatureScaledData
            for jj = 1:size(app.movie_data.results.VisuallyLabelled.LabelledMols, 1)
                cols_to_keep = [feature_cols, size(app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1}.Mol, 2)];
                app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol            = app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1}.Mol(:, cols_to_keep);
                app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.CellID         = app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1}.CellID;
                app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.MolID          = app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1}.MolID;
                app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.source_data    = 1;
            end
            
        case 'Ground truth'
            %find column indices of feature cols
            feature_cols = zeros(1, size(app.movie_data.models.temp_params.feature_names, 2));
            for jj = 1:size(app.movie_data.models.temp_params.feature_names, 2)
                feature_cols(jj) = findColumnIdx(app.movie_data.params.column_titles.tracks, app.movie_data.models.temp_params.feature_names(jj));
            end
            
            %keep record of data souce being current file
            app.movie_data.results.FeatureScaledData.source_file{1, 1} = 'Currently loaded data';
            
            %transfer only training feature cols and label col from currently loaded ground truth data to FeatureScaledData
            for jj = 1:size(app.movie_data.results.GroundTruth.LabelledMols, 1)
                cols_to_keep = [feature_cols, size(app.movie_data.results.GroundTruth.LabelledMols{jj, 1}.Mol, 2)];
                app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol            = app.movie_data.results.GroundTruth.LabelledMols{jj, 1}.Mol(:, cols_to_keep);
                app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.CellID         = app.movie_data.results.GroundTruth.LabelledMols{jj, 1}.CellID;
                app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.MolID          = app.movie_data.results.GroundTruth.LabelledMols{jj, 1}.MolID;
                app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.source_data    = 1;
            end
            
        case 'Human annotations (mulitple experiments)'
            popup = SelectTrainingFilesPopUp(app);
            uiwait(popup.UIFigure);
            
            %exit if user didn't provide valid file selection
            if ~isfield(app.movie_data.params, "train_data_source") || isempty(app.movie_data.params.train_data_source) || ~size(app.movie_data.params.train_data_source, 1) > 0
                warndlg("User did not provide valid source files containing annotated tracks; if you wish to train only on currently loaded annotation please select this from the training data source dropdown.", "Suitable files were not provided.");
                success = false;
                return;
            end
            
            %concatenate all data into FeatureScaledData, optionally including the human annotations in the currently loaded file
            if strcmp(app.movie_data.params.train_data_source(1, 1), '[Currently loaded annotations]')
                %find the expected column indices based on the currently loaded data
                feature_cols = zeros(1, size(app.movie_data.models.temp_params.feature_names, 2));
                for jj = 1:size(app.movie_data.models.temp_params.feature_names, 2)
                    feature_cols(jj) = findColumnIdx(app.movie_data.params.column_titles.tracks, app.movie_data.models.temp_params.feature_names(jj));
                end
                
                %keep record of user including data from current file
                app.movie_data.results.FeatureScaledData.source_file{1, 1} = 'Currently loaded data';
                
                %transfer only training feature cols and label col from currently loaded human annotated data to FeatureScaledData
                for jj = 1:length(app.movie_data.results.VisuallyLabelled.LabelledMols)
                    cols_to_keep = [feature_cols, size(app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1}.Mol, 2)];    
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol            = app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1}.Mol(:, cols_to_keep);
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.CellID         = app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1}.CellID;
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.MolID          = app.movie_data.results.VisuallyLabelled.LabelledMols{jj, 1}.MolID;
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.source_data    = 1;
                end
                
                %loop over all external files, loading the data
                for jj = 2:size(app.movie_data.params.train_data_source, 1)
                    curr_pathname = app.movie_data.params.train_data_source{jj};
                    app.movie_data.results.FeatureScaledData.source_file{jj, 1} = curr_pathname;
                    
                    %load the next datafile
                    data = load(curr_pathname);
                    
                    %find the col indices for the new data based on file's column titles
                    feature_cols = zeros(1, numel(app.movie_data.models.temp_params.feature_names));
                    for kk = 1:numel(app.movie_data.models.temp_params.feature_names)
                        feature_cols(kk) = findColumnIdx(data.movie_data.params.column_titles.tracks, app.movie_data.models.temp_params.feature_names{kk});
                    end
                    
                    %if the columns all exist, remove irrelevant feature columns from imported data, and append
                    if any(feature_cols == 0)
                        success = false;
                        warning('The required data fields are missing in file: %s', curr_pathname);
                        h_warn = warndlg("File " + curr_pathname + " could not be loaded or does not contain suitable features. Loading will continue with other datasets.", "Unable to load annotations from file.", 'modal');
                        uiwait(h_warn);
                    else                                
                        %generate new cell array containing only feature cols and labels
                        new_mols = cell(size(data.movie_data.results.VisuallyLabelled.LabelledMols));
                        for kk = 1:size(data.movie_data.results.VisuallyLabelled.LabelledMols, 1)
                            cols_to_keep                = [feature_cols, size(data.movie_data.results.VisuallyLabelled.LabelledMols{kk, 1}.Mol, 2)];
                            new_mols{kk, 1}.Mol         = data.movie_data.results.VisuallyLabelled.LabelledMols{kk, 1}.Mol(:, cols_to_keep);
                            new_mols{kk, 1}.CellID      = data.movie_data.results.VisuallyLabelled.LabelledMols{kk, 1}.CellID;
                            new_mols{kk, 1}.MolID       = data.movie_data.results.VisuallyLabelled.LabelledMols{kk, 1}.MolID;
                            new_mols{kk, 1}.source_data = jj;
                        end
                        
                        %append imported data to FeatureScaledData
                        app.movie_data.results.FeatureScaledData.LabelledMols = [app.movie_data.results.FeatureScaledData.LabelledMols; new_mols];
                    end
                end
            
            %if user doesn't want to include currently loaded annotations
            else
                %loop over all external files, loading the data
                for jj = 1:size(app.movie_data.params.train_data_source, 1)
                    curr_pathname = app.movie_data.params.train_data_source{jj};
                    app.movie_data.results.FeatureScaledData.source_file{jj, 1} = curr_pathname;
                    
                    %load the next datafile
                    data = load(curr_pathname);
                    
                    %find the col indices for the new data based on file's column titles
                    feature_cols = zeros(1, numel(app.movie_data.models.temp_params.feature_names));
                    for kk = 1:numel(app.movie_data.models.temp_params.feature_names)
                        feature_cols(kk) = findColumnIdx(data.movie_data.params.column_titles.tracks, app.movie_data.models.temp_params.feature_names{kk});
                    end
                    
                    %if the columns all exist, remove irrelevant feature columns from imported data, and append
                    if any(feature_cols == 0)
                        success = false;
                        warning('The required data fields are missing in file: %s', curr_pathname);
                        h_warn = warndlg("File " + curr_pathname + " could not be loaded or does not contain suitable features. Loading will continue with other datasets.", "Unable to load annotations from file.");
                        uiwait(h_warn);
                    else                                
                        %generate new cell array containing only feature cols and labels
                        new_mols = cell(size(data.movie_data.results.VisuallyLabelled.LabelledMols));
                        for kk = 1:size(data.movie_data.results.VisuallyLabelled.LabelledMols, 1)
                            cols_to_keep                = [feature_cols, size(data.movie_data.results.VisuallyLabelled.LabelledMols{kk, 1}.Mol, 2)];
                            new_mols{kk, 1}.Mol         = data.movie_data.results.VisuallyLabelled.LabelledMols{kk, 1}.Mol(:, cols_to_keep);
                            new_mols{kk, 1}.CellID      = data.movie_data.results.VisuallyLabelled.LabelledMols{kk, 1}.CellID;
                            new_mols{kk, 1}.MolID       = data.movie_data.results.VisuallyLabelled.LabelledMols{kk, 1}.MolID;
                            new_mols{kk, 1}.source_data = jj;
                        end
                        
                        %append imported data to FeatureScaledData
                        app.movie_data.results.FeatureScaledData.LabelledMols = [app.movie_data.results.FeatureScaledData.LabelledMols; new_mols];
                    end
                end
            end
            
        case 'Ground truth (mulitple simulations)'
            popup = SelectTrainingFilesPopUp(app);
            uiwait(popup.UIFigure);
            
            %exit if user didn't provide valid file selection
            if ~isfield(app.movie_data.params, "train_data_source") || isempty(app.movie_data.params.train_data_source) || ~size(app.movie_data.params.train_data_source, 1) > 0
                warndlg("User did not provide valid source files containing annotated tracks; if you wish to train only on currently loaded annotation please select this from the training data source dropdown.", "Suitable files were not provided.");
                success = false;
                return;
            end
            
            %concatenate all data into FeatureScaledData, optionally including the ground truth in the currently loaded file
            if strcmp(app.movie_data.params.train_data_source(1, 1), '[Currently loaded annotations]')
                %find the expected column indices based on the currently loaded data
                feature_cols = zeros(1, size(app.movie_data.models.temp_params.feature_names, 2));
                for jj = 1:size(app.movie_data.models.temp_params.feature_names, 2)
                    feature_cols(jj) = findColumnIdx(app.movie_data.params.column_titles.tracks, app.movie_data.models.temp_params.feature_names(jj));
                end
                
                %keep record of user including data from current file
                app.movie_data.results.FeatureScaledData.source_file{1, 1} = 'Currently loaded data';
                
                %transfer only training feature cols and label col from currently loaded ground truth data to FeatureScaledData
                for jj = 1:length(app.movie_data.results.GroundTruth.LabelledMols)
                    cols_to_keep = [feature_cols, size(app.movie_data.results.GroundTruth.LabelledMols{jj, 1}.Mol, 2)];    
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol            = app.movie_data.results.GroundTruth.LabelledMols{jj, 1}.Mol(:, cols_to_keep);
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.CellID         = app.movie_data.results.GroundTruth.LabelledMols{jj, 1}.CellID;
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.MolID          = app.movie_data.results.GroundTruth.LabelledMols{jj, 1}.MolID;
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.source_data    = 1;
                end
                
                %loop over all external files, loading the data
                for jj = 2:size(app.movie_data.params.train_data_source, 1)
                    curr_pathname = app.movie_data.params.train_data_source{jj};
                    app.movie_data.results.FeatureScaledData.source_file{jj, 1} = curr_pathname;
                    
                    %load the next datafile
                    data = load(curr_pathname);
                    
                    %find the col indices for the new data based on file's column titles
                    feature_cols = zeros(1, numel(app.movie_data.models.temp_params.feature_names));
                    for kk = 1:numel(app.movie_data.models.temp_params.feature_names)
                        feature_cols(kk) = findColumnIdx(data.movie_data.params.column_titles.tracks, app.movie_data.models.temp_params.feature_names{kk});
                    end
                    
                    %if the columns all exist, remove irrelevant feature columns from imported data, and append
                    if any(feature_cols == 0)
                        success = false;
                        warning('The required data fields are missing in file: %s', curr_pathname);
                        h_warn = warndlg("File " + curr_pathname + " could not be loaded or does not contain suitable features. Loading will continue with other datasets.", "Unable to load annotations from file.", 'modal');
                        uiwait(h_warn);
                    else
                        %generate new cell array containing only feature cols and labels
                        new_mols = cell(size(data.movie_data.results.GroundTruth.LabelledMols));
                        for kk = 1:size(data.movie_data.results.GroundTruth.LabelledMols, 1)
                            cols_to_keep                = [feature_cols, size(data.movie_data.results.GroundTruth.LabelledMols{kk, 1}.Mol, 2)];
                            new_mols{kk, 1}.Mol         = data.movie_data.results.GroundTruth.LabelledMols{kk, 1}.Mol(:, cols_to_keep);
                            new_mols{kk, 1}.CellID      = data.movie_data.results.GroundTruth.LabelledMols{kk, 1}.CellID;
                            new_mols{kk, 1}.MolID       = data.movie_data.results.GroundTruth.LabelledMols{kk, 1}.MolID;
                            new_mols{kk, 1}.source_data = jj;
                        end
                        
                        %append imported data to FeatureScaledData
                        app.movie_data.results.FeatureScaledData.LabelledMols = [app.movie_data.results.FeatureScaledData.LabelledMols; new_mols];
                    end
                end
            
            %if user doesn't want to include currently loaded ground truth data
            else
                %loop over all external files, loading the data
                for jj = 1:size(app.movie_data.params.train_data_source, 1)
                    curr_pathname = app.movie_data.params.train_data_source{jj};
                    app.movie_data.results.FeatureScaledData.source_file{jj, 1} = curr_pathname;
                    
                    %load the next datafile
                    data = load(curr_pathname);
                    
                    %find the col indices for the new data based on file's column titles
                    feature_cols = zeros(1, numel(app.movie_data.models.temp_params.feature_names));
                    for kk = 1:numel(app.movie_data.models.temp_params.feature_names)
                        feature_cols(kk) = findColumnIdx(data.movie_data.params.column_titles.tracks, app.movie_data.models.temp_params.feature_names{kk});
                    end
                    
                    %if the columns all exist, remove irrelevant feature columns from imported data, and append
                    if any(feature_cols == 0)
                        success = false;
                        warning('The required data fields are missing in file: %s', curr_pathname);
                        h_warn = warndlg("File " + curr_pathname + " could not be loaded or does not contain suitable features. Loading will continue with other datasets.", "Unable to load annotations from file.");
                        uiwait(h_warn);
                    else                                
                        %generate new cell array containing only feature cols and labels
                        new_mols = cell(size(data.movie_data.results.GroundTruth.LabelledMols));
                        for kk = 1:size(data.movie_data.results.GroundTruth.LabelledMols, 1)
                            cols_to_keep                = [feature_cols, size(data.movie_data.results.GroundTruth.LabelledMols{kk, 1}.Mol, 2)];
                            new_mols{kk, 1}.Mol         = data.movie_data.results.GroundTruth.LabelledMols{kk, 1}.Mol(:, cols_to_keep);
                            new_mols{kk, 1}.CellID      = data.movie_data.results.GroundTruth.LabelledMols{kk, 1}.CellID;
                            new_mols{kk, 1}.MolID       = data.movie_data.results.GroundTruth.LabelledMols{kk, 1}.MolID;
                            new_mols{kk, 1}.source_data = jj;
                        end
                        
                        %append imported data to FeatureScaledData
                        app.movie_data.results.FeatureScaledData.LabelledMols = [app.movie_data.results.FeatureScaledData.LabelledMols; new_mols];
                    end
                end
            end
            
        otherwise
            app.textout.Value = "The training dataset is not currently available";
            success = false;
            return;
    end
    
    %check data exists
    if isempty(app.movie_data.results.FeatureScaledData.LabelledMols)
        success = false;
        warndlg("Error in rescaling features; exiting");
        return;
    end
    
    %write the souce files to the temp params struct for future access
    app.movie_data.models.temp_params.source_file = app.movie_data.results.FeatureScaledData.source_file;
    
    %erase any trajectories from scaled data that have not been fully labelled
    del_idx = [];
    for jj = 1:size(app.movie_data.results.FeatureScaledData.LabelledMols, 1)
        if any(app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol(:, end) == -1)
            del_idx = [del_idx, jj];
        end
    end
    app.movie_data.results.FeatureScaledData.LabelledMols(del_idx) = [];
    
    %crop trajectories to ensure all features contain viable information
    cropTrajectories(app, "feature_scaled", app.IgnorerowsfromstartSpinner.Value, app.IgnorerowsfromendSpinner.Value);
    
    switch method
        case "None"
            % << placeholder >>
            
        case "Z-score"
            %Z-score feature scaling of relevant features
            
            %compute global mean and stdev for each feature
            N_mols = size(app.movie_data.results.FeatureScaledData.LabelledMols,1);
            all_data = cell(N_mols, 1);
            for jj = 1:N_mols
                all_data{jj} = app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol(:, 1:end-1);
            end
            all_data = vertcat(all_data{:});
            
            %keep track of feature scaling variables used
            app.movie_data.models.temp_params.feature_means = mean(all_data);
            app.movie_data.models.temp_params.feature_stds  = std(all_data);
            
            %standardize each feature in each matrix using Z-score
            for jj = 1:N_mols
                for col = 1:length(app.movie_data.models.temp_params.feature_cols)
                    original_data       = app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol(:, col);
                    standardized_data   = (original_data - app.movie_data.models.temp_params.feature_means(col)) / app.movie_data.models.temp_params.feature_stds(col);
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol(:, col) = standardized_data;
                end
            end
            success = true;
            
        case "Normalise (0-1)"
            %standard linear min-max normalisation (0-1)
            
            %compute global min and max for each feature
            N_mols = size(app.movie_data.results.FeatureScaledData.LabelledMols,1);
            all_data = cell(N_mols, 1);
            for jj = 1:N_mols
                all_data{jj} = app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol(:, 1:end-1);
            end
            all_data = vertcat(all_data{:});
            app.movie_data.models.temp_params.feature_mins = min(all_data);
            app.movie_data.models.temp_params.feature_maxs = max(all_data);
            
            %normalize each feature in each matrix using min-max scaling
            for jj = 1:N_mols
                for col = 1:length(app.movie_data.models.temp_params.feature_cols)
                    original_data   = app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol(:, col);
                    normalized_data = (original_data - app.movie_data.models.temp_params.feature_mins(col)) / (app.movie_data.models.temp_params.feature_maxs(col) - app.movie_data.models.temp_params.feature_mins(col));
                    app.movie_data.results.FeatureScaledData.LabelledMols{jj, 1}.Mol(:, col) = normalized_data;
                end
            end
            
            success = true;
            
        otherwise
            
    end
end


function [valid] = checkTrainingDataValid(app, expected_features, expected_col_idx, data)
%Check whether a loaded training dataset is valid, Oliver Pambos,
%07/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: checkTrainingDataValid
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
%Note that this is a legacy function from a previous implementation of
%scaleLabelledFeatures.m
%
%After user loads a file containing pre-annotated data as the struct data,
%this function performs the following checks to ensure that it contains
%valid data,
%   1. Labelled data struct exists
%   2. The expected feature names (column titles) match exactly the
%       expected list
%   3. The number of columns in the tracks matrices match the number of
%       feature columns
%
%Input
%-----
%app        (handle)    main GUI handle
%
%Output
%------
%valid      (bool)      determines whether the current loaded data is valid
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %bool test array
    test = [false, false, false];
    
    %check the struct is correct
    if isfield(data, 'movie_data') && isfield(data.movie_data, 'results') && isfield(data.movie_data.results, 'VisuallyLabelled') && isfield(data.movie_data.results.VisuallyLabelled, 'LabelledMols')
        test(1) = true;
    else
        valid = false;
        return;
    end
    
    %check the features for training are in the correct columns; if they're wrong but exist then reorder the key columns only to be correct
    col_idx = zeros(1, size(app.movie_data.models.temp_params.feature_names, 2));
    for ii = 1:size(app.movie_data.models.temp_params.feature_names, 2)
        col_idx(ii) = findColumnIdx(data.movie_data.params.column_titles.tracks, expected_features(ii));
    end
    if all(col_idx ~= 0) && all(col_idx == expected_col_idx)
        test(2) = true;
    else
        %test failed, now check if the key features exist, if so re-order; else completely fail
        if all(col_idx ~= 0)
            data = repairFeatureOrder(data, col_idx, expected_col_idx);
            test(2) = true;
        else
            valid = false;
            return;
        end
    end
    
    %check that every tracks matrix in the loaded data contains enough
    %columns (very rough check of integrity); <= used here instead of < due
    %to additional column for the labels
    test(3) = true;
    for ii = 1:size(data.movie_data.results.VisuallyLabelled.LabelledMols, 1)
        if size(data.movie_data.results.VisuallyLabelled.LabelledMols{ii, 1}.Mol, 2) <= max(expected_col_idx)
            test(3) = false;
            break;
        end
    end
    
    %check if struct passes all of the tests
    if all(test)
        valid = true;
    else
        valid = false;
    end
end


function [data] = repairFeatureOrder(data, col_idx, expected_col_idx)
%If correct features exist in loaded datafiles, but columns vary, fix this
%through column manipulation, Oliver Pambos, 07/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: attemptStructRepair
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
%Note that this is a legacy function from a previous implementation of
%scaleLabelledFeatures.m
%
%This function handles difficult scenarios where previous training has been
%performed with the correct features, but these are in a different order.
%This function attempts to reorder the relevant columns in the all tracks
%matrices across entire annotated dataset to ensure that the key features
%columns that are required for training are positioned correctly within the
%struct.
%
%IMPORTANT: this the result of this function often leaves column/features
%that are not used for training in orders that no longer match the column
%titles. For this reason the entirety of FeatureScaledData is wiped at the
%end of GeneratetrainingsetButtonPushed().
%
%The function intension leaves all features not used for downstream ML
%training as zeros. It does however crucially move over the labels.
%Performance here could clearly be optimised, but this is not pressing.
%
%
%Input
%-----
%data       (mat)   data file that was loaded
%col_idx    (vec)   column indices
%
%Output
%------
%valid      (bool)      determines whether the current loaded data is valid
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    for ii = 1:size(data.movie_data.results.VisuallyLabelled.LabelledMols, 1)
        new_mat = zeros(size(data.movie_data.results.VisuallyLabelled.LabelledMols{ii, 1}.Mol));
        new_mat(:, expected_col_idx) = data.movie_data.results.VisuallyLabelled.LabelledMols{ii, 1}.Mol(:, col_idx);
        new_mat(:, end) = data.movie_data.results.VisuallyLabelled.LabelledMols{ii, 1}.Mol(:, end);
        data.movie_data.results.VisuallyLabelled.LabelledMols{ii, 1}.Mol = new_mat;
    end
end