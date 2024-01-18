function [] = identifyExcludedSteps(app)
%Use string comparisons to user-selected feature names to determine which
%rows contain useless information, Oliver Pambos, 13/01/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: identifyExcludedSteps
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
%There are many known features that may not be available at the start or
%end of a trajectory. For example, the feature 'step size' represents the
%Euclidean distance between localisations there is no information encoded
%in the first frame. The first row of every trajectory therefore requires
%separate handling, either through cropping the rows, imputation, masking
%with a new feature, or some other process to identify or minimise the
%impact on the trained model. Currently this is handled either through
%imputation or deletion from both the training and later classified data.
%Similarly, the feature 'following step size' will have an empty entry at
%the end of the trajectory. Inluding these features would complicate
%training of the models.
%
%As many of these features have known strings assigned to them during data
%preparation, the column titles can be interpreted here using a series of
%string comparisons to automatically suggest to the user rows to remove.
%These values are returned to the GUI, where the user can override the
%decisions if necessary prior to training; this may be necessary for a
%number of reasons, for example if the localisation data comes from an
%as-yet unknown localisation algorithm with unknown feature names.
%
%This functionality may later be expanded upon by allowing the user to read
%in a file containing feature-row removal information, likely in the form
%of a dictionary/hash table.
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
    
    %ensure there are selected features to read; then zero counters
    if size(app.MLfeatures.CheckedNodes,1) == 0
        app.IgnorerowsfromstartSpinner.Value    = 0;
        app.IgnorerowsfromendSpinner.Value      = 0;
        return;
    end
    
    %compile a list of feature names
    for ii = 1:size(app.MLfeatures.CheckedNodes,1)
        feature_names{ii} = app.MLfeatures.CheckedNodes(ii).Text;
    end
    
    %zero the current values
    ignore_rows_start   = 0;
    ignore_rows_end     = 0;
    
    %interpret which rows to ignore from the list of selected feature names
    for ii = 1:length(feature_names)
        if ignore_rows_start < 1 && (strcmp(feature_names{ii}, "Time step interval from previous step (s)") || strcmp(feature_names{ii}, "Step size (nm)") || strcmp(feature_names{ii}, "Step angle relative to image (degrees)") || strcmp(feature_names{ii}, "Step angle relative to cell axis (degrees)"))
           ignore_rows_start = 1;
        elseif ignore_rows_start < 2 && (strcmp(feature_names{ii}, "Step angle relative to previous step (degrees, absolute)") || strcmp(feature_names{ii}, "Previous step size (nm)"))
            ignore_rows_start = 2;
        elseif ignore_rows_start < 3 && (strcmp(feature_names{ii}, "Second-to-last step size (nm)"))
            ignore_rows_start = 3;
        elseif ignore_rows_end < 1 && (strcmp(feature_names{ii}, "Following step size (nm)"))
            ignore_rows_end = 1;
        end
    end
    
    %update values in GUI
    app.IgnorerowsfromstartSpinner.Value    = ignore_rows_start;
    app.IgnorerowsfromendSpinner.Value      = ignore_rows_end;
end