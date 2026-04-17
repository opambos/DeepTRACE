function [] = labelFromScratch(app)
%Initiate or overwrite the manual labelling process, Oliver Pambos,
%30/10/2022.
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
%Initialises the labelling from scratch process, by gathering custom label
%names form the user, repopulating the human annotation system with new
%buttons, overwriting any previous manual labels applying the colour
%assignments to each state, and copying over every molecular trajectory to
%the results substruct.
%
%Note that colours are currently hardcoded; in a future update this will
%be replaced with options for custom colours using a colour picker
%elsewhere in the GUI, and an option for selecting random colours.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle, with manual labelling initilised
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%regenerateLabelButtons()
    
    %prompt user for input list of class names
    if ~isfield(app.movie_data, "params") || ~isfield(app.movie_data.params, "class_names") || isempty(app.movie_data.params.class_names)
        class_names_input = inputdlg('Enter a list of class names for each of the states, separated by commas');
        
        %exit early if user either presses cancel, closes the dialogue box, or doesn't enter anything
        if isempty(class_names_input) || isempty(class_names_input{1})
            error("labelFromScratch:UserOmittedClassNames", "Warning in labelFromScratch: Either user cancelled or closed the class name definition dialogue, or they entered an empty input.");
        else
            app.movie_data.params.class_names = class_names_input;
        end
        
        app.movie_data.params.class_names = strip(split(app.movie_data.params.class_names, ','));  %parsing user input: separates the user inputs by the comma delimiter, then strips out any of the white space at beginning and end
    end
    
    %wipe any previous manually labelled results - deliberately placed after gathering user input for exception handling
    app.movie_data.results.VisuallyLabelled = [];
    app.movie_data.state.labelled_so_far = 0;
    
    %populate custom buttons of the human annotation system
    regenerateLabelButtons(app);
    
    %generate random colours for each of the states selected by user - to be later introduced in an update also enabling user definition of label colours
%     app.movie_data.params.event_label_colours = [rand(size(app.movie_data.params.class_names,1),3)];
    
    %define the default colours
    preset_colours = [1,       0,       0           %red            %0.7843,  0.2157,  0.2157;     %DeepTRACE red
                      0,       0.4471,  0.7412;     %DeepTRACE blue
                      0,       1,       0;          %green
                      133/255, 176/255, 154/255;    %Cambridge blue
                      87/255,  188/255, 240/255;    %light blue
                      243/255, 69/255,  107/255     %light red
                      ];
    
    %if there are more states than the currently described number of colours, then use the colours available, followed by randomly-selected colours
    if size(app.movie_data.params.class_names,1) > size(preset_colours, 1)
        app.movie_data.params.event_label_colours = zeros(size(app.movie_data.params.class_names,1),3);
        app.movie_data.params.event_label_colours(1:size(preset_colours, 1),:) = preset_colours;
        app.movie_data.params.event_label_colours(size(preset_colours,1)+1:size(app.movie_data.params.class_names,1),:) = rand(size(app.movie_data.params.class_names,1) - size(preset_colours,1), 3);
    else
        %otherwise use the available colours
        app.movie_data.params.event_label_colours(1:size(app.movie_data.params.class_names,1),:) =  preset_colours(1:size(app.movie_data.params.class_names,1),:);
    end
    
    count = 1;
    %copy over every track to the results struct
    for ii = 1:size(app.movie_data.cellROI_data,1)
        for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs,1)
            %write the LoColi tracks data to the LabelledMols struct
            app.movie_data.results.VisuallyLabelled.LabelledMols{count,1}.Mol = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj), :);
            
            %update the VisuallyLabelled results substruct; a cell array of classifications performed by the user
            app.movie_data.results.VisuallyLabelled.LabelledMols{count,1}.CellID = ii;
            app.movie_data.results.VisuallyLabelled.LabelledMols{count,1}.MolID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj);
            app.movie_data.results.VisuallyLabelled.LabelledMols{count,1}.EventSequence = 'pending';
            app.movie_data.results.VisuallyLabelled.LabelledMols{count,1}.MoleculeDuration = size(app.movie_data.results.VisuallyLabelled.LabelledMols{count}.Mol,1) / app.movie_data.params.frame_rate;      %in seconds
            app.movie_data.results.VisuallyLabelled.LabelledMols{count,1}.DateClassified = 'pending';
            
            count = count + 1;
        end
    end
    
    %populate the GUI dropdown options in the State histogram and Event overlayer panels with the new class names
    app.EventstoviewDropDown.Items  = app.movie_data.params.class_names;    %put class names back in class selection box in state histogram options
    app.EventoverlayerSOI.Items     = app.movie_data.params.class_names;    %put class names back in class selection box in event overlayer options
    
    %start the user at the first molecule in the dataset
    app.movie_data.state.event_labeller_current_ID = 1;
end