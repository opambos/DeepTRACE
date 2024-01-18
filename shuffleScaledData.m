function [] = shuffleScaledData(app)
%Shuffle the feature-scaled data, Oliver Pambos, 28/04/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: shuffleScaledData
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
%Shuffles the feature-scaled data prior to splitting the training data into
%training, validation, and test sets. This approach varies depending upon
%the type of model that this will be used to train. For ensemble decision
%trees where individual steps are considered as independent examples the
%trajectories are concatenated into a single matrix prior to shuffling and
%splitting; this is possible becauase the temporal information is encoded
%in new features; this method is the localisation-wise shuffling.
%For all other models the temporal information in each molecular trajectory
%is handled natively by the model, and shuffling is performed
%molecule-by-molecule.
%
%Note that the option to knock out zeros was used earlier in development,
%and is now redundant, to be removed in a future version.
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
%compileLabelledData()
%splitData()
    
    %get the user-selected method for feature scaling used to train model, and record in model params
    method = app.ShufflingmethodDropDown.Value;
    app.movie_data.models.temp_params.shuffling = method;
    
    switch method
        case "Localisation"
            %shuffle data localisation-wise; this is used for training ensemble decision trees
            
            %pre-allocation required in future version
            concat_data = [];
            
            %loop over all molecules in file
            for ii = 1:size(app.movie_data.results.FeatureScaledData.LabelledMols, 1)
                
                %concatenate all molecules that have a classification label for every localisation
                if ~any(app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(:,end) == -1)
                    mol = app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol;
                    concat_data = cat(1, concat_data, mol);
                end
                
            end
            
            %if user requests, remove any rows with zeros in any of the feature columns; this now redundant, and will be removed in a future version
            if app.KnockoutzerosCheckBox.Value
                rows_to_remove = any(concat_data(:, 1:end-1) == 0, 2);
                concat_data(rows_to_remove, :) = [];
                app.movie_data.models.temp_params.knocked_out = 0;  %keep track of values knocked out of dataset
            end
            
            %perform shuffle
            N_examples      = size(concat_data, 1);
            permuted_idx    = randperm(N_examples);
            app.movie_data.results.labelled_data = concat_data(permuted_idx, :);
            
        case "Molecule"
            %shuffle data molecule-by-molecule; this is used to train more complex models such as neural nets that natively handle temporal dependencies
            
            N_mol = size(app.movie_data.results.FeatureScaledData.LabelledMols, 1); 
            
            %shuffle
            random_order = randperm(N_mol); 
            shuffled_matrices = cell(N_mol, 1); 
            
            %loop through matrices, reorder, then overwrite original mols with shuffled mols
            for ii = 1:N_mol
                shuffled_matrices{ii, 1} = app.movie_data.results.FeatureScaledData.LabelledMols{random_order(ii), 1};
            end
            app.movie_data.results.FeatureScaledData.LabelledMols = shuffled_matrices;
            
        otherwise

    end
    
end

