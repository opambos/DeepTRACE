function [] = regenerateLabelButtons(app)
%Regenerate the state label button list during runtime, Oliver Pambos,
%29/10/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: regenerateLabelButtons
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
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle, now with the generated buttons
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%eventLabelButtonCallback() - button callback local to this .m file
%addPartialVisualLabel()    - called from local callback function
    
    %delete existing buttons
    if numel(app.Event_label_buttons.Children) > 0
        delete(app.Event_label_buttons.Children);
    end
    
    %compute required number of rows and columns; two columns for every button (one hold the number, the other the button itself)
    N_buttons   = size(app.movie_data.params.class_names, 1);
    N_rows      = min(N_buttons, 5);        
    N_cols      = ceil(N_buttons / 5) * 2;
    
    %build a grid layout object to hold the buttons, make digit-holding column 10x smaller than button-holding columns
    grid_layout = uigridlayout(app.Event_label_buttons, [N_rows, N_cols]);
    grid_layout.ColumnWidth = repmat({'1x', '10x'}, 1, ceil(N_buttons / 5));
    grid_layout.RowHeight = repmat({22}, 1, N_rows);
    grid_layout.BackgroundColor = [1 1 1]; %set background colour to white
    
    %generate buttons & labels on the fly
    for ii = 1:N_buttons
        column_offset = floor((ii - 1) / 5) * 2; %determine the column offset for each set of four buttons
        
        %add button label
        label = uilabel(grid_layout, 'Text', num2str(ii) + ".");
        label.Layout.Row = mod(ii - 1, 5) + 1;
        label.Layout.Column = 1 + column_offset;
        label.FontName = 'Arial'; label.FontSize = 14;
        
        %generate button
        btn = uibutton(grid_layout, 'Text', app.movie_data.params.class_names(ii), 'ButtonPushedFcn', @(btn,event) eventLabelButtonCallback(app, btn));
        btn.Layout.Row = mod(ii - 1, 5) + 1;
        btn.Layout.Column = 2 + column_offset;
        btn.FontName = 'Arial'; btn.FontSize = 14;
    end
end


function eventLabelButtonCallback(app, btn)
    app.movie_data.state.current_label = btn.Text;
    addPartialVisualLabel(app);
end

