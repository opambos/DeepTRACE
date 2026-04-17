function [idx_file, file_frame] = findFrame(frame_offsets, global_frame)
%Locates the correct file and frame from the global frame number, Oliver
%Pambos, 12/11/2020.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
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
%global_frame   (int)       frame number (from concatenated files) to find
%
%Outputs
%-------
%idx_file       (int)       index of FITS file containing requested frame
%file_frame     (int)       frame number within FITS file
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    idx_file = max(find(frame_offsets < global_frame));
    file_frame = global_frame - frame_offsets(idx_file);
    
end

