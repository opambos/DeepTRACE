function [movie_data] = genAllOverlays(movie_data, border, bitdepth)
%Generates a brightfield overlay for all cells, Oliver Pambos, 11/11/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genAllOverlays
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
%Generates an inverted overlay for all BF images, and saves it back to the
%main data struct in movie_data.cellROI_data(ii).overlay together with its
%offset movie_data.cellROI_data(ii).overlay_offset.
%
%Input
%-----
%movie_data     (struct)    main data struct
%buffer         (int)       size of border around the existing ROI
%bitdepth       (int)       bit depth of overlays produced
%
%Output
%------
%movie_data     (struct)    main data struct
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %normalise image to 0:1 and invert
    img = mat2gray(movie_data.brightfield_image);
    img = img .* (-1);
    img = img + 1;
    
    %convert image back to original bit depth
    if bitdepth == 8
        img = img*(2^8);
        img = uint8(img);
    elseif bitdepth == 16
        img = img*(2^16);
        img = uint16(img);
    else
        disp('Error in genAllOverlays: unknown bit depth');
    end
    
    %generate sub-image for each cell
    for ii = 1:size(movie_data.cellROI_data, 1)
        y_lo = floor(min(movie_data.cellROI_data(ii).ROIVertices(:,1)) - border);
        y_hi = ceil(max(movie_data.cellROI_data(ii).ROIVertices(:,1))  + border);
        
        x_lo = floor(min(movie_data.cellROI_data(ii).ROIVertices(:,2)) - border);
        x_hi = ceil(max(movie_data.cellROI_data(ii).ROIVertices(:,2))  + border);
        
        %ensuring ROI does not exceed edge of image - note that same must be done with fluor video
        if x_lo < 1
            x_lo = 1;
        end
        if x_hi > size(img,2)
            x_hi = size(img,2);
        end
        if y_lo < 1
            y_lo = 1;
        end
        if y_hi > size(img,1)
            y_hi = size(img,1);
        end
        
        movie_data.cellROI_data(ii).overlay = img(x_lo:x_hi, y_lo:y_hi);
        movie_data.cellROI_data(ii).overlay_offset = [x_lo y_lo];
    end
    
end

