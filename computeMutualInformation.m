function [] = computeMutualInformation(app, method)
%Compute mutual information between each feature and assigned class, and
%between feature pairs, Oliver Pambos, 12/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeMutualInformation
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
%This function computes the mutual information between all requested
%feature pairs, and the mutual information between each requested feature
%and the known class. When computing MI for feature vs class, it is able to
%compute the scores for all data, as well as restricted to
%changepoint-proximal and changepoint-distal regions. For the latter, it
%visualises the scores with an hbar plot for both masked regions
%simultaneously. For all feature vs class results the feature are ranked in
%decending order of MI score. For the masked scores the ranking is
%performed as the sum of the scores in proximal and distal regions. All
%requested feature pair scores are displayed as a heatmap.
%
%This function is able to operate on the currently-loaded file, or on
%combinations of external files and internal data. It is able to use either
%the loaded ground truth or human annotations for class comparisons where
%required.
%
%Due to the extremely varied distributions produced by all features, and
%the unknown distribution of arbitrary features that may be provided by the
%user, adaptive binning is used to space bin edges non-linearly to ensure
%the data is well sampled even in cases for example in which a feature
%contains an extremely long-tailed distribution. The number of bins is
%hardcoded to 25, such a bin typically contains ~4% of data for the
%feature; this was found to work well with the type of data present in SMLM
%tracking data experiments.
%
%Inputs
%------
%app    (handle)    main GUI handle
%method (str)       determines whether to perform feature ranking via MI or
%                       to compute MI between feature pairs, options are,
%                           'pairwise': compute MI between all requested
%                               feature pairs
%                           'ranked': rank features by mutual information
%                               with known class for each localisation
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%concatTracks()                     - local to this .m file
%splitCPRegions()                   - local to this .m file
%computeMIScoresFeatureVsClass()    - local to this .m file
%plotMIRanked()                     - local to this .m file
%plotMIScoresProximalDistal()       - local to this .m file
%calcMutualInfoFeatureVsClass()     - local to this .m file
%computeFeaturePairwiseMI()         - local to this .m file
%plotPairwiseMIHeatmap()            - local to this .m file
    
    %bins used to discretise data
    N_bins = 25;
    cp_range = app.FeatureImportanceChangepointmasksizeSpinner.Value;
    
    %obtain list of features to use
    switch app.FeatureImportanceFeaturesubsetDropDown.Value
        case "All features"
            feature_list = app.movie_data.params.column_titles.tracks(:, 1:end-1);
        case "Selected features"
            feature_list = app.MLfeatures.CheckedNodes;
            if isempty(feature_list)
                app.textout.Value = "You have not selected any features! Please select features to analyze from the [Features] list.";
                warndlg("You have not selected any features! Please select features to analyze from the [Features] list.", "No features selected!");
                return;
            end
            feature_list = {feature_list.Text};
        otherwise
            app.textout.Value = "Invalid option selected in [Feature subset] dropdown. Please select either 'All features' or 'Selected features'.";
            warndlg("Invalid option selected in [Feature subset] dropdown. Please select either 'All features' or 'Selected features'.", "Invalid selection!");
            return;
    end
    
    %get source data
    switch app.FeatureImportanceSourcedataDropDown.Value
        case "Ground truth"
            track_data = app.movie_data.results.GroundTruth.LabelledMols;
        case "Human annotations"
            track_data = app.movie_data.results.VisuallyLabelled.LabelledMols;
        case "Human annotations (multiple experiments)"
            track_data = loadAndCombineTracks(app, "VisuallyLabelled");
        case "Ground truth (multiple simulations)"
            track_data = loadAndCombineTracks(app, "GroundTruth");
        otherwise
            app.textout.Value = "The selected dataset is invalid or unavailable.";
            warndlg("The selected dataset is invalid or unavailable.", "No data available!");
            return;
    end
    if isempty(track_data)
        app.textout.Value = "The selected dataset contains no annotated data. Please load the appropriate file or perform human annotation.";
        warndlg("The selected dataset contains no annotated data. Please load the appropriate file or perform human annotation.", "No annotated data!");
        return;
    end
    
    [feature_data, class_data] = concatTracks(track_data);
    
    switch method
        case 'ranked'
            %separate changepoint-proximal and distal data
            [feature_data_cp, class_data_cp, feature_data_distal, class_data_distal] = splitCPRegions(track_data, cp_range);
            
            %compute MI for all data, changepoint-proximal and distal data
            MI_scores_all_data  = computeMIScoresFeatureVsClass(feature_data, class_data, feature_list, app.movie_data.params.column_titles.tracks, N_bins);
            MI_scores_cp        = computeMIScoresFeatureVsClass(feature_data_cp, class_data_cp, feature_list, app.movie_data.params.column_titles.tracks, N_bins);
            MI_scores_distal    = computeMIScoresFeatureVsClass(feature_data_distal, class_data_distal, feature_list, app.movie_data.params.column_titles.tracks, N_bins);
            
            %plot MI for all data
            plotMIRanked(feature_list, MI_scores_all_data);
            
            %plot changepoint-proximal and distal MI scores
            plotMIScoresProximalDistal(feature_list, MI_scores_cp, MI_scores_distal);
        
        case 'pairwise'
            %compute and plot pairwise MI between features
            computeFeaturePairwiseMI(feature_data, feature_list, app.movie_data.params.column_titles.tracks, N_bins);
            
        otherwise
            return;
    end
