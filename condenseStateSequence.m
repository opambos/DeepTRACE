function [condensed_state_sequence] = condenseStateSequence(track)
%Determines the class of event present in a track, Oliver Pambos,
%18/11/2020.
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
%This function takes in the refined state sequence of a track, and
%identifies the type of event(s) found.
%
%Input
%-----
%track                      (vec)   column vector of integers representing the state sequence of the track
%
%Output
%------
%condensed_state_sequence   (char)  event type, expressed as a series of integers in a char array
%                                   0:      no event present
%                                   1:      continuous event of lowest diffusion state
%                                   2:      continuous event of second diffusion state
%                                   N:      (where N is a positive integer) continuous event of diffusion state N
%                                   21:     fast-slow transition
%                                   12:     slow-fast transition
%                                   MN:     (where M and N are positive integers) transition from state M to state N (not currently supported)
%                                   212:    "full" event, fast-slow-fast
%                                   121:    slow-fast-slow event
%                                   MNM:    (M, N both positive integers) transition from state M to N to M (not currently supported)
%                                   >3 digits: multiple transition event
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    curr_state = track(1);
    if curr_state ~= 0
        condensed_state_sequence = num2str(curr_state);
    else
        condensed_state_sequence = '';
    end
    for i = 2:size(track,1)
        if track(i) ~= curr_state && track(i) ~= 0
            curr_state = track(i);
            condensed_state_sequence = strcat(condensed_state_sequence, num2str(curr_state));
        end
    end
    
    if strcmp(condensed_state_sequence,'')
        condensed_state_sequence = num2str(0);
    end
end