function [events] = getStateExits(mol, state)
%%Extracts all of the entrances from a labelled molecule matrix for a given
%state, and returns the events, Oliver Pambos, 25/05/2023.
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
%This code scans through a labelled single molecule matrix, which contains
%a large number of features, the last of which is the state label. This
%code is agnostic as to the source of the labelling.
%
%Procedure
%When start of state is found write start point to matrix (col 1)
%When transition to another state is found, write this point to matrix (col 2)
%When end of that state (or end of molecule) is found, write this point to matrix (col 3)
%If the end of the non-state-of-interest is found before the end of the molecule,
%then reset all vars and continue searching.
%
%Input
%-----
%mol    (mat)   labelled single molecule data, rows are localisations, columns
%                   are features, except final column which is state label
%state  (int)   state of interest
%
%Output
%------
%events (mat)   the events present in the molecule; rows are events,
%                   col 1: row number of start of state of interest
%                   col 2: row numer of transition to next state (i.e. the exit)
%                   col 3: row number of end of next state, or end of mol
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %initialisation
    n_event = 1;
    events = [];

    %set state of interest bool
    if mol(1,end) == state
        events(1,1) = 1;
        SOI = true;
    else
        SOI = false;
    end
    
    for ii = 2:size(mol,1)
        %if it's an exit
        if SOI == true && mol(ii,end) ~= state
            SOI = false;
            events(n_event,2) = ii;
            if ii == size(mol,1)
                events(n_event,3) = ii;
            end

        %if it's a transition from a non-state back to a new state of interest, and it's not the final step
        elseif SOI == false && mol(ii,end) == state
            if ~isempty(events)
                events(n_event,3) = ii - 1;
                n_event = n_event + 1;
            end
            %assuming it's not the final localisation
            if ii < size(mol,1)
                events(n_event,1) = ii;
            end
            SOI = true;
        
        %if it's a continuation of the non-interesting state and the final step in the trajectory
        elseif SOI == false && mol(ii,end) ~= state && ii == size(mol,1) && ~isempty(events)
            events(n_event,3) = ii;
        
        %if end of molecule is reached before a new exit is found, then delete the current entry
        elseif SOI == true && mol(ii,end) == state && ii == size(mol,1) && ~isempty(events)
            events(end,:) = [];
        end
    end
end