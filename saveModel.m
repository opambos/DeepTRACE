function [] = saveModel(app)
%Save a trained model, Oliver Pambos, 30/03/2025.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcModelSize
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
%This function originates from an older implementation in the private
%methods of the main GUI class (.mlapp). It has been moved to this .m file
%to provide access to scopes outside the existing GUI callbacks. This
%restructuring was necessary to resolve a bug in which the user was
%prompted to save a model after cancelling the model construction process.
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
    
    %open save dialog
    app.textout.Value    = "Please select a file name and location to save the trained model.";
    [filename, pathname] = uiputfile({'*.mat', 'Save trained model (*.mat)'}, 'Save trained model as');
    
    %check if the user pressed 'Cancel'
    if isequal(filename, 0) || isequal(pathname, 0)
        app.textout.Value = "User pressed cancel";
    else
        full_filepath = fullfile(pathname, filename);
    
        %create a struct containing the model and its metadata
        switch app.movie_data.models.current_model
            case "RF"
                model_data = struct('model', app.movie_data.models.RF);
            case "GRU"
                model_data = struct('model', app.movie_data.models.GRU);
            case "BiGRU"
                model_data = struct('model', app.movie_data.models.BiGRU);
            case "LSTM"
                model_data = struct('model', app.movie_data.models.LSTM);
            case "BiLSTM"
                model_data = struct('model', app.movie_data.models.BiLSTM);
            otherwise
            
        end
        
        %save the struct to the file
        try
            save(full_filepath, 'model_data');
            app.textout.Value = app.movie_data.models.current_model + " model saved to " + full_filepath;
        catch ME
            app.textout.Value = "Failed to save model data: " + ME.message;
        end
    end
end