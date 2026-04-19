function [] = readLims(h_array)
%Update the plot limits entry boxes for the MLDataView plot, 02/05/2023.
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
%h_array    (cell)  array of object handles for 1. MLDataView
%                                               2. X lower limit
%                                               3. X upper limit
%                                               4. Y lower limit
%                                               5. Y upper limit
%                                               6. Z lower limit
%                                               7. Z upper limit
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    h_axes = h_array{1};
    
    %obtain the current limits from the UIAxes
    x_limits = xlim(h_axes);
    y_limits = ylim(h_axes);
    z_limits = zlim(h_axes);
    
    %update the GUI components for the plot limits of MLDataView
    h_array{2}.Value = x_limits(1);
    h_array{3}.Value = x_limits(2);
    
    h_array{4}.Value = y_limits(1);
    h_array{5}.Value = y_limits(2);
    
    h_array{6}.Value = z_limits(1);
    h_array{7}.Value = z_limits(2);
end