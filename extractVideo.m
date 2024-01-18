function [video] = extractVideo(ffpath, ffname, frame_lo, frame_hi, x_lo, x_hi, y_lo, y_hi)
%Extracts a section (in x, y, t) of a FITS image sequence, Oliver Pambos,
%10/11/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: extractVideo
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
%ffpath     (str)   FITS file path
%ffname     (str)   FITS file name
%frame_lo   (int)   first frame of subset of images to extract
%frame_hi   (int)   final frame of subset of images to extract
%x_lo       (vec)   pixel position of left edge of the ROI to extract
%x_hi       (vec)   pixel position of right edge of the ROI to extract
%y_lo       (vec)   pixel position of top edge of the ROI to extract (img coords are inverted in y)
%y_hi       (vec)   pixel position of bottom edge of the ROI to extract
%
%Output
%------
%video      (mat)   XxYxN matrix containing a series of N frames of video of the ROI
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%matlab.io.fits package reqiured for handling FITS files

    import matlab.io.*
    fptr = fits.openFile(char(fullfile(ffpath,ffname)));    %17/06/2022: added char() here to eliminate a bug
    video = fits.readImg(fptr, [y_lo x_lo frame_lo], [y_hi x_hi frame_hi]);
    fits.closeFile(fptr);
    
end

