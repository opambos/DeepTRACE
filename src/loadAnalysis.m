function [load_successful] = loadAnalysis(app)
%Load an existing DeepTRACE analysis file, and configure the GUI control
%state to reflect the saved state, 20/02/2024.
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
%This function modularizes the file loading functionality for the GUI. It
%loads a saved DeepTRACE analysis file, updates the GUI controls to
%reflect the saved state, and ensures that the core analysis data is loaded
%correctly.
%
%This function distinguishes between different file types using the
%'filtered_track_IDs' field, which is always present after data preparation
%in DeepTRACE, and absent in files output from input pipelines such as
%LoColi. While a versioning field could be introduced, it would necessitate
%updating all older saved files, which may not be practical.
%
%Exception handling ensures that even if there are changes to the GUI
%components between versions, the core saved data (app.movie_data) is
%loaded correctly. If a component is not found, the function will not
%proceed to load further components and the user will need to manually
%reconfigure the GUI controls, or load a valid configuration file
%separately.
%
%This function additionally checks the validity of the path (ffPath) to the
%fluorescence video files (ffFile); if this is invalid it will then search
%the path containing the loaded analysis file; if this too fails it falls
%back to prompting the user to identify the correct path using the path
%selection GUI, after which it checks the validity of the newly provided
%path. This enables intuitive the moving of saved data files between
%different machines and operating systems with the minimum of hassle to the
%user; automatic file linking occurs in the vast majority of practical
%cases.
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
%checkFluorFilePaths()  - local to this .m file
    
    load_successful = false;

    %record username to prevent overwrite on file load
    if isprop(app, "movie_data") && isfield(app.movie_data, "params") && isfield(app.movie_data.params, "user")
        username = app.movie_data.params.user;
    else
        username = "Default user";
    end
    
    %track loading errors
    gui_load_error      = false;
    gui_config_missing  = false;
    
    %========================
    %Part 1: load tracks data
    %========================
    %user provides DeepTRACE analysis file
    app.textout.Value = "Please select a DeepTRACE analysis file,";
    [file, path] = uigetfile({'*.mat', 'DeepTRACE analysis file (.mat)'}, 'Select a DeepTRACE analysis file.');
    %check user didn't cancel
    if isequal(file, 0) || isequal(path, 0)
        return;
    end
    
    %load data from file
    loaded_data = load(fullfile(path, file));
    
    %check if the file contains movie_data and update app.movie_data
    if isfield(loaded_data, 'movie_data') && isfield(loaded_data.movie_data, 'cellROI_data') && size(loaded_data.movie_data.cellROI_data,1) &&...
            isfield(loaded_data.movie_data.cellROI_data, 'filtered_track_IDs')
        app.movie_data = loaded_data.movie_data;
    else
        app.textout.Value = "The loaded file is not a valid InVivoKinetics analysis file. " + newline + ...
            "This is most likely to occur when an unrelated `.mat` file is loaded " + ...
            "(for example a user configuration file or saved MATLAB workspace variables)";
        return;
    end
    
    %check fluorescence file paths, get new path from user if necessary
    if checkFluorFilePaths(app, path)
        load_successful = true;
    else
        %exit if user hasn't provided the valid file path to fluor files
        load_successful = false;
        return;
    end
    
    %===========================
    %Part 1: update GUI controls
    %===========================
    %compile a list of items to ignore when updating the GUI from save file
    ignore_list = {'HeatmapstyleDropDown', 'BackgroundcolourDropDown', 'DiffusionHistPlotlocationDropDown', 'ProcessaveragesDropDown', 'DcalculationmethodDropDown','TruncationDropDown','HistogramdatatoexportDropDown','Overlayerstyle',...
        'EntriesorexitsDropDown','FeatureimportancemetricDropDown','FeatureVisualisationMethodDropDown','FeatureAnalysisDatasubsetDropDown','ShufflingmethodDropDown','TracksamplingDropDown','TrainingdataexportformatDropDown','TrainingmodeDropDown',...
        'LossfunctionDropDown','ModelexportformatDropDown','PermutationImportanceDatasubsetDropDown','SHAPvaluedisplayDropDown','PostprocessingmethodDropDown'};
    
    %check if the file contains the config data, if so load it
    if ~isfield(loaded_data, 'GUI_config')
        gui_config_missing = true;
    else
        try
            %update the GUI components with the loaded state
            components = loaded_data.GUI_config;
            fields = fieldnames(components);
            for ii = 1:length(fields)
                component_name = fields{ii};
                if isprop(app, component_name)
                    component = app.(component_name);
                    
                    %if component is on the ignore list, skip
                    if ismember(component_name, ignore_list)
                        continue;
                    end
                    
                    %if it's a dropdown box, search for a saved items list in the loaded data and update the current values
                    if isa(component, 'matlab.ui.control.DropDown')
                        var_name = strcat(component_name, '_Items');
                        if iscell(loaded_data.GUI_config.(var_name))
                            app.(component_name).Items = loaded_data.GUI_config.(var_name);
                        end
                    end
                    
                    %if it's recognised, update it in the active GUI
                    if isa(component, 'matlab.ui.control.NumericEditField') || ...  %numeric entry (non-spinner)
                        isa(component, 'matlab.ui.control.TextArea') || ...         %text area
                        isa(component, 'matlab.ui.control.Spinner')  || ...         %spinner
                        isa(component, 'matlab.ui.control.CheckBox') || ...         %check box
                        isa(component, 'matlab.ui.control.DropDown')                %dropdown box
                        
                        %load component value
                        component.Value = components.(component_name);
                    end
                end
            end
        catch ME
            gui_load_error = true;
            warning(ME.identifier, 'Error updating GUI components. Some settings may not be restored: %s', ME.message);
        end
    end
    
    %clear the existing event labelling buttons
    delete(app.Event_label_buttons.Children);

    %write the current user's name back to params struct
    app.movie_data.params.user = username;
    
    %notify user regarding loaded data state
    if gui_load_error
        app.textout.Value = "Warning: Not all GUI settings were restored, " + ...
            "likely due to the analysis file either being saved using an older version of the software or file corruption, " + ...
            "however the critical saved analysis data was loaded successfully.";
    elseif gui_config_missing
        app.textout.Value = "The loaded file did not contain GUI configuration options. " + ...
            "This may have been saved using an older version of the software. " + newline + ...
            "The file has been loaded without the GUI settings configuration, " + ...
            "however if you have a saved user configuratin file you can load " + ...
            "this separately using the `Load configuration` button. " + newline + ...
            "Note that resaving your file will resolve this issue in the future.";
    else
        app.textout.Value = "A previous analysis file has been loaded. " + ...
            "To continue labelling molecules press the [Begin] button in the [Human annotation tab].";
    end
