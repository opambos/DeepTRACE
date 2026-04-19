function [feature_data, class_data] = concatTracks(track_data)
%Concatenate all tracks into a single matrix, 12/12/2024.
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
%This function is extremely inefficient, and needs to be reworked with
%pre-allocation.
%
%Inputs
%------
%track_data (cell)  cell array of tracks, where each cell contains a struct
%                       with a matrix named '.Mol' of dimensions Ax(B+1)
%                       where A is the number of localisations and B is the
%                       number of features; the final column containing the
%                       assigned class ID
%
%Output
%------
%feature_data       (mat)   NxM matrix of all all feature data from all
%                               tracks concatenated into a single matrix
%class_data         (vec)   Nx1 column vector of all class IDs associated
%                               with feature data in combined_features from
%                               all tracks in the dataset
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    feature_data    = [];
    class_data      = [];
    
    for ii = 1:numel(track_data)
        curr_track      = track_data{ii, 1}.Mol;
        feature_data    = [feature_data; curr_track(:, 1:end-1)];
        class_data      = [class_data; curr_track(:, end)];
    end
end