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
%label. Each time this runs it populates the human annotations in the
%VisuallyLabelled results substruct. This function also performs autosave
%and provides predictions of annotation time to the user.
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
%drawStateRectangle()       - local to this .m file
    
    pos = app.movie_data.state.labeller_track_pos;
    
    %check that the assignment is valid
    if pos <= app.movie_data.state.labelled_so_far
        %current position has already been labelled; warn and return
        app.textout.Value = 'You have already assigned that step. If you have made a mistake, you can repeat the labelling by clicking the (Undo label) button.';
        return
    else
        col_t = findColumnIdx(app.movie_data.params.column_titles.tracks, "Time from start of track (s)");

        %write matrix to local variable for readability
        curr_track = app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol;

        %get state being requested
        app.movie_data.state.current_label_number = strcmp(app.movie_data.state.current_label, app.movie_data.params.class_names);
        app.movie_data.state.current_label_number = find(app.movie_data.state.current_label_number, 1); %error handling required when the human annotation system first runs to make sure that there is only one of each class name; this will be addressed in a future version
        
        app.textout.Value = strcat('user is manually assigning a state to', {' '}, app.movie_data.state.current_label, {' and the label number is '}, num2str(app.movie_data.state.current_label_number));
        
        %assign the label to results data
        curr_track(app.movie_data.state.labelled_so_far+1:pos,end) = app.movie_data.state.current_label_number;
        app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol = curr_track;
        
        %update the status bar above plot to show selected diffusive state
        if app.movie_data.state.labelled_so_far == 0
            left = 0;
            if pos == size(curr_track, 1)
                width = curr_track(end, col_t);
            else
                width = (curr_track(pos, col_t) + curr_track(pos + 1, col_t)) / 2;
            end
            
        else
            %if the state is a continuation of a preceeding one that is the same replace both with one label; else make a new label
            if curr_track(app.movie_data.state.labelled_so_far, end) == app.movie_data.state.current_label_number
                left_idx = find(curr_track(1:pos, end) ~= app.movie_data.state.current_label_number, 1, 'last');
                if isempty(left_idx)
                    left = 0;
                else
                    left = (curr_track(left_idx, col_t) + curr_track(left_idx + 1, col_t)) / 2;
                end

                %ensure width of state illustration bar does not exceed end of track
                if pos >= size(curr_track, 1)
                    width = curr_track(end, col_t) - left;
                else
                    width   = ((curr_track(pos, col_t) + curr_track(pos + 1, col_t)) / 2) - left;
                end

                %prevent width from exceeding plot if state extends to end of track
                if left + width > curr_track(end, col_t)
                    width = curr_track(end, col_t) - left;
                end
                
                %delete most recent rectangle in state labeller
                if ~isempty(app.UIAxes_event_labeller_status.Children)
                    delete(app.UIAxes_event_labeller_status.Children(1:2));
                end
            else
                left = (curr_track(app.movie_data.state.labelled_so_far, col_t) + curr_track(app.movie_data.state.labelled_so_far + 1, col_t)) / 2;
                if pos < size(curr_track, 1)
                    width = ((curr_track(pos, col_t) + curr_track(pos + 1, col_t)) / 2) - left;
                else
                    width = curr_track(end, col_t) - left;
                end
            end
        end
        
        %draw the rectangle with label
        drawStateRectangle(app, left, width, app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number, :), app.movie_data.state.current_label);
        
        %keep track of new position
        app.movie_data.state.labelled_so_far = pos;
        
        %if it's the end of the trajectory
        if pos == size(curr_track, 1)
            %complete the classification: add a date, compute the condensed state sequence
            app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.DateClassified  = datestr(now, 'dd/mm/yy-HH:MM:SS');
            app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.User            = app.UserEditField.Value;
            app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.EventSequence   = condenseStateSequence(curr_track(:,end));
            
            %if user asked illustration to happen after labelling, then do this now
            if app.IllustrateafterlabellingCheckBox.Value == 1
                SaveillustrationButtonPushed(app);
            end
            
            %if it's the last trajectory end, otherwise then load the next trajectory
            if app.movie_data.state.event_labeller_current_ID == size(app.movie_data.results.VisuallyLabelled.LabelledMols, 1)
                %if it's the end of the dataset
                cla(app.UIAxes_event_labeller);
                cla(app.UIAxes_event_labeller_status);
                app.textout.Value = 'Well done: you have successfully labelled all of the molecules!';
                
            else
                %give the user a projected time to finish
                if app.movie_data.state.event_labeller_current_ID > 5
                    time_per_mol = etime(datevec(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID, 1}.DateClassified),   datevec(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID-5, 1}.DateClassified))/5;
                    
                    if time_per_mol < 1000
                        pred_sec = (size(app.movie_data.results.VisuallyLabelled.LabelledMols, 1) - app.movie_data.state.event_labeller_current_ID) * time_per_mol;
                        pred_hr = floor(pred_sec / 3600);
                        pred_remaining_min = round(mod(pred_sec / 60, 60));
                        
                        app.textout.Value = sprintf('Based on your past 5 classifications, it took you %.0f seconds per molecule; to complete the remaining dataset will take an estimated %d hours and %d minutes.', time_per_mol, pred_hr, pred_remaining_min);
                    end
                end
                

                %autosave
                if app.AutosavefrequencytrajectoriesSpinner.Value ~= 0 && mod(app.movie_data.state.event_labeller_current_ID, app.AutosavefrequencytrajectoriesSpinner.Value) == 0
                    app.textout.Value = ("Autosaving...");

                    %define the autosave folder; create if it doesn't already exist
                    autosave_dir = fullfile(app.movie_data.params.ffPath, 'Autosave');
                    if ~exist(autosave_dir, 'dir')
                        mkdir(autosave_dir);
                    end
                    
                    autosave_name = sprintf('%s_Autosave_%d_mols.mat', app.movie_data.params.title{1}, app.movie_data.state.event_labeller_current_ID);
                    autosave_path = fullfile(autosave_dir, autosave_name);
                    
                    %save to disk
                    movie_data  = app.movie_data;
                    save(autosave_path, 'movie_data');
                    app.textout.Value = ("Autosave complete!");
                    
                    %delete non-recent autosave files
                    files = dir(fullfile(autosave_dir, '*.mat'));
                    if length(files) > app.NumberofautosvefilestokeepSpinner.Value
                        %sort files by date
                        [~, idx] = sort([files.datenum]);
                        %get list of all but the last N files
                        del_files = files(idx(1:end - app.NumberofautosvefilestokeepSpinner.Value));
                        
                        %delete oldest files
                        for ii = 1:length(del_files)
                            delete(fullfile(autosave_dir, del_files(ii).name));
                        end
                    end
                end
                
                %load next molecule, and reset everything
                app.movie_data.state.labelled_so_far = 0;
                app.movie_data.state.event_labeller_current_ID = app.movie_data.state.event_labeller_current_ID + 1;
                repopulateEventLabeller(app);
            end
        end
    end
