function [] = saveAnalysis(app)
%Save the current analysis to file, 20/02/2024.
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
%This function moves the file save functionality out of the main GUI code
%to further modularise the code.
%
%This function loops over the properties (components) of the GUI app
%handles, filters by component type, and writes everything to file with the
%data, which is copied as the whole of app.movie_data. The save file
%therefore consists of,
%   movie_data  (struct)    contains the current state of the analysed data
%   GUI_config  (struct)    contains the current state of relevant
%                               GUI components
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
    
    %copy all of the analysis data
    movie_data = app.movie_data;
    
    %struct to store the state of GUI components
    GUI_config = struct();
    
    %get a list of all components
    properties = fieldnames(app);
    
    %loop over components
    for ii = 1:length(properties)
        component_name      = properties{ii};
        component_handle    = app.(component_name);
        
        %check if component is of the type we want to save (spinners, text areas, dropdown boxes, checkboxes); if so save
        if isa(component_handle, 'matlab.ui.control.NumericEditField') || ...   %numeric entry (non-spinner)
           isa(component_handle, 'matlab.ui.control.TextArea') || ...           %text area
           isa(component_handle, 'matlab.ui.control.Spinner') || ...            %spinner
           isa(component_handle, 'matlab.ui.control.CheckBox') || ...           %check box
           isa(component_handle, 'matlab.ui.control.DropDown')                  %drop down selection
            
            %save component
            GUI_config.(component_name) = component_handle.Value;
            
            %if it's a dropdown box also save the list of items
            if isa(component_handle, 'matlab.ui.control.DropDown') && isprop(component_handle, 'Items')
                var_name = strcat(component_name, '_Items');
                GUI_config.(var_name) = component_handle.Items;
            end
        end
    end
    
    %save data and components to file
    %user selects output file
    app.textout.Value = "Please provide a name and location to save your progress as a DeepTRACE analysis file.";
    [file, path] = uiputfile(strcat(app.movie_data.params.title, '_kinetics_analysis.mat'));
    %check user doesn't press cancel
    if isequal(file, 0) || isequal(path, 0)
        app.textout.Value = "Save operation cancelled by user";
        return;
    else
        %save analysis, and verify whether this was successful
        try
            save(fullfile(path, file), 'movie_data', 'GUI_config');
            app.textout.Value = "DeepTRACE analysis file saved successfully.";
        catch ME
            app.textout.Value = "Failed to save DeepTRACE analysis file. " + ...
                "This may be due to insufficient disk space, or you may not have sufficient administrative rights " + ...
                "to write data to the requested location: " + ME.message;
        end
    end
end