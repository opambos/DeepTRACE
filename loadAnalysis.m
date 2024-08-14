function loadAnalysis(app)
%Load an existing DeepTRACKS analysis file, and configure the GUI control
%state to reflect the saved state, Oliver Pambos, 20/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: loadAnalysis
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
%This function modularizes the file loading functionality for the GUI. It
%loads a saved DeepTRACKS analysis file, updates the GUI controls to
%reflect the saved state, and ensures that the core analysis data is loaded
%correctly.
%
%This function distinguishes between different file types using the
%'filtered_track_IDs' field, which is always present after data preparation
%in DeepTRACKS, and absent in files output from input pipelines such as
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
%fluorescence video files (ffFile); if this is invalid it prompts user to
%provide an opportunity to update the path using the path selection GUI,
%after which it checks the validity of the newly provided path. This
%enables intuitive the moving of saved data files between different
%machines and operating systems with the minimum of hassle to the user,
%whilst also not making any assumptions about the location, or naming, of
%files, which may differ from one user to another.
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
    
    %track GUI loading errors
    gui_load_error      = false;
    gui_config_missing  = false;

    %user provides DeepTRACKS analysis file
    app.textout.Value = "Please select a DeepTRACKS analysis file,";
    [file, path] = uigetfile({'*.mat', 'DeepTRACKS analysis file (.mat)'}, 'Select a DeepTRACKS analysis file.');
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
    if ~checkFluorFilePaths(app)
        %exit if user hasn't provided the valid file path to fluor files
        return;
    end
    
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


function fluorpath_OK = checkFluorFilePaths(app)
%Check if the file is correctly linked to the fluorescence video files, and
%prompt user to reconnect file path if necessary, Oliver Pambos,
%13/08/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: checkFluorFilePaths
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
%This function performs a check to ensure the fluorescence video files are
%correctly linked within within the app.movie_data.params struct. If
%linking is incorrect it provides the user with the opportunity to identify
%the correct path using the path selection GUI tool. This improves
%portability between machines, and inter-operability between different
%operating systems.
%
%Input
%-----
%app            (handle)    main GUI handle
%
%Output
%------
%fluorpath_OK   (bool)  true if the filepath is valid, else false
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    fluorpath_OK = true;
    
    %check if the ffPath exists
    if isfolder(app.movie_data.params.ffPath)
        %check if the files in ffFile exist in the specified ffPath
        files_exist = all(cellfun(@(file) isfile(fullfile(app.movie_data.params.ffPath, file)), app.movie_data.params.ffFile));
        
        if files_exist
            %if all files exist, continue as normal
            return;
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
                new_files_exist = all(cellfun(@(file) isfile(fullfile(new_path, file)), app.movie_data.params.ffFile));
                
                %if files exist update ffPath with new path and continue, otherwise warn user and exit
                if new_files_exist
                    app.movie_data.params.ffPath = [new_path filesep];
                    return;
                else
                    warndlg('The provided path does not contain the fluorescence video files. Please restart the loading process.', 'Missing Fluorescence Video Files');
                    ClearanalysisButtonPushed(app);
                    fluorpath_OK = false;
                    return;
                end
            end
        end
        
    else
        %prompt user to provide ffPath if original does not exist
        new_path = uigetdir('', 'Select the directory containing the fluorescence video files');
        
        if new_path == 0
            %if the user cancels the directory selection
            warndlg('No directory selected. Please restart the loading process.', 'Missing Fluorescence Video Files');
            ClearanalysisButtonPushed(app);
            fluorpath_OK = false;
            return;
        else
            %check if files exist in the new path
            new_files_exist = all(cellfun(@(file) isfile(fullfile(new_path, file)), app.movie_data.params.ffFile));
            
            %if files exist in path provided update ffPath with new path and continue, otherwise warn user and exit
            if new_files_exist
                app.movie_data.params.ffPath = [new_path filesep];
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