function [dist] = findEuclidDist(pt_1, pt_2)
%Find Euclidean distance, from Cluster Tracker, 08/02/2018.
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
%This function simply applies pythagoras' theorem to find the Euclidean
%distance between two points.
%
%Inputs
%------
%pt_1   (vec)   row vector [x y] for the first point
%pt_2   (vec)   row vector [x y] for the second point
%
%Outputs
%-------
%data   distance between two input points
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None

    dist = sqrt((pt_2(1) - pt_1(1))^2 + (pt_2(2) - pt_1(2))^2);
end
