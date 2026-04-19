function [frame_rate, frames_per_file, frame_offsets, success] = computeFrameOffsets(ffPath, ffFile)
%Compute frame offsets, and extract metadata from fluorescence videos,
%18/12/2025.
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
%This is historical code moved into this external f'n during
%refactorisation to improve modularity, as this is now required to be
%called from multiple places. Some tweaks and error catching introduced to
%make this more stable than the original version from ~2020.
%
%getFileExtension() has been moved locally here as all checks can be
%performed during frame offset computation regardless of input pipeline.
%
%Inputs
%------
%ffPath     (str)   absolute path to fluorescence video files
%ffFile     (str)   fluorsecence video filenames; takes the form of a cell
%                       array when multiple files are selected
%
%Output
%------
%frame_rate         (float) video recording frame rate extracted from
%                               metadata; currently only valid for FITS
%                               files through reading 'KCT' parameter
%frames_per_file    (int)   number of frames in each file
%frame_offsets      (vec)   vector containing the cumulative frame numbers
%                               of the first frame of each fluorescence
%                               video file; assumes all videos are
%                               consecutive
%success            (bool)  true if files are valid and offsets are
%                               successfully obtained; false otherwise
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%getFITSMeta()
%getFileExtension() - local to this .m file
    
    success = false;
    frame_rate = NaN;

    %number of video files
    if iscell(ffFile)
        N_videos = numel(ffFile);
    else
        N_videos = 1;
    end
    
    %init; moved outside
    frames_per_file     = zeros(N_videos, 1);
    frame_offsets       = zeros(N_videos, 1);
    frame_offsets(1)    = 0;
    
    %check the file extensions are consistent; if so get the extension
    [file_ext, consistent] = getFileExtension(ffFile);
    
    %return if filenames are inconsistent
    if ~consistent
        warning("File extensions of the selected fluorescence video files are inconsistent.");
        success = false;
        return;
    end
    
    %handle the other tiff extension
    file_ext = lower(string(file_ext));
    if file_ext == ".tiff"
        file_ext = ".tif";
    end
    
    %load video files
    try
        switch file_ext
            case ".fits"
                %obtain frame rate from KCT value in FITS file header
                if N_videos > 1
                    frame_rate = 1/str2double(getFITSMeta(string(ffFile(1)), ffPath, 'KCT'));
                else
                    frame_rate = 1/str2double(getFITSMeta(string(ffFile), ffPath, 'KCT'));
                end
                
                %build frame offset index for all FITS files
                if N_videos > 1
                    h_offset_waitbar = waitbar(0, "Computing temporal offsets for video files....");
                    set(h_offset_waitbar, 'WindowStyle', 'modal');
                    
                    for ii = 1:N_videos
                        waitbar(ii/N_videos, h_offset_waitbar, ...
                            sprintf('Computing temporal offsets for video file C %d/%d', ii, N_videos));
                
                        frames_per_file(ii) = str2double(getFITSMeta(string(ffFile(ii)), ffPath, 'NAXIS3'));
                    end
                    frame_offsets = [0; cumsum(frames_per_file(1:end-1))];
                    close(h_offset_waitbar)
                
                else
                    %single FITS file (still store frames_per_file for params consistency)
                    frames_per_file(1) = str2double(getFITSMeta(string(ffFile), ffPath, 'NAXIS3'));
                end
                
            case ".tif"
                % << future handling of TIF metadata using imfinfo() >>
                
                %if there are multiple files
                if N_videos > 1
                    h_offset_waitbar = waitbar(0, "Computing temporal offsets for video files....");
                    set(h_offset_waitbar, 'WindowStyle', 'modal');
                    for ii = 1:N_videos
                        waitbar(ii/N_videos, h_offset_waitbar, sprintf('Computing temporal offsets for video file %d/%d', ii, N_videos));
                        info = imfinfo(fullfile(ffPath, ffFile{ii}));
                        frames_per_file(ii) = numel(info); %number of frames in the current TIF file
                        
                        %for the first file, the offset is already set to 0
                        if ii > 1
                            %update frame offsets for subsequent files
                            frame_offsets(ii) = frame_offsets(ii-1) + frames_per_file(ii-1);
                        end
                    end
                    close(h_offset_waitbar);
                else
                    info = imfinfo(fullfile(ffPath, ffFile));
                    frames_per_file(1) = numel(info);
                end
                
            otherwise
                warning("Unsupported fluorescence video type: %s", string(file_ext));
                return;
        end
        
        success = true;
        
    catch ME
        warning(ME.identifier, "Failed to compute frame offsets: %s", ME.message);
        success = false;
    end
end


function [file_ext, consistent] = getFileExtension(ffFile)
%Extracts video file extension, and identifies inconsistency when multiple
%are present, 28/02/2024.
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
%This local helper function is moved from the earlier implementation in
%prepData().
%
%Inputs
%------
%ffFile     (str)   fluorsecence video filenames; takes the form of a cell
%                       array when multiple files are selected
%
%Output
%------
%file_ext   (str)   file extension of all video files used
%consistent (bool)  true if all file extensions are consistent; false if
%                       they differ
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    consistent  = true;
    
    %if multiple files are present
    if iscell(ffFile)
        [~, ~, file_ext] = fileparts(ffFile{1});
        
        %check remaining filenames for consistency
        for ii = 2:numel(ffFile)
            [~, ~, current_ext] = fileparts(ffFile{ii});
            if ~strcmpi(file_ext, current_ext)
                consistent = false;
                break;
            end
        end
    else
        [~, ~, file_ext] = fileparts(ffFile);
    end
end