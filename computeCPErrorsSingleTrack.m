function [cp_errors, state_transitions, N_unpaired_cps] = computeCPErrorsSingleTrack(gt_labels, pred_labels, max_cp_error, min_cp_sep)
%Find change point error between predicted labels and ground truth for a
%single track, Oliver Pambos, 17/07/2024.
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
%The changepoint error is the distance (in frames) between changepoints
%found in the ground truth, and the nearest changepoint of the same type
%(the same transition between classes) found in the annotations. Note that
%if there is a changepoint in the annotations that does not exist in the
%ground truth, this is not currently factored in the statistics.
%
%Inputs
%------
%gt_labels      (vec)   column vector of ground truth labels for a single
%                           track
%pred_labels    (vec)   column vector of annotations for a single track
%max_cp_error   (int)   maximum alloweable distance (in frames) between the
%                           ground truth and annotated labels for any
%                           changepoint
%min_cp_sep     (int)   minimum separation between any two changepoints,
%                           for the error in those changepoints to be
%                           computed
%
%Output
%------
%cp_errors          (vec)   column vector of changepoint errors for every
%                               changepoint in the ground truth track labels;
%                               this value is positive if the changepoint of
%                               the predicted annotations occurs earlier in
%                               time than the ground truth, and it is positive
%                               if the predicted changepoint occurs later in
%                               time than the ground truth.
%state_transitions  (mat)   Nx2 matrix where N has the same length as
%                               cp_errors; each row contains two values
%                               representing,
%                                   col 1: class before transition
%                                   col 2: class after transition
%N_unpaired_cps     (int)   number of unpaired changepoints in the current
%                               track; unpaired is defined as the annotated
%                               dataset not having an equivalent
%                               changepoint of the same type within
%                               min_cp_sep of the corresponding ground
%                               truth changepoint
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %find locations of all changepoints in ground truth and predictions
    gt_cp_indices   = find(diff(gt_labels) ~= 0);
    pred_cp_indices = find(diff(pred_labels) ~= 0);
    
    %this is intentionally not pre-allocated because this would result in the skipped changepoints registering as the pre-allocated value,
    %alternatives (e.g. more complex pre-allocation, or removal of individual datapoints) are less readable, more computationally intensive,
    %and more prone to human error in coding
    cp_errors           = [];
    state_transitions   = [];
    N_unpaired_cps      = 0;
    
    %loop over ground truth changepoints
    for ii = 1:numel(gt_cp_indices)
        %skip changepoint if it's within min_cp_sep of either the next or previous changepoint
        if (ii < numel(gt_cp_indices) && (gt_cp_indices(ii + 1) - gt_cp_indices(ii)) < min_cp_sep) || ...
           (ii > 1 && (gt_cp_indices(ii) - gt_cp_indices(ii - 1)) < min_cp_sep)
            continue;
        end
        
        idx_gt_cp = gt_cp_indices(ii);
        
        %skip changepoint if it is last index to avoid indexing out of bounds
        if idx_gt_cp >= numel(gt_labels)
            continue;
        end
        
        gt_class_before = gt_labels(idx_gt_cp);
        gt_class_after  = gt_labels(idx_gt_cp + 1);
        
        min_cp_error     = inf;
        closest_cp_found = false;
        
        %loop over predicted changepoints to find closest match
        for jj = 1:numel(pred_cp_indices)
            idx_pred_cp = pred_cp_indices(jj);
            
            %skip predicted changepoint if it is the last point in track to avoid indexing out of bounds
            if idx_pred_cp >= numel(pred_labels)
                continue;
            end
            
            %check if changepoint matches transition type
            if pred_labels(idx_pred_cp) == gt_class_before && pred_labels(idx_pred_cp + 1) == gt_class_after
                %calc dist between changepoints
                cp_distance = idx_pred_cp - idx_gt_cp;
                
                %if it is closest matching changepoint, update the minimum error
                if abs(cp_distance) < abs(min_cp_error)
                    min_cp_error     = cp_distance;
                    closest_cp_found = true;
                end
            end
        end
        
        %if match was found, and is within max_cp_error, log the error, otherwise log it as unpaired
        if closest_cp_found && abs(min_cp_error) <= abs(max_cp_error)
            cp_errors           = [cp_errors; min_cp_error];
            state_transitions   = [state_transitions; gt_class_before, gt_class_after];
        else
            N_unpaired_cps = N_unpaired_cps + 1;
            
            %update to changepoint error definition to cap max distance
            cp_errors = [cp_errors; max_cp_error];
            state_transitions = [state_transitions; gt_class_before, gt_class_after];
        end
    end
end