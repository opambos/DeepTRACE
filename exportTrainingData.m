function [] = exportTrainingData(app)
%Export training, validation, and test data for use in external frameworks,
%Oliver Pambos, 11/06/2024.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
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
%Exports the user's notes to a wide range of different formats, currently
%including,
%   - CSV   (recommended)
%   - JSON
%   - HDF5
%
%CSV is recommended for almost all applications due to its flexibility, and
%human readability. This output format will prompt the user for a directory
%into which the data will be written, inside which it will create up to
%three folders (training, validation, and test) containing an individual
%file for each of the tracks, or track sections. In each case the
%corresponding annotations are placed in the same directory with the suffix
%'_labels', followed by a number that corresponds to its associated
%datafile.
%
%JSON is widely used, and enables a single file for each of the datasets.
%
%HDF5 is only useful for a small number of tracks of extremely long length,
%and is therefore not recommended for most tracking applications; file
%write times can be extremely long using this format particularly when
%using short segments or sliding windows due to the need to separate each
%track or segment into an individual dataset.
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
    
    switch app.TrainingdataexportformatDropDown.Value
        case "CSV"
            %get export pathname from user
            path = uigetdir([], 'Select the directory to save CSV files');
            if path == 0
                disp('User canceled the file selection.');
                return;
            end
            
            %define file types
            data_types      = {'train', 'validation', 'test'};
            data_fields     = {'train_data', 'val_data', 'test_data'};
            label_fields    = {'train_labels', 'val_labels', 'test_labels'};
            
            %handle scenarios where val_data or test_data are missing
            active_data_types   = {};
            active_data_fields  = {};
            active_label_fields = {};
            for ii = 1:length(data_types)
                if isfield(app.movie_data.results, data_fields{ii}) && ~isempty(app.movie_data.results.(data_fields{ii}))
                    active_data_types{end+1}    = data_types{ii};
                    active_data_fields{end+1}   = data_fields{ii};
                    active_label_fields{end+1}  = label_fields{ii};
                end
            end
            
            for ii = 1:length(active_data_types)
                %create a directory for each data type
                folder_path = fullfile(path, active_data_types{ii});
                if ~exist(folder_path, 'dir')
                    mkdir(folder_path);
                end
                
                %get the current dataset
                curr_data   = app.movie_data.results.(active_data_fields{ii});
                curr_labels = app.movie_data.results.(active_label_fields{ii});
                
                h_progress = waitbar(0, 'Please wait...');
                
                %export each separate entry and its labels
                for jj = 1:length(curr_data)
                    waitbar(jj / length(curr_data), h_progress, sprintf('Exporting %s: %d%%', replace(active_data_fields{ii}, '_', ' '), floor(jj / length(curr_data) * 100)));
                    
                    %define filename for each matrix
                    data_filename   = fullfile(folder_path, sprintf('%s_data_%d.csv', active_data_types{ii}, jj));
                    labels_filename = fullfile(folder_path, sprintf('%s_labels_%d.csv', active_data_types{ii}, jj));
                    
                    %export data with annotations
                    writematrix(curr_data{jj}, data_filename);
                    writematrix(curr_labels{jj}, labels_filename);
                end
                close(h_progress);
            end
            
            app.textout.Value = "Exported data and labels have been saved to: " + path;
            
        case "JSON"
            %get export pathname from user
            [file, path] = uiputfile('*.json', 'Save JSON file as');
            if isequal(file, 0) || isequal(path, 0)
                disp('User canceled the file selection.');
                return;
            end
            base_pathname = fullfile(path, file);
            
            %extract filename without extension
            [~, name] = fileparts(base_pathname);
            
            %define file suffixes
            data_types      = {'train', 'validation', 'test'};
            data_fields     = {'train_data', 'val_data', 'test_data'};
            label_fields    = {'train_labels', 'val_labels', 'test_labels'};
            
            %handle scenarios where val_data or test_data are missing
            active_data_types   = {};
            active_data_fields  = {};
            active_label_fields = {};
            for ii = 1:length(data_types)
                if isfield(app.movie_data.results, data_fields{ii}) && ~isempty(app.movie_data.results.(data_fields{ii}))
                    active_data_types{end+1}    = data_types{ii};
                    active_data_fields{end+1}   = data_fields{ii};
                    active_label_fields{end+1}  = label_fields{ii};
                end
            end
            
            for ii = 1:length(active_data_types)
                %gen filename for current data type
                json_pathname = fullfile(path, [name, '_', active_data_types{ii}, '.json']);
                
                %check if file exists and delete if the user chooses to overwrite
                if exist(json_pathname, 'file')
                    choice = questdlg('File exists. Do you want to overwrite it?', 'File Exists', 'Yes', 'No', 'No');
                    if strcmp(choice, 'No')
                        disp(['User chose not to overwrite the existing file: ', json_pathname]);
                        continue;
                    end
                    delete(json_pathname);
                end
                
                %get the current dataset
                curr_data = app.movie_data.results.(active_data_fields{ii});
                curr_labels = app.movie_data.results.(active_label_fields{ii});
                
                h_progress = waitbar(0, 'Please wait...');
                
                %initialize a cell array to hold JSON objects
                data_json_array = cell(1, length(curr_data));
                
                %export each separate entry and its labels
                for jj = 1:length(curr_data)
                    waitbar(jj / length(curr_data), h_progress, sprintf('Exporting %s: %d%%', replace(active_data_fields{ii}, '_', ' '), floor(jj / length(curr_data) * 100)));
                    
                    %convert to numeric
                    data_struct = struct('Data', curr_data{jj}, 'Labels', double(curr_labels{jj}));
                    
                    %convert the struct to a JSON string
                    data_json_array{jj} = jsonencode(data_struct);
                end
                
                %write file
                fid = fopen(json_pathname, 'w');
                if fid == -1
                    error('Cannot open file for writing: %s', json_pathname);
                end
                fprintf(fid, '[');
                for k = 1:length(data_json_array)
                    if k > 1
                        fprintf(fid, ',');
                    end
                    fprintf(fid, '%s', data_json_array{k});
                end
                fprintf(fid, ']');
                fclose(fid);
                
                close(h_progress);
            end
            
            app.textout.Value = "Exported data and labels have been saved to: " + base_pathname;

        case "HDF5"
           %get export pathname from user
            [file, path] = uiputfile('*.h5', 'Save HDF5 file as');
            if isequal(file, 0) || isequal(path, 0)
                disp('User canceled the file selection.');
                return;
            end
            base_pathname = fullfile(path, file);
            
            %extract filename without extension
            [~, name] = fileparts(base_pathname);
            
            %define file suffixes
            data_types      = {'train', 'validation', 'test'};
            data_fields     = {'train_data', 'val_data', 'test_data'};
            label_fields    = {'train_labels', 'val_labels', 'test_labels'};
            
            %handle scenarios where val_data or test_data are missing
            active_data_types   = {};
            active_data_fields  = {};
            active_label_fields = {};
            for ii = 1:length(data_types)
                if isfield(app.movie_data.results, data_fields{ii}) && ~isempty(app.movie_data.results.(data_fields{ii}))
                    active_data_types{end+1}    = data_types{ii};
                    active_data_fields{end+1}   = data_fields{ii};
                    active_label_fields{end+1}  = label_fields{ii};
                end
            end
            
            for ii = 1:length(active_data_types)
                %gen filename for current data type
                data_pathname = fullfile(path, [name, '_', active_data_types{ii}, '_data.h5']);
                
                %check if file exists and delete if the user chooses to overwrite
                if exist(data_pathname, 'file')
                    choice = questdlg('File exists. Do you want to overwrite it?', 'File Exists', 'Yes', 'No', 'No');
                    if strcmp(choice, 'No')
                        disp(['User chose not to overwrite the existing file: ', data_pathname]);
                        continue;
                    end
                    delete(data_pathname);
                end
                
                %get the current dataset
                curr_data = app.movie_data.results.(active_data_fields{ii});
                curr_labels = app.movie_data.results.(active_label_fields{ii});
                
                h_progress = waitbar(0, 'Please wait ....');
                %export each separate entry and its labels
                for jj = 1:length(curr_data)
                    waitbar(jj / length(curr_data), h_progress, sprintf('Exporting %s: %d%%', replace(active_data_fields{ii}, '_', ' '), floor(jj / length(curr_data) * 100)));
            
                    dataset_data_path   = sprintf('/data/%d', jj);
                    dataset_label_path  = sprintf('/labels/%d', jj);
                    
                    h5create(data_pathname, dataset_data_path, size(curr_data{jj}), 'Datatype', 'double');
                    h5write(data_pathname, dataset_data_path, curr_data{jj});
                    
                    %convert categorical labels to numeric
                    curr_label_numeric = double(curr_labels{jj});
                    
                    h5create(data_pathname, dataset_label_path, size(curr_label_numeric), 'Datatype', 'double');
                    h5write(data_pathname, dataset_label_path, curr_label_numeric);
                end
                
                close(h_progress);
            end
            
            app.textout.Value = "Exported data and labels have been saved to: " + base_pathname;

        otherwise
            
    end
end