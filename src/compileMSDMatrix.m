function [msd_result] = compileMSDMatrix(track, t_interframe)
%Compiles matrix of mean square displacements for a single track,
%03/07/2019.
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
%Simple MSD matrix compiler that can be used by external functions to
%produce diffusion coefficients and diffusion histograms.
%
%This function outputs both the averaged and non-averaged squared Euclidean
%distances together with the number of entries used for each lag time in
%order to aid different methods of aggregating statistics in external f'ns.
%Zeros are intentionally left in MSD matrix to aid aggregation of data from
%many trajectories.
%
%Inputs
%------
%track          (mat)   Nx3 matrix, trajectory of a single molecule composed of N localisations,
%                           columns are,
%                               1. x
%                               2. y
%                               3. frame number (do not have to be contiguous)
%t_interframe   (float) time interval between frames in seconds
%
%Output
%------
%msd_result     (mat)   matrix containing MSD values with respective time lags
%                           columns are,
%                               1. sum of squared Euclidean distances from all steps of given lag time, units are input units for (x,y) squared
%                               2. number of entries collected
%                               3. lag time in seconds
%                               4. mean squared Euclidean distance for given lag time across this trajectory, units are input units for (x,y) squared
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %remove track number offset and initialise results matrix
    track(:,3) = track(:,3) - min(track(:,3)) + 1;
    msd_result = zeros(max(track(:,3)), 2);
    
    %loop over all pairs of localisations track (all possible time delays)
    for ii = 1:size(track, 1)
        for jj = ii+1:size(track, 1)
            delta_frame = track(jj, 3) - track(ii, 3);
            
            %if its not the same localisation, compute the distance and update the results patrix
            if delta_frame > 0
                distance_sq = pdist([track(ii, 1:2); track(jj, 1:2)], 'squaredeuclidean');
                msd_result(delta_frame, 1) = msd_result(delta_frame, 1) + distance_sq;
                msd_result(delta_frame, 2) = msd_result(delta_frame, 2) + 1;
            end
        end
    end
    
    %calculating mean for each time lag
    valid_idx = msd_result(:, 2) > 0;
    msd_result(valid_idx, 4) = msd_result(valid_idx, 1) ./ msd_result(valid_idx, 2);
    
    %produce a third column containing the lag time
    msd_result(:,3) = (1:size(msd_result,1))' .* t_interframe;
end