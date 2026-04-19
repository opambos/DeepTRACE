function [step_sizes] = computeStepSizeProfile(movie_data, N_lim, h_axes)
%Compile a histogram of steps from all tracks in original data, 19/12/2021.
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
%movie_data     (struct)    main struct (originally derived from LoColi)
%N_lim          (int)       maximum number of steps to take from each track
%                               tracks are truncated to this number, use
%                               zero or a -ve number to prevent truncation
%
%Output
%------
%step_sizes     (vec)       column vector containing all step sizes in data
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %pre-allocate step_sizes
    N_mol = 0;
    for ii = 1:size(movie_data.cellROI_data,1)
        if ~isempty(movie_data.cellROI_data(ii).tracks)
            N_mol = N_mol + size(unique(movie_data.cellROI_data(ii).tracks(:,4)),1);
        end
    end
    step_sizes = zeros(N_mol,1);
    
    idx = 1;
    %loop over cells
    for ii = 1:size(movie_data.cellROI_data,1)
        if ~isempty(movie_data.cellROI_data(ii).tracks)
            tracklist = unique(movie_data.cellROI_data(ii).tracks(:,4));
            %loop over all tracks in cell
            for jj = 1:size(tracklist,1)
                track = movie_data.cellROI_data(ii).tracks(movie_data.cellROI_data(ii).tracks(:,4) == tracklist(jj), 1:2);
                
                if size(track,1)-1 < N_lim || N_lim < 1
                    %if track has fewer than N_lim steps, keep everything
                    distance = zeros(size(track,1) - 1, 1);
                    for kk = 1:size(track,1)-1
                        distance(kk,1) = pdist([track(kk,1:2);track(kk+1,1:2)]);
                    end
                    idx = idx + size(track,1) - 1;
                elseif N_lim == 1
                    %if just keeping first step
                    distance = pdist([track(1,1:2);track(2,1:2)]);
                    idx = idx + 1;
                else
                    %if track had more than N_lim steps, only keep the first N_lim steps
                    distance = zeros(N_lim, 1);
                    for kk = 1:N_lim
                        distance(kk,1) = pdist([track(kk,1:2);track(kk+1,1:2)]);
                    end
                    idx = idx + N_lim;
                end
                step_sizes(idx - size(distance,1) : idx - 1,1) = distance;
            end
        end
    end
    
    %scale steps to nm
    step_sizes = step_sizes .* movie_data.params.px_scale;
    
    %plot the histogram
    h = histogram(h_axes, step_sizes);
    h.FaceColor = 'black';
    h.EdgeColor = 'white';
    h.LineWidth = 2;
    h_axes.YLim = [0 ceil(max(h.Values) * 1.1)];
    h_axes.XLim = [0 max(h.BinEdges)];
    xlabel(h_axes, 'Step size (nm)'); ylabel(h_axes, 'Frequency');
    title(h_axes, 'All step sizes present in dataset');
    box(h_axes, 'on');
end