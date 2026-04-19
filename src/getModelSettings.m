function [] = getModelSettings(app)
%Generate a popup window to gather user input of model parameters,
%17/04/2023.
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
%This function enables direct modification of the parameters used to train
%the ML models from the GUI. This code requires significant refactoring to
%avoid repetition, to be completed in a near future update.
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
    
    switch app.ModeltypeDropDown.Value
        case "Random forest"
            
            prompt = {"Number of trees:", "Maximum depth of trees:", "Minimum leaf size:"};
            dlgtitle = "Random forest model parameters";
            dims = [1 35];
            if isfield(app.movie_data.models.temp_params, "N_trees")
                N_trees = app.movie_data.models.temp_params.N_trees;
            else
                N_trees = 50;   %default value
            end
            definput = {num2str(N_trees), 'Default', 'Default'};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            
            %check the user input is valid and assign
            if ~isempty(answer)
                N_trees = round(str2double(answer{1}));
                if isnan(N_trees) || N_trees <= 0
                    warndlg("Number of trees must be a positive integer. Keeping the previously used value.", "Input Error");
                else
                    app.movie_data.models.temp_params.N_trees = N_trees;
                end
            end
            
        case "Gradient boosted trees"

            prompt = {"Number of trees:", "Maximum depth of trees:", "Minimum leaf size:"};
            dlgtitle = "Random forest model parameters";
            dims = [1 35];
            if isfield(app.movie_data.models.temp_params, "N_trees")
                N_trees = app.movie_data.models.temp_params.N_trees;
            else
                N_trees = 50;   %default value
            end
            definput = {num2str(N_trees), 'Default', 'Default'};
            answer = inputdlg(prompt,dlgtitle,dims,definput);
            
            %check the user input is valid and assign
            if ~isempty(answer)
                N_trees = round(str2double(answer{1}));
                if isnan(N_trees) || N_trees <= 0
                    warndlg("Number of trees must be a positive integer. Keeping the previously used value.", "Input Error");
                else
                    app.movie_data.models.temp_params.N_trees = N_trees;
                end
            end

        case "Gated Recurrent Unit (GRU)"
            
            prompt = {"Number of units (Positive integer):", ...
                      "Max epochs (Positive integer):", ...
                      "Batch size (Positive integer):", ...
                      "Learning Rate (Positive float, e.g., 0.0001):", ...
                      "Dropout Rate (Float between 0 and 1, e.g., 0.5):", ...
                      "Input Weights L2 Factor (Non-negative float, e.g., 0.00001):", ...
                      "Recurrent Weights L2 Factor (Non-negative float, e.g., 0.00001):", ...
                      "Bias L2 Factor (Non-negative float, e.g., 0):"};
            dlgtitle = "Gated Recurrent Unit (GRU) model parameters";
            dims = [1 90];  %width of prompt window
            
            %set defaults
            definput = {'20', '5', '16', '0.0001', '0.5', '0.00001', '0.00001', '0'};
            
            %display dialog
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            
            %check and assign user inputs
            if ~isempty(answer)
                %convert to numerical values
                responses = cellfun(@str2double, answer);
                
                %validation checks for each parameter
                if isnan(responses(1)) || responses(1) <= 0 || mod(responses(1), 1) ~= 0
                    warndlg("Number of GRU units must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.N_units = responses(1);
                end
            
                if isnan(responses(2)) || responses(2) <= 0 || mod(responses(2), 1) ~= 0
                    warndlg("Max epochs must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.max_epochs = responses(2);
                end
            
                if isnan(responses(3)) || responses(3) <= 0 || mod(responses(3), 1) ~= 0
                    warndlg("Batch size must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.batch_size = responses(3);
                end
            
                if isnan(responses(4)) || responses(4) <= 0
                    warndlg("Learning rate must be a positive float.", "Input Error");
                else
                    app.movie_data.models.temp_params.learn_rate = responses(4);
                end
            
                if isnan(responses(5)) || responses(5) < 0 || responses(5) > 1
                    warndlg("Dropout rate must be a float between 0 and 1.", "Input Error");
                else
                    app.movie_data.models.temp_params.dropout_rate = responses(5);
                end
            
                if isnan(responses(6)) || responses(6) < 0
                    warndlg("Input weights L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.input_l2_factor = responses(6);
                end
            
                if isnan(responses(7)) || responses(7) < 0
                    warndlg("Recurrent weights L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.recurrent_l2_factor = responses(7);
                end
            
                if isnan(responses(8)) || responses(8) < 0
                    warndlg("Bias L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.bias_l2_factor = responses(8);
                end
            end
            
        case "Bidirectional Gated Recurrent Unit (BiGRU)"
            
            prompt = {"Number of units (Positive integer):", ...
                      "Max epochs (Positive integer):", ...
                      "Batch size (Positive integer):", ...
                      "Learning Rate (Positive float, e.g., 0.0001):", ...
                      "Dropout Rate (Float between 0 and 1, e.g., 0.5):", ...
                      "Input Weights L2 Factor (Non-negative float, e.g., 0.00001):", ...
                      "Recurrent Weights L2 Factor (Non-negative float, e.g., 0.00001):", ...
                      "Bias L2 Factor (Non-negative float, e.g., 0):"};
            dlgtitle = "Bidirectional Gated Recurrent Unit (BiGRU) model parameters";
            dims = [1 90];  %width of prompt window
            
            %set defaults
            definput = {'20', '5', '16', '0.0001', '0.5', '0.00001', '0.00001', '0'};
            
            %display dialog
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            
            %check and assign user inputs
            if ~isempty(answer)
                %convert to numerical values
                responses = cellfun(@str2double, answer);
                
                %validation checks for each parameter
                if isnan(responses(1)) || responses(1) <= 0 || mod(responses(1), 1) ~= 0
                    warndlg("Number of GRU units must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.N_units = responses(1);
                end
            
                if isnan(responses(2)) || responses(2) <= 0 || mod(responses(2), 1) ~= 0
                    warndlg("Max epochs must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.max_epochs = responses(2);
                end
            
                if isnan(responses(3)) || responses(3) <= 0 || mod(responses(3), 1) ~= 0
                    warndlg("Batch size must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.batch_size = responses(3);
                end
            
                if isnan(responses(4)) || responses(4) <= 0
                    warndlg("Learning rate must be a positive float.", "Input Error");
                else
                    app.movie_data.models.temp_params.learn_rate = responses(4);
                end
            
                if isnan(responses(5)) || responses(5) < 0 || responses(5) > 1
                    warndlg("Dropout rate must be a float between 0 and 1.", "Input Error");
                else
                    app.movie_data.models.temp_params.dropout_rate = responses(5);
                end
            
                if isnan(responses(6)) || responses(6) < 0
                    warndlg("Input weights L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.input_l2_factor = responses(6);
                end
            
                if isnan(responses(7)) || responses(7) < 0
                    warndlg("Recurrent weights L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.recurrent_l2_factor = responses(7);
                end
            
                if isnan(responses(8)) || responses(8) < 0
                    warndlg("Bias L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.bias_l2_factor = responses(8);
                end
            end

        case "Long Short-Term Memory (LSTM)"
            
            prompt = {"Number of units (Positive integer):", ...
                      "Max epochs (Positive integer):", ...
                      "Batch size (Positive integer):", ...
                      "Learning Rate (Positive float, e.g., 0.0001):", ...
                      "Dropout Rate (Float between 0 and 1, e.g., 0.5):", ...
                      "Input Weights L2 Factor (Non-negative float, e.g., 0.00001):", ...
                      "Recurrent Weights L2 Factor (Non-negative float, e.g., 0.00001):", ...
                      "Bias L2 Factor (Non-negative float, e.g., 0):"};
            dlgtitle = "Long Short-Term Memory (LSTM) model parameters";
            dims = [1 90];  %width of prompt window
            
            %set defaults
            definput = {'20', '5', '16', '0.0001', '0.5', '0.00001', '0.00001', '0'};
            
            %display dialog
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            
            %check and assign user inputs
            if ~isempty(answer)
                %convert to numerical values
                responses = cellfun(@str2double, answer);
                
                %validation checks for each parameter
                if isnan(responses(1)) || responses(1) <= 0 || mod(responses(1), 1) ~= 0
                    warndlg("Number of LSTM units must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.N_units = responses(1);
                end
            
                if isnan(responses(2)) || responses(2) <= 0 || mod(responses(2), 1) ~= 0
                    warndlg("Max epochs must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.max_epochs = responses(2);
                end
            
                if isnan(responses(3)) || responses(3) <= 0 || mod(responses(3), 1) ~= 0
                    warndlg("Batch size must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.batch_size = responses(3);
                end
            
                if isnan(responses(4)) || responses(4) <= 0
                    warndlg("Learning rate must be a positive float.", "Input Error");
                else
                    app.movie_data.models.temp_params.learn_rate = responses(4);
                end
            
                if isnan(responses(5)) || responses(5) < 0 || responses(5) > 1
                    warndlg("Dropout rate must be a float between 0 and 1.", "Input Error");
                else
                    app.movie_data.models.temp_params.dropout_rate = responses(5);
                end
            
                if isnan(responses(6)) || responses(6) < 0
                    warndlg("Input weights L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.input_l2_factor = responses(6);
                end
            
                if isnan(responses(7)) || responses(7) < 0
                    warndlg("Recurrent weights L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.recurrent_l2_factor = responses(7);
                end
            
                if isnan(responses(8)) || responses(8) < 0
                    warndlg("Bias L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.bias_l2_factor = responses(8);
                end
            end
        
        case "Bidirectional LSTM (BiLSTM)"
            
            prompt = {"Number of units (Positive integer):", ...
                      "Max epochs (Positive integer):", ...
                      "Batch size (Positive integer):", ...
                      "Learning Rate (Positive float, e.g., 0.0001):", ...
                      "Dropout Rate (Float between 0 and 1, e.g., 0.5):", ...
                      "Input Weights L2 Factor (Non-negative float, e.g., 0.00001):", ...
                      "Recurrent Weights L2 Factor (Non-negative float, e.g., 0.00001):", ...
                      "Bias L2 Factor (Non-negative float, e.g., 0):"};
            dlgtitle = "Bidirectional Long Short-Term Memory (BiLSTM) model parameters";
            dims = [1 90];  %width of prompt window
            
            %set defaults
            definput = {'20', '5', '16', '0.0001', '0.5', '0.00001', '0.00001', '0'};
            
            %display dialog
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            
            %check and assign user inputs
            if ~isempty(answer)
                %convert to numerical values
                responses = cellfun(@str2double, answer);
                
                %validation checks for each parameter
                if isnan(responses(1)) || responses(1) <= 0 || mod(responses(1), 1) ~= 0
                    warndlg("Number of BiLSTM units must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.N_units = responses(1);
                end
            
                if isnan(responses(2)) || responses(2) <= 0 || mod(responses(2), 1) ~= 0
                    warndlg("Max epochs must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.max_epochs = responses(2);
                end
            
                if isnan(responses(3)) || responses(3) <= 0 || mod(responses(3), 1) ~= 0
                    warndlg("Batch size must be a positive integer.", "Input Error");
                else
                    app.movie_data.models.temp_params.batch_size = responses(3);
                end
            
                if isnan(responses(4)) || responses(4) <= 0
                    warndlg("Learning rate must be a positive float.", "Input Error");
                else
                    app.movie_data.models.temp_params.learn_rate = responses(4);
                end
            
                if isnan(responses(5)) || responses(5) < 0 || responses(5) > 1
                    warndlg("Dropout rate must be a float between 0 and 1.", "Input Error");
                else
                    app.movie_data.models.temp_params.dropout_rate = responses(5);
                end
            
                if isnan(responses(6)) || responses(6) < 0
                    warndlg("Input weights L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.input_l2_factor = responses(6);
                end
            
                if isnan(responses(7)) || responses(7) < 0
                    warndlg("Recurrent weights L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.recurrent_l2_factor = responses(7);
                end
            
                if isnan(responses(8)) || responses(8) < 0
                    warndlg("Bias L2 factor must be a non-negative float.", "Input Error");
                else
                    app.movie_data.models.temp_params.bias_l2_factor = responses(8);
                end
            end
        otherwise
            
    end
end