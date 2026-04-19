function [data] = gatherEventHistogramData(app, class_number)
%Gather dwell time data for each event in the human annotated data based on
%user selections of which class to show, and what type of truncation to
%show, 29/10/2022.
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
%This function filters the appropriate extracted states matrix for a given
%class to compile histogram data based on truncation type. Filtering is
%performed based on logical comparison of left and right trucation values.
%
%Inputs
%------
%app            (handle)    main GUI handle, crucially this must contain
%                               the Nx6 extractedStates matrices
%class_number   (int)       number of the class/state for which to compile
%                               histogram data
%
%Output
%------
%data           (mat)       the extracted states matrix
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %retrieve the extracted states matrix for the requested class
    data = app.movie_data.results.InsightData.extractedStates{1, class_number};

    truncation = app.TruncationDropDown.Value;
    
    switch truncation
        case 'Singly-truncated'
            
            %keep the data which is either truncated left, or truncated right, but not both
            data = data(data(:,5) == 1 & data(:,6) == 0  |  data(:,5) == 0 & data(:,6) == 1, :);
            
        case 'Doubly-truncated'
            
            %keep data which is both left and right truncated
            data = data(data(:,5) == 1 & data(:,6) == 1, :);
            
        case 'All truncated'
            
            %keep the data which is either left truncated, right truncated, or (implicitly) both
            data = data(data(:,5)==1 | data(:,6)==1, :);
            
        case 'Full events'
            
            %keep the data which is neither left or right truncated
            data = data(data(:,5) == 0 & data(:,6) == 0, :);
            
        case 'All events'
            %do nothing, user will see all data
        otherwise
    end
end