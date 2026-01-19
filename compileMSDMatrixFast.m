function [msd_result] = compileMSDMatrixFast(track, t_interframe, max_lag)
%A faster version of compileMSDMatrix which compiles matrix of mean square
%displacements for a single track only for steps used in D* calculation,
%Oliver Pambos, 09/03/2024.
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
%Simple MSD matrix compiler that can be used by external functions to
%produce diffusion coefficients and diffusion histograms.
%
%This function outputs both the averaged and non-averaged squared Euclidean
%distances together with the number of entries used for each lag time in
%order to aid different methods of aggregating statistics in external f'ns.
%Zeros are intentionally left in MSD matrix to aid aggregation of data from
%many trajectories.
%
%This faster version of compileMSDMatrix() only computes step sizes at lag
%times up to max_lag, which ensures calculations are only performed for lag
%times used in the computation of diffusion coefficient (D) in the calling
%function. It is essential that the calling function correctly assigns the
%input parameter max_lag consistent with the calculation being performed.
%
%As with compileMSDMatrix() this function is robust against molecular
%blinking events.
%
%Inputs
%------
%track          (mat)   Nx3 matrix, trajectory of a single molecule composed of N localisations,
%                           columns are,
%                               1. x
%                               2. y
%                               3. frame number (do not have to be contiguous)
%t_interframe   (float) time interval between frames in seconds
%max_lag        (int)   maximum lag time to compute (in frames)
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
    
    %initialise results matrix
    msd_result = zeros(max_lag, 2);
    
    %loop over all pairs of localisations in track (all possible time delays)
    for ii = 1:size(track, 1)
        for jj = ii+1:size(track, 1)
            delta_frame = track(jj, 3) - track(ii, 3);
            
            %if lag time exceeds range, stop computing further lag times for loc ii, and move to next loc
            if delta_frame > max_lag
                break;
            end
            %else if the lag time is relevant, and ii and jj are different, compute squared Euclidean distance, and add to MSD matrix
            distance_sq = sum((track(ii, 1:2) - track(jj, 1:2)).^2);
            msd_result(delta_frame, 1) = msd_result(delta_frame, 1) + distance_sq;
            msd_result(delta_frame, 2) = msd_result(delta_frame, 2) + 1;
        end
    end
    
    %calculating mean for each time lag
    valid_idx = msd_result(:, 2) > 0;
    msd_result(valid_idx, 4) = msd_result(valid_idx, 1) ./ msd_result(valid_idx, 2);
    
    %produce a third column containing the lag time
    msd_result(:,3) = (1:size(msd_result,1))' .* t_interframe;
end