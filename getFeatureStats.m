function [] = getFeatureStats(app, overwrite)
%Compute global feature stats across tracks data, Oliver Pambos,
%28/06/2025.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getFeatureStats
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
%Provide rapid access to feature stats for a wide range of different track
%analysis tasks.
%
%Inputs
%------
%app        (handle)    main GUI handle
%overwrite  (bool)      boolean to determine whether to overwrite existing
%                           feature stats
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %ignore if ranges already exist
    if (isfield(app.movie_data,"params") && isfield(app.movie_data.params,"feature_stats") && overwrite == false) || ~isfield(app.movie_data.params, "column_titles") || isempty(app.movie_data.cellROI_data)
        return
    end
    
    %init vars
    N_features  = numel(app.movie_data.params.column_titles);   %this also captures the class label
    global_min  =  inf(1, N_features);
    global_max  = -inf(1, N_features);
    sum_feat    =  zeros(1,N_features);
    sum_sqrt    =  zeros(1,N_features);
    total_rows  =  0;
    
    for ii = 1:numel(app.movie_data.cellROI_data)
        tracks      = app.movie_data.cellROI_data(ii).tracks;
        
        %skip empty cells
        if isempty(tracks)
            continue;
        end
        
        global_min   = min(global_min, min(tracks,[],1), 'omitnan');
        global_max   = max(global_max, max(tracks,[],1), 'omitnan');
        
        sum_feat   = sum_feat + sum(tracks,   1,'omitnan');
        sum_sqrt    = sum_sqrt  + sum(tracks.^2,1,'omitnan');
        total_rows = total_rows + size(tracks,1);
    end
    
    %compute mean and stdev globally
    mu    = sum_feat ./ total_rows;
    var   = max(sum_sqrt./total_rows - mu.^2, 0);
    sigma = sqrt(var);
    
    %store stats back in main struct
    app.movie_data.params.feature_stats = [global_min; global_max; mu; sigma];
end