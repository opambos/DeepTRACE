function [] = scaleLabelledFeatures(app)
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
%This function scales user-selected features in the human labelled data
%(VisuallyLabelled substruct), and saves this to a new substruct
%(FeatureScaledData). This function is called during the process of
%generating training datasets for ML models. To ensure seemless future
%classification using these models on unseen datasets, the parameters used
%(e.g. mean and standard deviation in the case of Z-score) are saved
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
%cropTrajectories()
    
    %compile a list of features selected by the user (format is column IDs)
    app.movie_data.models.temp_params.feature_cols = [];
    for ii = 1:size(app.MLfeatures.CheckedNodes,1)
        feature_name = app.MLfeatures.CheckedNodes(ii).Text;
        a = strcmp(string(app.movie_data.params.column_titles.tracks), feature_name);
        app.movie_data.models.temp_params.feature_cols = [app.movie_data.models.temp_params.feature_cols find(a,1)];
        
        %keep track of column titles of ref data for plotting
        app.movie_data.models.temp_params.feature_names{ii} = feature_name;
    end
    
    %get the user-selected method for feature scaling used to train model, and record in model params
    method = app.FeaturescalingDropDown.Value;
    app.movie_data.models.temp_params.feature_scaling = method;
    
    %copy over all of the manually labelled data
    app.movie_data.results.FeatureScaledData = app.movie_data.results.VisuallyLabelled;

    %erase any trajectories from scaled data that have not been fully labelled
    del_idx = [];
    for ii = 1:size(app.movie_data.results.FeatureScaledData.LabelledMols, 1)
        if any(app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:, end) == -1)
            del_idx = [del_idx, ii];
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
            for ii = 1:N_mols
                all_data{ii} = app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:, app.movie_data.models.temp_params.feature_cols);
            end
            all_data = vertcat(all_data{:});
            
            %keep track of feature scaling variables used
            app.movie_data.models.temp_params.feature_means = mean(all_data);
            app.movie_data.models.temp_params.feature_stds  = std(all_data);
            
            %standardize each feature in each matrix using Z-score
            for ii = 1:N_mols
                for col = 1:length(app.movie_data.models.temp_params.feature_cols)
                    feature_col         = app.movie_data.models.temp_params.feature_cols(col);
                    original_data       = app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:, feature_col);
                    standardized_data   = (original_data - app.movie_data.models.temp_params.feature_means(col)) / app.movie_data.models.temp_params.feature_stds(col);
                    app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:, feature_col) = standardized_data;
                end
            end
            
        case "Normalise (0-1)"
            %standard linear min-max normalisation (0-1)
            
            %compute global min and max for each feature
            N_mols = length(app.movie_data.results.FeatureScaledData.LabelledMols);
            all_data = cell(N_mols, 1);
            for ii = 1:N_mols
                all_data{ii} = app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:, app.movie_data.models.temp_params.feature_cols);
            end
            all_data = vertcat(all_data{:});
            app.movie_data.models.temp_params.feature_mins = min(all_data);
            app.movie_data.models.temp_params.feature_maxs = max(all_data);
            
            %normalize each feature in each matrix using min-max scaling
            for ii = 1:N_mols
                for col = 1:length(app.movie_data.models.temp_params.feature_cols)
                    feature_col     = app.movie_data.models.temp_params.feature_cols(col);
                    original_data   = app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:, feature_col);
                    normalized_data = (original_data - app.movie_data.models.temp_params.feature_mins(col)) / (app.movie_data.models.temp_params.feature_maxs(col) - app.movie_data.models.temp_params.feature_mins(col));
                    app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:, feature_col) = normalized_data;
                end
            end
            
        otherwise
            
    end
    
end