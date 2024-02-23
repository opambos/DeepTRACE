function saveAnalysis(app)
%Save the current analysis to file, Oliver Pambos, 20/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: saveAnalysis
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
    
    %get the filename and location to write to
    [file, path] = uiputfile(strcat(app.movie_data.params.title, '_kinetics_analysis.mat'));
    %check user doesn't press cancel
    if isequal(file, 0) || isequal(path, 0)
        return;
    end
    
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
        end
    end
    
    %save data and components to file
    save(fullfile(path, file), 'movie_data', 'GUI_config');
end
