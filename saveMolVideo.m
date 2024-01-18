function [video] = saveMolVideo(video, frame_rate, filetype, pathname, overlay, overlay_pc, dr_mode, save_to_disk)
%Saves a video of a molecule with BF overlay, Oliver Pambos, 10/11/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: saveMolVideo
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
%The output format is a looping gif video. This is saved relative to the
%current project path defined as ffPath inside the movie_data.params
%substruct. This subroutine can also run without saving a video to disk in
%order to either display the video to the user without saving, or to
%combine the fluorescence and inverted brightfield data and passed to
%another function for further use.
%
%Note that dynamic range adjustments are applied to the fluorescence video
%by illustrateMol() prior to passing to this function.
%
%Inputs
%------
%video          (mat)       XxYxN image sequence of N frames (fluorescence video)
%frame_rate     (double)    frames per second of output video
%filetype       (str)       'gif' for .gif output; currently only gif video is implemented
%pathname       (str)       full path, and filename, of output file - to avoid saving the file keep this as ~, in this case the function just returns the video stack
%overlay        (mat)       single brightfield frame to overlay - set to 0 if unused
%overlay_pc     (double)    intensity (as a %) of overlay
%dr_mode        (string)    ('auto' or 'manual') determines whether to automatically assign the dynamic range of the image based on max and min values in stack
%save_to_disk   (int)       0 or 1 depending on whether the video is saved to disk
%
%Output
%------
%video          (mat)       XxYxN image sequence of N frames consisting of fluorescence video combined with inverted brightfield overlay
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %note overlays are now stored as uint16, and need rescaling, then conversion to uint8 before using here
    video = video.*255;
    video = double(video);
    overlay = double(overlay);
    
    %combine all frames with overlay
    if size(overlay) ~= [1 1]
        scale_factor = (max(max(max(double(video)))) / max(max(double(overlay)))) * (overlay_pc/100);
        overlay         = overlay .* scale_factor;
        
        %loop over all video frames, and combine with re-scaled overlay
        for i = 1:size(video, 3)
            video(:,:,i) = video(:,:,i) + overlay;
        end
    end
    
    video = mat2gray(video);
    
    %save video
    if save_to_disk == 1
        if strcmp(filetype,'gif') && exist('pathname', 'var')
                video = video .*255;
                video = uint8(video);
            imwrite(video(:,:,1), pathname, 'Loopcount', inf, 'DelayTime', 1/frame_rate);
            
            for i = 2:size(video,3)
              imwrite(video(:,:,i), pathname, 'WriteMode', 'append', 'DelayTime', 1/frame_rate); 
            end

            % <further filetypes here if required>
        else
            disp('Error in saveMolVideo: unknown filetype');
        end
    else
        video = video .*255;
        video = uint8(video);
    end
    
end

