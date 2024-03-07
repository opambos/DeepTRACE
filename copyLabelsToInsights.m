function [success] = copyLabelsToInsights(app)
%Copies the relevant source of labels to the `insights` substruct for
%analysis, Oliver Pambos, 07/03/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: copyLabelsToInsights
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
%This function copies an entire labelled dataset into a dedicated substruct
%(`InsightData`), providing a stable location for data to be analysed.
%Operating on a consistent data struct greatly simplifies the organisation
%of downstream analysis code, and enables additional models and data
%labelling methods to be later incorporated into the InVivoKinetics
%codebase.
%
%The labelled data to copy into the `InsightData` struct is determined by
%the GUI component `app.InsightsSourcedataDropDown`.
%
%Input
%-----
%app        (handle)    main GUI handle
%
%Output
%------
%success    (bool)      true only if labelled data substruct successfully
%                           copied to InsightData substruct; else false
%app        (handle)    main GUI handle, now containing a copy of the relevant
%                           data labels in the `InsightData` substrct (not
%                           passed by value)
    
    
    success = false;
    
    if ~isfield(app.movie_data, "results")
        return;
    elseif isfield(app.movie_data.results, "InsightData")
        app.movie_data.results  = rmfield(app.movie_data.results, 'InsightData');
    end
    
    %copy selected labelled dataset to the `InsightData` substruct; if this is not found,
    %execute the dropdown callback to make sure the options available to the user in the app is up to date
    switch app.InsightsSourcedataDropDown.Value
        case "Human annotations"
            if isfield(app.movie_data.results, "VisuallyLabelled")
                app.movie_data.results.InsightData = app.movie_data.results.VisuallyLabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select again";
                app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Ground truth"
            if isfield(app.movie_data.results, "GroundTruth")
                app.movie_data.results.InsightData = app.movie_data.results.GroundTruth;
            else
                app.textout.Value = "The selected dataset is no longer available, please select again";
                app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from RF"
            if isfield(app.movie_data.results, "RFLabelled")
                app.movie_data.results.InsightData = app.movie_data.results.RFLabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select again";
                app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from LSTM"
            if isfield(app.movie_data.results, "LSTMLabelled")
                app.movie_data.results.InsightData = app.movie_data.results.LSTMLabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select again";
                app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from BiLSTM"
            if isfield(app.movie_data.results, "BiLSTMLabelled")
                app.movie_data.results.InsightData = app.movie_data.results.BiLSTMLabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select again";
                app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from GRU"
            if isfield(app.movie_data.results, "GRULabelled")
                app.movie_data.results.InsightData = app.movie_data.results.GRULabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select again";
                app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        case "Labels from BiGRU"
            if isfield(app.movie_data.results, "BiGRULabelled")
                app.movie_data.results.InsightData = app.movie_data.results.BiGRULabelled;
            else
                app.textout.Value = "The selected dataset is no longer available, please select again";
                app.InsightsSourcedataDropDownOpening(app, []);
            end
            
        otherwise
            app.textout.Value = "No data is available to compute insights";
    end
    
    if isfield(app.movie_data.results, "InsightData") && ~isempty(app.movie_data.results.InsightData)
        success = true;
    end
end