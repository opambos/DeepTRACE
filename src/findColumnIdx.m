function varargout = findColumnIdx(titles, varargin)
%Find the column index for an arbitrary number specified features, Oliver
%Pambos, 01/03/2024.
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
%Column index lookup is required to generalise the software to a wide
%variety of SMLM input data types, and also to eliminate hardcoding of
%imported and engineered features. This improves readability and robustness
%of code, and eliminates repetition.
%
%This function performs a lookup for specific features (column header
%strings) in the column reference cell array `titles` passed to the
%function. In the case of SMLM tracking data this reference list is stored
%in app.movie_data.params.column_titles.tracks. Column IDs are returns as
%positive integers when found, and as `0` when not found in the reference
%list.
%
%The function employs variable input and output arguments enabling a single
%call to resolve multiple column index assignments. This improves
%readability, and reduces repetitive calls.
%
%Example usage,
%[frame_col, stepsize_col] = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Frame', 'Step size (nm)')
%
%Inputs
%------
%titles     (cell)  a cell array of column titles, each containing a char
%                       array or string
%varargin   (cell)  variable number of input arguments, each a cell array
%                       or string to locate in the reference list `titles`
%
%Output
%------
%varargout  (int)   variable number of output arguments, each being a
%                       column ID for the respective input string; returns
%                       `0` when column is not found
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %pre-allocate outputs
    N_features = length(varargin);
    varargout = cell(1, N_features);
    
    %find indices
    for ii = 1:N_features
        feature = varargin{ii};
        idx = find(strcmp(titles, feature), 1, 'first');
        %return 0 if not found
        if isempty(idx)
            idx = 0;
        end
        varargout{ii} = idx;
    end
end