function [video] = extractVideo(ffpath, ffname, frame_lo, frame_hi, x_lo, x_hi, y_lo, y_hi)
%Extracts a section (in x, y, t) of a video image sequence, 10/11/2020.
%
%Author: Oliver J. Pambos, Department of Physics, University of Oxford, UK
%(oliver.pambos@physics.ox.ac.uk).
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed by Oliver J. Pambos, and is
%distributed as part of the single-molecule track analysis software
%DeepTRACE.
%
%For citation of this work, refer to:
%
%   Pambos et al., Commun Biol (2026)
%   https://doi.org/10.1038/s42003-026-09899-y
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For license and attribution terms, see the LICENSE and NOTICE files.
%
%Copyright 2022-2026 Oliver J. Pambos
%
%Licensed under the Apache License, Version 2.0 (the "License");
%you may not use this file except in compliance with the License.
%You may obtain a copy of the License at
%
%   http://www.apache.org/licenses/LICENSE-2.0
%
%Unless required by applicable law or agreed to in writing, software
%distributed under the License is distributed on an "AS IS" BASIS,
%WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%See the License for the specific language governing permissions and
%limitations under the License.
%
%
%DESIGN AND CONTEXT
%This function handles cropping of video stacks in both FITS and TIF/TIFF
%formats. For FITS files, the performance is optimised for FITS fils as the
%function only extracts the specified ROI, and performs extraction across
%the entire stack with a single call. This approach improves processing
%speed and minimizes memory usage.
%
%However, for TIF/TIFF files, it accesses only the relevant frames but
%requires the entire frame to be read into memory before ROI extraction due
%to limitations in TIF format handling. This leads to potentially slower
%performance and more memory usage, particularly when using the image size
%is much larger than the ROI.
%
%Note also that it was necessary to suppress the warning
%'imageio:tiffutils:libtiffWarning'. As it is unclear how this impacts
%performance, if this function is called repetitively it would be best to
%move the warning suppression code to encapsulate the repetitive external
%call.
%
%Inputs
%------
%ffpath     (str)   video file path
%ffname     (str)   video file name
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
    
    %extract file extension
    [~, ~, ext] = fileparts(ffname);
    ext = lower(string(ext));
    if strcmp(ext, ".tif") || strcmp(ext, ".tiff")
        file_type = ".tif";
    else
        file_type = ext;
    end
    
    video = [];
    
    %extract cropped region of video
    switch file_type
        case ".fits"
            import matlab.io.*
            fptr = fits.openFile(char(fullfile(ffpath,ffname)));    %17/06/2022: char() as this can be passed as a cell array
            video = fits.readImg(fptr, [y_lo x_lo frame_lo], [y_hi x_hi frame_hi]);
            fits.closeFile(fptr);
            
        case ".tif"
            tif_meta = imfinfo(char(fullfile(ffpath, ffname)));
            N_frames = numel(tif_meta);
            
            %pre-allocate
            video = zeros(y_hi-y_lo+1, x_hi-x_lo+1, min(frame_hi, N_frames)-frame_lo+1, 'uint16');
            
            %suppress warning
            warning('off', 'imageio:tiffutils:libtiffWarning');
            
            t = Tiff(char(fullfile(ffpath, ffname)), 'r');
            
            %loop over frames
            for ii = frame_lo:frame_hi
                if ii > N_frames
                    break;
                end
                setDirectory(t, ii);
                tempImg = read(t);
                %extract ROI for current frame
                video(:, :, ii-frame_lo+1) = tempImg(y_lo:y_hi, x_lo:x_hi);
            end
            close(t);
            
            %re-enable warning
            warning('on', 'imageio:tiffutils:libtiffWarning');
            
        otherwise
            error('Unsupported file format');
    end 
end