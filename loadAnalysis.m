function loadAnalysis(app)
%Save the current analysis to file, Oliver Pambos, 20/02/2024.
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
%This function moves the file load functionality out of the main GUI code
%to further modularise the code.
%
%This function loops over the saved GUI states, and updates any entries
%that have a corresponding control in the current GUI.
%
%Note that currently the field 'filtered_track_IDs' is used to distinguish
%the difference between a LoColi file and an InVivoKinetics save file as
%this field only exists following data preparation, and must exists in all
%versions of InVivoKinetics. While it is possible to introduce a new field
%to hold for example the version number, this would require coding a
%fallback option as the structs of save files from time-consuming analyses
%done by multiple human annotators during development would also have to be
%updated.
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
%None
    
    %ask user to select file
    [file, path] = uigetfile('*.mat', 'Select the Analysis File');
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
    
    %check if the file contains the config data, if so load it
    if ~isfield(loaded_data, 'GUI_config')
        app.textout.Value = "The file did not contain GUI configuration options. " + ...
            "This may have been saved using an older version of the software. " + newline + ...
            "The file has been loaded without the GUI settings configuration, " + ...
            "however if you have a saved user configuratin file you can load " + ...
            "this separately using the `Load configuration` button. " + newline + ...
            "Note that resaving your file will resolve this issue in the future.";
    else
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
    end
    
    %clear the existing event labelling buttons
    delete(app.Event_label_buttons.Children);
    
end
