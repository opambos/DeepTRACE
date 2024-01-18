function [idx_file, file_frame] = findFrame(frame_offsets, globalframe)
%Locates the correct file and frame from the global frame number, Oliver
%Pambos, 12/11/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findFrame
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
%LoColi does a very bad job of managing multiple FITS files often knocking
%them out of sync. As single recordings are broken into multiple .FITS
%files with a number of frames dependent upon the ROI size, and bit depth
%used, this routine is necessary to ensure that the global frame number
%(across all files) can be translated into the correct filename and frame
%number (within that file), so that other parts of the system can find the
%correct raw data for various operations.
%
%Inputs
%------
%params         (struct)    params substruct of the main data struct
%globalframe    (int)       frame number (from concatenated files) to find
%
%Outputs
%-------
%idx_file       (int)       index of FITS file containing requested frame
%file_frame     (int)       frame number within FITS file
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    idx_file = max(find(frame_offsets < globalframe));
    file_frame = globalframe - frame_offsets(idx_file);
end

