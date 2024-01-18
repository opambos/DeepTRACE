function [] = readLims(h_array)
%Update the plot limits entry boxes for the MLDataView plot, Oliver Pambos,
%02/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: readLims
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
%h_array    (cell)  array of object handles for 1. MLDataView
%                                               2. X lower limit
%                                               3. X upper limit
%                                               4. Y lower limit
%                                               5. Y upper limit
%                                               6. Z lower limit
%                                               7. Z upper limit
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    h_axes = h_array{1};
    
    %obtain the current limits from the UIAxes
    x_limits = xlim(h_axes);
    y_limits = ylim(h_axes);
    z_limits = zlim(h_axes);
    
    %update the GUI components for the plot limits of MLDataView
    h_array{2}.Value = x_limits(1);
    h_array{3}.Value = x_limits(2);
    
    h_array{4}.Value = y_limits(1);
    h_array{5}.Value = y_limits(2);
    
    h_array{6}.Value = z_limits(1);
    h_array{7}.Value = z_limits(2);
end