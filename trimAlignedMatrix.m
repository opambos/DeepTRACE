function [trimmed_mat, trimmed_t] = trimAlignedMatrix(aligned_mat, t)
%Strip the zeros from either side of the matrices of aligned events,
%Oliver Pambos, 25/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trimAlignedMatrix
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
%aligned_mat    (mat)   padded matrix consisting of aligned events; each row contains an individual event
%t              (vec)   row vector of time values relative to event; each entry corresponds to the associated column in aligned_mat
%
%Outputs
%-------
%trimmed_mat    (mat)   padded matrix consisting of aligned events, with padding removed from left and right sides
%trimmed_t      (vec)   row vector of time values relative to event; each entry corresponds to the associated column in trimmed_mat
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %find the first and last columns with non-zero elements
    first_nonzero_col = find(any(aligned_mat~=0, 1), 1, 'first');
    last_nonzero_col  = find(any(aligned_mat~=0, 1), 1, 'last');

    %trim the matrix and the corresponding row vector t
    trimmed_mat = aligned_mat(:, first_nonzero_col:last_nonzero_col);
    trimmed_t   = t(:, first_nonzero_col:last_nonzero_col);
end