end


function [feature_data, class_data] = concatTracks(track_data)
%Concatenate all tracks into a single matrix, Oliver Pambos, 12/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: concatTracks
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
%This function is extremely inefficient, and needs to be reworked with
%pre-allocation.
%
%Inputs
%------
%track_data (cell)  cell array of tracks, where each cell contains a struct
%                       with a matrix named '.Mol' of dimensions Ax(B+1)
%                       where A is the number of localisations and B is the
%                       number of features; the final column containing the
%                       assigned class ID
%
%Output
%------
%feature_data       (mat)   NxM matrix of all all feature data from all
%                               tracks concatenated into a single matrix
%class_data         (vec)   Nx1 column vector of all class IDs associated
%                               with feature data in combined_features from
%                               all tracks in the dataset
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    feature_data    = [];
    class_data      = [];
    
    for ii = 1:numel(track_data)
        curr_track      = track_data{ii, 1}.Mol;
        feature_data    = [feature_data; curr_track(:, 1:end-1)];
        class_data      = [class_data; curr_track(:, end)];
    end
end


function [feature_data_proximal, class_data_proximal, feature_data_distal, class_data_distal] = splitCPRegions(track_data, cp_range)
%Split tracks into changepoint-proximal and changepoint-distal regions, and
%return as concatenated matrices, Oliver Pambos, 12/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: splitCPRegions
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
%This function is extremely inefficient, and needs to be replaced with
%pre-allocation.
%
%Inputs
%------
%track_data (cell)  cell array of tracks, where each cell contains a struct
%                       with a matrix named '.Mol' of dimensions Ax(B+1)
%                       where A is the number of localisations and B is the
%                       number of features; the final column containing the
%                       assigned class ID
%cp_range   (int)   number of localisations before and after each
%                       changepoint to use to construct the changepoint
%                       proximal mask.
%
%Output
%------
%feature_data_proximal        (mat)   NxM matrix of all tracked localisations in
%                               changepoint-proximal regions, where N is
%                               the number of localistions, and M is the
%                               number of features
%class_data_proximal         (vec)   Nx1 column vector of class IDs for all
%                               changepoint-proximal localisations
%feature_data_distal    (mat)   NxM matrix of all tracked localisations in
%                               changepoint-distal regions, where N is
%                               the number of localistions, and M is the
%                               number of features
%class_data_distal     (vec)   Nx1 column vector of class IDs for all
%                               changepoint-distal localisations
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    feature_data_proximal     = [];
    class_data_proximal      = [];
    feature_data_distal = [];
    class_data_distal  = [];
    
    %loop over all tracks
    for ii = 1:numel(track_data)
        curr_track      = track_data{ii, 1}.Mol;
        feature_data    = curr_track(:, 1:end-1);
        class_data      = curr_track(:, end);
        
        %construct changepoint-proximal and distal masks using diff
        changepoints    = find(diff(class_data) ~= 0);
        cp_mask         = false(size(class_data));
        for idx = changepoints'
            range = max(1, idx - cp_range + 1) : min(length(class_data), idx + cp_range);
            cp_mask(range) = true;
        end
        distal_mask = ~cp_mask;
        
        %concat changepoint-proximal, and changepoint-distal from current track, onto global data
        feature_data_proximal   = [feature_data_proximal; feature_data(cp_mask, :)];
        class_data_proximal     = [class_data_proximal; class_data(cp_mask)];
        feature_data_distal     = [feature_data_distal; feature_data(distal_mask, :)];
        class_data_distal       = [class_data_distal; class_data(distal_mask)];
    end
