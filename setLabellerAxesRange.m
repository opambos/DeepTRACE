function [] = setLabellerAxesRange(app)
%Set axes ranges for the human annnotation system, Oliver Pambos,
%08/02/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: setLabellerAxes
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
%It was necessary to separate this as an independent function as this logic
%is called several times from different code.
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
    
    %================
    %set y-axis range
    %================
    if app.FixupperlimitCheckBox.Value
        if app.SetlowerlimttozeroCheckBox.Value
            %fixed upper and lower limit (to zero)
            lim_lo = 0;
        else
            %fixed upper limit, variable lower limit
            lim_lo = min(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature));
        end

        lim_hi = app.YaxisupperlimitSpinner.Value;
        ylim(app.UIAxes_event_labeller, [lim_lo - ((lim_hi - lim_lo)*(0.05)) lim_hi+((lim_hi - lim_lo)*(0.05))]);
    
    else
        %find highest y-value from the data points and reference lines; could be computed in single call to max()
        lim_hi = max(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature));
        if isfield(app.movie_data.params, "reference_lines") && max(app.movie_data.params.reference_lines) > lim_hi
            lim_hi = max(app.movie_data.params.reference_lines);
        end
        
        if app.SetlowerlimttozeroCheckBox.Value
            %variable upper limit, but lower limit fixed to zero
            lim_lo = 0;
            ylim(app.UIAxes_event_labeller, [lim_lo lim_hi+((lim_hi - lim_lo)*(0.05))]);
        else
            %variable lower and upper limit
            lim_lo = min(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature));
            if isfield(app.movie_data.params, "reference_lines") && min(app.movie_data.params.reference_lines) < lim_lo
                lim_lo = min(app.movie_data.params.reference_lines);
            end
            ylim(app.UIAxes_event_labeller, [lim_lo - ((lim_hi - lim_lo)*(0.05)), lim_hi+((lim_hi - lim_lo)*(0.05))]);
        end
    end
    
    %================
    %set x-axis range
    %================
    col_t = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Time from start of track (s)');
    app.UIAxes_event_labeller.XLim = [app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(1, col_t) app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(end, col_t)];
end