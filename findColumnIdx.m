function varargout = findColumnIdx(titles, varargin)
%Find the column index for an arbitrary number specified features, Oliver
%Pambos, 01/03/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findFeatureColumn
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
%Column index lookup is required to generalise the software to a wide
%variety of SMLM input data types, and also to eliminate hardcoding of
%imported and engineered features. This improves readability and robustness
%of code, and eliminates repetition.
%
%This function performs a lookup for specific features (column header
%strings) in the column reference cell array `titles` passed to the
%function. In the case of SMLM tracking data this reference list is stored
%in app.movie_data.params.column_titles.tracks. Column IDs are returns as
%positive integers when found, and as `0` when not found in the reference
%list.
%
%The function employs variable input and output arguments enabling a single
%call to resolve multiple column index assignments. This improves
%readability, and reduces repetitive calls.
%
%Example usage,
%[frame_col, stepsize_col] = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Frame', 'Step size (nm)')
%
%Inputs
%------
%titles     (cell)  a cell array of column titles, each containing a char
%                       array or string
%varargin   (cell)  variable number of input arguments, each a cell array
%                       or string to locate in the reference list `titles`
%
%Output
%------
%varargout  (int)   variable number of output arguments, each being a
%                       column ID for the respective input string; returns
%                       `0` when column is not found
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %pre-allocate outputs
    N_features = length(varargin);
    varargout = cell(1, N_features);
    
    %find indices
    for ii = 1:N_features
        feature = varargin{ii};
        idx = find(strcmp(titles, feature), 1, 'first');
        %return 0 if not found
        if isempty(idx)
            idx = 0;
        end
        varargout{ii} = idx;
    end
end