end


function [MI_scores] = computeMIScoresFeatureVsClass(feature_data, class_data, feature_list, column_titles, N_bins)
%Compute mutual information scores between features and classes, Oliver
%Pambos, 12/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeMIScoresFeatureVsClass
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
%Inputs
%------
%feature_data   (mat)   concatenated NxM matrix of all data in dataset,
%                           where N is the number of localisations, and M
%                           is the number of features (including those not
%                           used)
%class_data     (vec)   column vector with N entries, holds the known class
%                           for each entry in feature_data
%feature_list   (cell)  cell array of char arrays, where each cell contains
%                           the name of a feature selected by the user
%column_titles  (cell)  cell array of char arrays, containing the column
%                           titles for all features in dataset; used for
%                           lookup of column number
%N_bins         (int)   number of bins to use in discretising features
%
%Output
%------
%MI_scores      (vec)   vector containing mutual information between the
%                           known classes and the features in feature_list
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findColumnIdx()
%calcMutualInfoFeatureVsClass() - local to this .m file
    
    %pre-allocate
    MI_scores = zeros(1, numel(feature_list));
    
    %loop over features, computing MI scores
    for ii = 1:numel(feature_list)
        %obtain data for feature
        feature_idx         = findColumnIdx(column_titles, feature_list{ii});
        curr_feature_data   = feature_data(:, feature_idx);
        
        %compute MI between the feature and the class labels
        MI_scores(ii) = calcMutualInfoFeatureVsClass(curr_feature_data, class_data, N_bins);
    end
end


