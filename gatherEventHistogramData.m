function [data] = gatherEventHistogramData(app, class_number)
%Gather dwell time data for each event in the human annotated data based on
%user selections of which class to show, and what type of truncation to
%show, Oliver Pambos, 29/10/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: gatherEventHistogramData
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
%This function filters the appropriate extracted states matrix for a given
%class to compile histogram data based on truncation type. Filtering is
%performed based on logical comparison of left and right trucation values.
%
%This code is currently hardcoded to the VisuallyLabelled substruct as the
%system is currently primarily used for manually-labelled data, but this
%will be expanded to include other modalities in the near future.
%
%Inputs
%------
%app            (handle)    main GUI handle, crucially this must contain the Nx6 extractedStates matrices
%class_number   (int)       number of the class/state for which to compile histogram data
%
%Output
%------
%data           (mat)       the extracted states matrix
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %retrieve the extracted states matrix for the requested class
    data = app.movie_data.results.VisuallyLabelled.extractedStates{1, class_number};

    truncation = app.TruncationDropDown.Value;
    
    switch truncation
        case 'Singly-truncated'
            
            %keep the data which is either truncated left, or truncated right, but not both
            data = data(data(:,5) == 1 & data(:,6) == 0  |  data(:,5) == 0 & data(:,6) == 1, :);
            
        case 'Doubly-truncated'
            
            %keep data which is both left and right truncated
            data = data(data(:,5) == 1 & data(:,6) == 1, :);
            
        case 'All truncated'
            
            %keep the data which is either left truncated, right truncated, or (implicitly) both
            data = data(data(:,5)==1 | data(:,6)==1, :);
            
        case 'Full events'
            
            %keep the data which is neither left or right truncated
            data = data(data(:,5) == 0 & data(:,6) == 0, :);
            
        case 'All events'
            %do nothing, user will see all data
        otherwise
    end
end