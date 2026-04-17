function [feature_data, class_data] = concatTracks(track_data)
%Concatenate all tracks into a single matrix, Oliver Pambos, 12/12/2024.
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