function [] = labelFromScratch(app)
%Initiate or overwrite the manual labelling process, Oliver Pambos,
%30/10/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: labelFromScratch
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
    class_names_input = inputdlg('Enter a list of class names for each of the diffusive states, separated by commas');
    
    %exit early if user either presses cancel, closes the dialogue box, or doesn't enter anything
    if isempty(class_names_input) || isempty(class_names_input{1})
        error("labelFromScratch:UserOmittedClassNames", "Warning in labelFromScratch: Either user cancelled or closed the class name definition dialogue, or they entered an empty input.");
    else
        app.movie_data.params.class_names = class_names_input;
    end
    
    app.movie_data.params.class_names = strip(split(app.movie_data.params.class_names, ','));  %parsing user input: separates the user inputs by the comma delimiter, then strips out any of the white space at beginning and end
    
    %wipe any previous manually labelled results - deliberately placed after gathering user input for exception handling
    app.movie_data.results.VisuallyLabelled = [];
    app.movie_data.state.labelled_so_far = 0;
    
    %populate custom buttons of the human annotation system
    regenerateLabelButtons(app);
    
    %generate random colours for each of the states selected by user - to be later introduced in an update also enabling user definition of label colours
%     app.movie_data.params.event_label_colours = [rand(size(app.movie_data.params.class_names,1),3)];
    
    %define the default colours
    preset_colours = [1 0 0;        %red
        0 0 1;                      %blue
        0 1 0;                      %green
        133/255 176/255, 154/255;   %Cambridge blue
        87/255 188/255 240/255;     %light blue
        243/255 69/255 107/255      %light red
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