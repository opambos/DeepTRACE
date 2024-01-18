function [] = addPartialVisualLabel(app)
%Apply manual label to part of a trajectory, Oliver Pambos, 27/10/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: addPartialVisualLabel
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
%When user interacts with togglebutton panel to add a label to some data,
%this subroutine checks it is valid, and assigns associated numerical
%labels
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%condenseStateSequence()
%repopulateEventLabeller()
    
    pos = app.movie_data.state.labeller_track_pos;
    
    %check that the assignment is valid
    if pos <= app.movie_data.state.labelled_so_far      % THIS MIGHT NEED TO BE REPLACED WITH < RATHER THAN <=
        %current position has already been labelled; warn and return
        app.textout.Value = 'You have already assigned that step. If you have made a mistake, you can repeat the labelling by clicking the (Undo label) button.';
        return
    else
        %get state being requested
        app.movie_data.state.current_label_number = strcmp(app.movie_data.state.current_label, app.movie_data.params.class_names);
        app.movie_data.state.current_label_number = find(app.movie_data.state.current_label_number, 1); %error checking required when event labeller first runs to make sure that there is only one of each class name or this will crash out
        
        app.textout.Value = strcat('user is manually assigning a state to', {' '}, app.movie_data.state.current_label, {' and the label number is '}, num2str(app.movie_data.state.current_label_number));
        
        %assign the label to results data
        app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(app.movie_data.state.labelled_so_far+1:pos,end) = app.movie_data.state.current_label_number;

        %update the status bar above plot to show selected diffusive state
        if app.movie_data.state.labelled_so_far == 0
            left    = 0;
            width   = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(pos,16);
        else
            left    = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(app.movie_data.state.labelled_so_far,16);
            width   = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(pos,16) - app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(app.movie_data.state.labelled_so_far,16);
        end
        rectangle(app.UIAxes_event_labeller_status, 'Position', [left, 0, width, 1], 'EdgeColor','none', 'FaceColor', app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number,:));
        
        %decide whether to use black or white text based on the luminance of the background colour of the box; I was tired of difficult to read text; crude but functional
        luminance = 0.2126*app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number,1) + 0.7152*app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number,2) + 0.0722*app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number,3);
        if luminance > 0.5
            text_color = [0 0 0];
        else
            text_color = [1 1 1];
        end
        text(app.UIAxes_event_labeller_status, left + width/2, 0.5, app.movie_data.state.current_label, 'HorizontalAlignment', 'center', 'Color', text_color);
        drawnow;
        
        %keep track of new position
        app.movie_data.state.labelled_so_far = pos;
        
        %if it's the end of the trajectory, and not the last trajectory, then load the next trajectory
        if pos == size(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol, 1)
            if app.movie_data.state.event_labeller_current_ID == size(app.movie_data.results.VisuallyLabelled.LabelledMols, 1)
                %if it's the end of the dataset
                cla(app.UIAxes_event_labeller);
                cla(app.UIAxes_event_labeller_status);
                app.textout.Value = 'Well done: you have successfully labelled all of the molecules!';
                
            else
                %complete the classification: add a date, compute the condensed state sequence
                app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.DateClassified =  datestr(now, 'dd/mm/yy-HH:MM:SS');
                app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.EventSequence = condenseStateSequence(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.Mol(:,end));

                %if user asked illustration to happen after labelling, then do this now
                if app.IllustrateafterlabellingCheckBox.Value == 1
                    SaveillustrationButtonPushed(app);
                end

                %give the user a projected time to finish
                if app.movie_data.state.event_labeller_current_ID > 5
                    time_per_mol = etime(datevec(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.DateClassified),   datevec(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID-5, 1}.DateClassified))/5;
                    if time_per_mol < 1000
                        app.textout.Value = strcat('Based on your past 5 classifications, it took you ', num2str(time_per_mol), ' seconds per molecule; to complete the remaining dataset will take an estimated ', num2str((size(app.movie_data.results.VisuallyLabelled.LabelledMols,1) - app.movie_data.state.event_labeller_current_ID) * time_per_mol / 60), ' minutes');
                    end
                end
                
                %load next molecule, and reset everything
                app.movie_data.state.labelled_so_far = 0;
                app.Slider_event_labeller.Value      = 0;
                app.movie_data.state.event_labeller_current_ID = app.movie_data.state.event_labeller_current_ID + 1;
                repopulateEventLabeller(app);
            end
        end
    end
end