end


function [fluorpath_OK] = checkFluorFilePaths(app, analysis_path)
%Check if the file is correctly linked to the fluorescence video files, and
%prompt user to reconnect file path if necessary, 13/08/2024.
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
%This function performs a check to ensure the fluorescence video files are
%correctly linked within within the app.movie_data.params struct. If
%linking is incorrect it provides the user with the opportunity to identify
%the correct path using the path selection GUI tool. This improves
%portability between machines, and inter-operability between different
%operating systems.
%
%The app.movie_data.params.ffFile cell/char issue is inherited from
%integration of LoColi pipeline during early development, this will be
%addressed more robustly in a future update.
%
%The order of fluorescence file linking is as follows,
%   1. Exact path defined by ffPath
%   2. Analysis file path
%   3. If still missing, prompt user to identify location
%
%Input
%-----
%app    (handle)    main GUI handle
%path   (str)       file path for the loaded .mat analysis file
%
%Output
%------
%fluorpath_OK   (bool)  true if the filepath is valid, else false
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    fluorpath_OK = false;
    
    %if app.movie_data.params.ffFile is a char arr (i.e. if only one fluor file then convert to cell, see header notes)
    ff_files = app.movie_data.params.ffFile;
    if ischar(ff_files) || isstring(ff_files)
        ff_files = cellstr(ff_files);
    end

    %check if (i) the folder described in ffPath exists on this machine, and (ii) that the files held in ffFile are in that folder
    if isfolder(app.movie_data.params.ffPath) && all(cellfun(@(file) isfile(fullfile(app.movie_data.params.ffPath, file)), ff_files))
        %all files exist, continue as normal
        fluorpath_OK = true;
        return;
    
    %elseif all files can be found in the same directory as the loaded analysis file
    elseif all(cellfun(@(file) isfile(fullfile(analysis_path, file)), ff_files))
        app.movie_data.params.ffPath = analysis_path;
        fluorpath_OK = true;
        return;
    
    %if files cannot be found anywhere sensible, then prompt user to identify the folder themselves
    else
        %prompt user to provide new ffPath
        new_path = uigetdir('', 'Select the directory containing the fluorescence video files');
        
        if new_path == 0
            %if the user cancels the directory selection
            warndlg('No directory selected. Please restart the loading process.', 'Missing Fluorescence Video Files');
            ClearanalysisButtonPushed(app);
            fluorpath_OK = false;
            return;
        else
            %check if files exist in new path
            new_files_exist = all(cellfun(@(file) isfile(fullfile(new_path, file)), ff_files));
            
            %if files exist update ffPath with new path and continue, otherwise warn user and exit
            if new_files_exist
                app.movie_data.params.ffPath = [new_path filesep];
                fluorpath_OK = true;
                return;
            else
                warndlg('The provided path does not contain the fluorescence video files. Please restart the loading process.', 'Missing Fluorescence Video Files');
                ClearanalysisButtonPushed(app);
                fluorpath_OK = false;
                return;
            end
        end
    end
end