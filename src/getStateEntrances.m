function [events] = getStateEntrances(mol, state)
%Extracts all of the exits from a labelled molecule matrix for a given
%state, and returns the events, 26/05/2023.
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
%This code works by flipping the molecule's dataset, then running
%getStateExits(), on the reversed molecule, and then flipping the result.
%Doing so simplifies the code.
%
%Inputs
%------
%mol    (mat)   labelled molecule data, rows are localisations, columns
%                   are features, except final column which is the state label
%state  (int)   ID associated with the state of interest
%
%Output
%------
%events (mat)   the events present in the molecule, rows are events
%                   col 1: row number of start of state of interest
%                   col 2: row numer of transition to next state (i.e. the exit)
%                   col 3: row number of end of next state, or end of mol
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%getStateExits()
    
    mol = flipud(mol);
    events = getStateExits(mol, state);
    if isempty(events)
        return;
    end
    events = ((events - size(mol,1)/2).*-1) + size(mol,1)/2 + 1;
    events(:,2) = events(:,2) + 1;  %accounts for the fact that col 2 is on the wrong side of the transition (entrances vs exits)
    events = fliplr(events);
    events = flipud(events);        %there is no need to replace these operations with rot90(events,2) as suggested
end