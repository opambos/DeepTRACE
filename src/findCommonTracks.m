function [common] = findCommonTracks(varargin)
%Finds the tracks in common between annotation sets, 05/07/2024.
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
%This code has been adapted from an earlier external tool used for data
%exploration of saved analysis files, and incorporated into the main GUI.
%
%
%Inputs
%------
%varargin   (cell)  variable number of input cell arrays, one for each set
%                       annotation source
%
%Output
%------
%common (mat)   Nx2 matrix of tracks that are common to all annotation
%                   datasets, columns are,
%                       col1: Cell ID
%                       col2: Mol ID
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if nargin < 2
        error('At least two sets of annotations are required');
    end
    
    common_keys = cell2mat(cellfun(@(x) [x.CellID, x.MolID], varargin{1}, 'UniformOutput', false));
    for ii = 2:nargin
        model_keys = cell2mat(cellfun(@(x) [x.CellID, x.MolID], varargin{ii}, 'UniformOutput', false));
        common_keys = intersect(common_keys, model_keys, 'rows');
    end
    common = common_keys;
end