function [state_times, state_proportions] = computeTotalStateTimes(movie_data)
%Computes the total time spent in each of the states, 20/07/2023.
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
%Cycles through all molecules keeping track of the total number of frames
%assigned to each state globally. This is then scaled by the inter-frame
%time to obtain the total residence time in each state. Molecules
%containing any unassigned or erroneous state IDs are ignored.
%
%This method currently introduces a negligible error in cases where the
%memory parameter is used because a step of two frames will be added to the
%statistics as one. This negligible effect may be handled in a future
%update by computing compute the time between frames - this would be less
%computationally efficient but could be achieved by introducing logic
%operating on a call to diff() which passes the 'time from start of track'
%column.
%
%Inputs
%------
%movie_data         (struct)    main data struct, inherited originally from LoColi
%label_type         (char)      location of substruct containing labelled data;
%                               currently restricted to 'VisuallyLabelled' as
%                               app is primarily used for manual 1D segmentation;
%                               future versions may re-introduce previously used
%                               changepoint-labelled and ML-labelled data as a 
%                               separate substruct;
%
%Outputs
%-------
%state_times        (vec)       row vector containing the total time spent in each state
%state_proportions  (vec)       row vector containing the proportion of the total observation time of all labelled molecules spent in each state
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_classes   = size(movie_data.params.class_names,1);
    state_times = zeros(1,N_classes);
    
    %loop over all molecules
    for ii = 1:size(movie_data.results.InsightData.LabelledMols,1)
        %check all labels are valid
        if all(movie_data.results.InsightData.LabelledMols{ii,1}.Mol(:,end) > 0 & movie_data.results.InsightData.LabelledMols{ii,1}.Mol(:,end) <= N_classes)
            %increment counters for each class
            for kk = 1:N_classes
                state_times(kk) = state_times(kk) + sum(movie_data.results.InsightData.LabelledMols{ii, 1}.Mol(:, end) == kk);
            end     
        end
    end
    
    %convert to seconds
    state_times = state_times ./ movie_data.params.frame_rate;

    %compute the fraction of time spent in each state
    state_proportions = state_times / sum(state_times);
end