end


function drawStateRectangle(app, left, width, colour, state_str)
%Illustrate a state in the human annoation system with a coloured rectangle
%and name label, Oliver Pambos, 03/06/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: drawStateRectangle
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
%Much of this code was moved from an earlier version inside
%addPartialVisualLabel(). This function generates a rectangle, text, and
%colour associated with a human annotated state. It also assigns a
%button-down action to both the rectangle and the text that enables the
%user to identify a state by clicking; this highlights the corresponding
%region of the main plot, and is implemented via the custom-written public
%method rectangleButtonDown(), and the illustration is automatically
%removed from the main plot via the public method removeHighlight().
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
%None
    
    %draw the state indicator rectangle
    rect = rectangle(app.UIAxes_event_labeller_status, 'Position', [left, 0, width, 1], 'EdgeColor','none', 'FaceColor', app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number,:));
    
    %set the button down action for the rectangle
    rect.ButtonDownFcn = @(src, event) rectangleButtonDown(app, left, left + width, colour, state_str);
    
    %decide whether to use black or white text based on the luminance of the background colour of the box; I was tired of difficult to read text; crude but functional
    luminance = 0.2126*app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number, 1) + 0.7152*app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number, 2) + 0.0722*app.movie_data.params.event_label_colours(app.movie_data.state.current_label_number, 3);
    if luminance > 0.5
        text_color = [0 0 0];
    else
        text_color = [1 1 1];
    end
    
    %generate the text
    txt = text(app.UIAxes_event_labeller_status, left + width/2, 0.5, app.movie_data.state.current_label, 'HorizontalAlignment', 'center', 'Color', text_color);
    
    %assign the text an action that executes the same code as the rectangle
    txt.ButtonDownFcn = @(src, event) rectangleButtonDown(app, left, left + width, colour, state_str);
    
    drawnow;
end