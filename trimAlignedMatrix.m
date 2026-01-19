function [trimmed_mat, trimmed_t] = trimAlignedMatrix(aligned_mat, t)
%Strip the zeros from either side of the matrices of aligned events,
%Oliver Pambos, 25/05/2023.
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
%
%Inputs
%------
%aligned_mat    (mat)   padded matrix consisting of aligned events; each row contains an individual event
%t              (vec)   row vector of time values relative to event; each entry corresponds to the associated column in aligned_mat
%
%Outputs
%-------
%trimmed_mat    (mat)   padded matrix consisting of aligned events, with padding removed from left and right sides
%trimmed_t      (vec)   row vector of time values relative to event; each entry corresponds to the associated column in trimmed_mat
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %find the first and last columns with non-zero elements
    first_nonzero_col = find(any(aligned_mat~=0, 1), 1, 'first');
    last_nonzero_col  = find(any(aligned_mat~=0, 1), 1, 'last');

    %trim the matrix and the corresponding row vector t
    trimmed_mat = aligned_mat(:, first_nonzero_col:last_nonzero_col);
    trimmed_t   = t(:, first_nonzero_col:last_nonzero_col);
end
