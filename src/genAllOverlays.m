function [movie_data] = genAllOverlays(movie_data, border, bitdepth)
%Generates a brightfield overlay for all cells, 11/11/2020.
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
%Generates an inverted overlay for all reference images, and saves it back
%to the main data struct in movie_data.cellROI_data(ii).overlay together
%with its offset movie_data.cellROI_data(ii).overlay_offset.
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

    if isfield(movie_data.params, 'flipped') && movie_data.params.flipped
        img = flipud(img);
    end
    
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
        if x_hi > size(img,1)
            x_hi = size(img,1);
        end
        if y_lo < 1
            y_lo = 1;
        end
        if y_hi > size(img,2)
            y_hi = size(img,2);
        end
        
        movie_data.cellROI_data(ii).overlay = img(x_lo:x_hi, y_lo:y_hi);
        movie_data.cellROI_data(ii).overlay_offset = [x_lo y_lo];
    end
end