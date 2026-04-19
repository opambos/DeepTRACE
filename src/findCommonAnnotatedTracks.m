function [common] = findCommonAnnotatedTracks(all_labels, annotation_fields)
%Finds the completed track annotations that are common to multiple
%annotation sources, 12/08/2024.
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
%This function is an improvement of the findCommonTracks() function, which
%it calls, and then filters the results to ensure that all common tracks
%also contain fully annotated localisations. The original function has been
%left unmodified as it is used elsewhere.
%
%Inputs
%------
%all_labels         (struct)        struct of cell arrays where each cell
%                                       array contains an annotation
%                                       source, see calling function
%annotation_fields  (cell_array)    Nx1 cell array of char arrays, each of
%                                       which contains the char array of
%                                       the exact struct in
%                                       app.movie_data.results which
%                                       contains the annotation source data
%
%Output
%------
%common (mat)   Nx2 matrix of fully-annotated tracks that are common to all
%                   annotation sources, columns are,
%                       col1: Cell ID
%                       col2: Mol ID
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findCommonTracks()
    
    %find common tracks across multiple annotation fields
    varargin = cellfun(@(field) all_labels.(field), annotation_fields, 'UniformOutput', false);
    common = findCommonTracks(varargin{:});
    
    %loop over all annotation fields and check for '-1' in each track, eliminating those that are not fully annotated
    for ii = 1:numel(annotation_fields)
        cell_array  = all_labels.(annotation_fields{ii});
        cell_IDs    = cellfun(@(x) x.CellID, cell_array);
        mol_IDs     = cellfun(@(x) x.MolID, cell_array);
        
        %loop over each common track
        to_remove = false(size(common, 1), 1);
        for jj = 1:size(common, 1)
            %find corresponding entry
            idx = find(cell_IDs == common(jj, 1) & mol_IDs == common(jj, 2), 1);
            
            %if any Labels vector contains a -1, mark it for removal
            if ~isempty(idx) && any(cell_array{idx, 1}.Labels == -1)
                %to_remove(jj) = true;  %suppress this line to include partially-annotated tracks (e.g. from import of data processed by external models such as ResAnDi2 with finite input sequence length)
            end
        end
        
        %remove marked tracks, and move to next annotation source
        common(to_remove, :) = [];
    end
end