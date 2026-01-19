function [] = setLabellerAxesRange(app)
%Set axes ranges for the human annnotation system, Oliver Pambos,
%08/02/2024.
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
    if app.PrimaryFixupperlimitCheckBox.Value
        lim_hi = app.PrimaryYaxisupperlimitSpinner.Value;

        if app.PrimarySetlowerlimttozeroCheckBox.Value
            %fixed upper and lower limit (to zero)
            lim_lo = 0;
        else
            %fixed upper limit, variable lower limit
            lim_lo = min(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature));
            lim_lo = lim_lo - ((lim_hi - lim_lo)*(0.05));
        end
        
    else
        %find highest y-value from the data points and reference lines; could be computed in single call to max()
        lim_hi = max(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature));
        if isfield(app.movie_data.params, "reference_lines") && max(app.movie_data.params.reference_lines) > lim_hi
            lim_hi = max(app.movie_data.params.reference_lines);
        end
        
        if app.PrimarySetlowerlimttozeroCheckBox.Value
            %variable upper limit, but lower limit fixed to zero
            lim_lo = 0;
            lim_hi = lim_hi+((lim_hi - lim_lo)*(0.05));
        else
            %variable lower and upper limit
            lim_lo = min(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature));
            if isfield(app.movie_data.params, "reference_lines") && min(app.movie_data.params.reference_lines) < lim_lo
                lim_lo = min(app.movie_data.params.reference_lines);
            end
            lim_lo = lim_lo - ((lim_hi - lim_lo)*(0.05));
            lim_hi = lim_hi + ((lim_hi - lim_lo)*(0.05));
        end
    end
    
    %handle scenario where range is inverted
    if lim_lo < lim_hi
        %apply axis scaling
        ylim(app.UIAxes_event_labeller, [lim_lo lim_hi]);
    else
        %notify user they have chosen bad limits
        app.textout.Value = "You have selected an inappropriate display range for the feature data; data is shown autoscaled.";
        lim_lo = min(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature));
        lim_hi = max(app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(:,app.movie_data.state.col_feature));
        ylim(app.UIAxes_event_labeller, [lim_lo - ((lim_hi - lim_lo)*(0.05)), lim_hi + ((lim_hi - lim_lo)*(0.05));]);
    end
    
    %================
    %set x-axis range
    %================
    col_t = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Time from start of track (s)');
    app.UIAxes_event_labeller.XLim = [app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(1, col_t) app.movie_data.results.VisuallyLabelled.LabelledMols{app.movie_data.state.event_labeller_current_ID,1}.Mol(end, col_t)];


    %=============================================
    %if present also adjust secondary feature axes
    %=============================================
    yyaxis(app.UIAxes_event_labeller, 'right');
    if ~isempty(app.UIAxes_event_labeller.Children)
        y_data = app.UIAxes_event_labeller.Children(1).YData;
        
        if app.SecondaryFixupperlimitCheckBox.Value
            lim_hi = app.SecondaryYaxisupperlimitSpinner.Value;

            if app.SecondarySetlowerlimttozeroCheckBox.Value
                %fixed upper and lower limit (to zero)
                lim_lo = 0;
            else
                %fixed upper limit, variable lower limit
                lim_lo = min(y_data);
                lim_lo = lim_lo - ((lim_hi - lim_lo)*(0.05));
            end
            
            
        else
            lim_hi = max(y_data);
            
            if app.SecondarySetlowerlimttozeroCheckBox.Value
                %variable upper limit, but lower limit fixed to zero
                lim_lo = 0;
                if lim_lo ~= lim_hi
                    lim_hi = lim_hi + ((lim_hi - lim_lo)*(0.05));
                else
                    %handle extremely rare case where lim_lo and lim_hi are both zero
                    lim_hi = lim_hi*1.1;
                end
            else
                %variable lower and upper limit
                lim_lo = min(y_data);
                if lim_lo ~= lim_hi
                    lim_lo = lim_lo - ((lim_hi - lim_lo)*(0.05));
                    lim_hi = lim_hi + ((lim_hi - lim_lo)*(0.05));
                else
                    %handle case where lim_lo and lim_hi are identical
                    lim_lo = lim_lo*0.9;
                    lim_hi = lim_hi*1.1;
                end
            end
        end
    end
    
    %handle scenario where range is inverted
    if lim_lo < lim_hi
        %apply axis scaling
        ylim(app.UIAxes_event_labeller, [lim_lo lim_hi]);
    else
        %notify user they have chosen bad limits
        app.textout.Value = "You have selected an inappropriate display range for secondary feature data; data is shown autoscaled.";
        lim_lo = min(y_data);
        lim_hi = max(y_data);
        ylim(app.UIAxes_event_labeller, [lim_lo - ((lim_hi - lim_lo)*(0.05)), lim_hi + ((lim_hi - lim_lo)*(0.05));]);
    end
    
    yyaxis(app.UIAxes_event_labeller, 'left');
end