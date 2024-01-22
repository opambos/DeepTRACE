function [] = cropTrajectories(app, dataset, ignore_start, ignore_end)
%Crop trajectories to ensure only valid data from all selected features is
%retained, Oliver Pambos, 13/01/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: cropTrajectories
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
%There are many known features that may not be available at the start or
%end of a trajectory. For example, the feature 'step size' represents the
%Euclidean distance between localisations and therefore contains no
%information encoded in the first frame; the first row of every trajectory
%is therefore ignored from both the training and later classified data.
%Similarly, the feature 'following step size' will have an empty entry at
%the end of the trajectory. Inluding these features would severely
%complicate training. I have previously attemped other approaches to this
%problem, including imputation. This function however simply crops these
%regions from the dataset althogether.
%
%These rows which interfere with the ML model are identified earlier in the
%analysis procedure during a call to identifyExcludedSteps, and are
%optionally overridden by the user. These identified rows are removed by
%this function immediately prior to training. This function also stores in
%the models.temp_params substruct a two-element row vector which records
%the number of rows cropped from the start and end of the trajectories
%during training. This information is written to the ML temp_params struct
%to be subsequently stored with the trained model when saving to file.
%
%Input
%-----
%app            (handle)    main GUI handle
%removed_rows   (vec)       row vector containing which rows to remove
%dataset        (str)       which dataset to crop
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    switch dataset
        case "feature_scaled"
            %remove the relevant rows
            for ii = 1:numel(app.movie_data.results.FeatureScaledData.LabelledMols)
                app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol = app.movie_data.results.FeatureScaledData.LabelledMols{ii, 1}.Mol(ignore_start+1 : end-ignore_end, :);
            end

        case "GRU_labelled"
            %remove the relevant rows
            for ii = 1:numel(app.movie_data.results.GRULabelled.LabelledMols)
                app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol = app.movie_data.results.GRULabelled.LabelledMols{ii, 1}.Mol(ignore_start+1 : end-ignore_end, :);
            end

        case "LSTM_labelled"
            %remove the relevant rows
            for ii = 1:numel(app.movie_data.results.LSTMLabelled.LabelledMols)
                app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol = app.movie_data.results.LSTMLabelled.LabelledMols{ii, 1}.Mol(ignore_start+1 : end-ignore_end, :);
            end
            
        otherwise

    end
    
    %keep a record of this operation with the trained model
    app.movie_data.models.temp_params.removed_rows = [ignore_start ignore_end];
end