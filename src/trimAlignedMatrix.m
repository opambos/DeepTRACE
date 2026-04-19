function [trimmed_mat, trimmed_t] = trimAlignedMatrix(aligned_mat, t)
%Strip the zeros from either side of the matrices of aligned events,
%25/05/2023.
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