function [] = plotMIRanked(feature_list, MI_scores)
%Display features ranked by mutual information with class score, Oliver
%Pambos, 12/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotMIRanked
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
%Inputs
%------
%feature_list   (cell)  cell array of char arrays, where each cell contains
%                           the name of a feature selected by the user
%MI_scores      (vec)   vector containing mutual information between the
%                           known classes and the features in feature_list
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %rank features
    [sorted_scores, sorted_idx] = sort(MI_scores, 'descend');
    ranked_features             = feature_list(sorted_idx);
    y_positions                 = 1:numel(ranked_features);
    
    %display horizontal bar chart of ranking
    figure('Name', 'Feature importance ranked by mutual information', 'Color', 'w');
    barh(y_positions, sorted_scores, 'FaceColor', [0.3, 0.7, 0.9]);
    set(gca, 'YDir', 'reverse');    %reverse y-axis; best features at top
    yticks(y_positions);
    yticklabels({});                %suppress tick labels
    xlabel('Mutual Information');
    title('Feature importance ranked by feature-class mutual information across full dataset');
    xlim([0, max(sorted_scores) * 1.1]);
    set(gca, 'FontSize', 16);
    
    %display feature names as text annotations over data
    x_offset = 0.02 * max(sorted_scores);   %move away from y-axis
    for ii = 1:numel(ranked_features)
        text(x_offset, y_positions(ii), ranked_features{ii}, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Color', 'k', 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
    end
end


function [] = plotMIScoresProximalDistal(feature_list, MI_scores_proximal, MI_scores_distal)
%Plots the mutual information shared between each feature and known classes
%in changepoint proximal and changpoint distal regions on the same plot,
%Oliver Pambos, 12/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotMIScoresProximalDistal
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
%This function plots the MI feature-class scores on the same plot, with
%changepoint-proximal going negative, and changepoint-distal positive. The
%features are ranked by the sum of their proximal and distal scores.
%
%Inputs
%------
%feature_list       (cell)  cell array of char arrays, where each cell
%                               contains the name of a feature selected by
%                               the user
%MI_scores_proximal (vec)   vector containing mutual information score
%                               between features and known classes in
%                               changepoint-proximal regions
%MI_scores_distal   (vec)   vector containing mutual information score
%                               between features and known classes in
%                               changepoint-distal regions
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %combine changepoint-proximal and distal MI scores, then rank by total
    [~, sorted_idx] = sort(MI_scores_proximal + MI_scores_distal, 'descend');
    ranked_features = feature_list(sorted_idx);
    
    %combine scores with proximal as negative and distal as positive
    combined_scores = [MI_scores_proximal(sorted_idx) * -1; MI_scores_distal(sorted_idx)]';
    
    %display ranked results
    figure('Name', 'MI scores in changepoint-proximal and changepoint-distal regions', 'Color', 'w');
    barh(categorical(ranked_features, ranked_features), combined_scores, 'stacked');
    set(gca, 'YDir', 'reverse');    %invert y-axis to rank highest features at top
    xlabel('Feature-class mutual information');
    ylabel('Features');
    title('Mutual information shared between features and classes');
    legend({'Changepoint-proximal', 'Changepoint-distal'}, 'Location', 'best');
    set(gca, 'FontSize', 16);
end


function [MI] = calcMutualInfoFeatureVsClass(feature_data, class_data, N_bins)
%Compute mutual information between a feature and the known class labels,
%Oliver Pambos, 12/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcMutualInfoFeatureVsClass
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
%MI is calculate by constructing joint_prob, a 2D matrix in which each row
%is a bin in the binned feature data, and each column is a class.
%
%Note that in the case of computing a subset of features, the feature list
%and associated feature_data matrix have already been cropped to include
%only these features.
%
%Inputs
%------
%feature_data   (mat)   concatenated NxM matrix of the subset of M features
%                           to be computed; N is number of localisations;
%                           this matrix is concatenated from all tracks
%class_data     (vec)   column vector with N entries, holds the known class
%                           for each entry in feature_data
%N_bins         (int)   number of bins to use in discretising features
%
%Output
%------
%MI_scores      (vec)   vector containing mutual information between the
%                           known classes and the features supplied as
%                           columns in feature_data
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %bin feature data
    bin_edges           = unique(quantile(feature_data, linspace(0, 1, N_bins + 1)));
    discrete_feature    = discretize(feature_data, bin_edges);
    
    %compute joint and marginal probabilities - see notes in header
    joint_prob      = histcounts2(discrete_feature, class_data, (1:N_bins + 1) - 0.5, (min(class_data):max(class_data) + 1) - 0.5, 'Normalization', 'probability');
    prob_feature    = sum(joint_prob, 2);
    prob_class      = sum(joint_prob, 1);
    
    %compute mutual information
    MI = 0;
    for ii = 1:N_bins
        for jj = 1:numel(prob_class)
            if joint_prob(ii, jj) > 0
                MI = MI + joint_prob(ii, jj) * log2(joint_prob(ii, jj) / (prob_feature(ii) * prob_class(jj)));
            end
        end
    end
end


function [] = computeFeaturePairwiseMI(feature_data, feature_list, feature_names, N_bins)
%Compute pairwise mutual information between all requested features, Oliver
%Pambos, 14/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeFeaturePairwiseMI
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
%Note that this f'n also currently plots the pairwise feature heatmap by
%calling the plotting function plotPairwiseMIHeatmap().
%
%Inputs
%------
%feature_data   (mat)   concatenated NxM matrix of the subset of M
%                               features to be computed; N is number of
%                               localisations; this matrix is concatenated
%                               from all tracks
%feature_list   (cell)  cell array of char arrays, where each cell contains
%                               the name of a feature selected by the user
%feature_names  (cell)  cell array of char arrays, containing the
%                               complete list of feature names in the
%                               source data
%N_bins         (int)   number of bins to use in discretising features
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%plotPairwiseMIHeatmap()    - local to this .m file
    
    if isempty(feature_list) || isempty(feature_data)
        error('Feature list or combined features matrix is empty.');
    end
    
    N_features  = numel(feature_list);
    MI_matrix   = zeros(N_features, N_features);
    
    %bin all features into cell array
    discrete_features = cell(1, N_features);
    for ii = 1:N_features
        feature_idx = findColumnIdx(feature_names, feature_list{ii});
        if isempty(feature_idx)
            error('Feature "%s" not found in feature_names.', feature_list{ii});
        end
        curr_feature_data = feature_data(:, feature_idx);
        bin_edges = unique(quantile(curr_feature_data, linspace(0, 1, N_bins + 1)));
        discrete_features{ii} = discretize(curr_feature_data, bin_edges);
    end
    
    %compute MI score for each feature pair
    for ii = 1:N_features
        %compute only upper triangle (matrix is symmetric)
        for jj = ii:N_features
            discrete_feature_1 = discrete_features{ii};
            discrete_feature_2 = discrete_features{jj};
            
            %joint and marginal probs
            joint_prob = histcounts2(discrete_feature_1, discrete_feature_2, ...
                                     (1:N_bins + 1) - 0.5, ...
                                     (1:N_bins + 1) - 0.5, ...
                                     'Normalization', 'probability');
            prob_feature_1 = sum(joint_prob, 2);
            prob_feature_2 = sum(joint_prob, 1);
            
            %compute MI score
            MI = 0;
            for k = 1:N_bins
                for l = 1:N_bins
                    if joint_prob(k, l) > 0
                        MI = MI + joint_prob(k, l) * log2(joint_prob(k, l) / (prob_feature_1(k) * prob_feature_2(l)));
                    end
                end
            end
            
            %store result
            MI_matrix(ii, jj) = MI;
            MI_matrix(jj, ii) = MI; %symmetric value
        end
    end
    
    %plot heatmap
    plotPairwiseMIHeatmap(MI_matrix, feature_list);
end


function [] = plotPairwiseMIHeatmap(MI_mat, feature_list)
%Plot heatmap of all pairwise mutual information between all requested
%features, Oliver Pambos, 14/12/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotPairwiseMIHeatmap
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
%Inputs
%------
%MI_mat         (mat)   square matrix of size N, where N is the number of
%                           features; each element contains the mutual
%                           information score for the feature pair
%feature_list   (cell)  cell array of char arrays, where each cell
%                           contains the name of a feature associated with
%                           the coloumn and row entries of MI_mat
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    figure('Name', 'Pairwise feature mutual information heatmap', 'Color', 'w');
    h_heatmap = heatmap(feature_list, feature_list, MI_mat);
    h_heatmap.ColorLimits = [0, max(MI_mat(:))];
    h_heatmap.FontSize = 16;
    h_heatmap.Title = 'Pairwise mutual information heatmap for all features';
end