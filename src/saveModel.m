function [] = saveModel(app)
%Save a trained model, 30/03/2025.
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