function [d_min] = findPointToMeshDist(x, y, mesh)
%Find distance between a single point and a cell mesh, 03/04/2020.
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
%Part of findCellBoundary in my SuperCell software from early 2020.
%This code finds the minimum distance between a cell mesh defined by a
%series of vertices, and a single point
%
%Note that the mesh used here is reformattted from a microbeTracker mesh to
%an Nx2 matrix of (x,y) coordinates which links back to its start point.
%Manipulation of this mesh is performed in computeLocMemDists() such that
%the matrix manipulation occurs only once for each cell/mesh in order to
%minimise computational overhead.
%
%Inputs
%------
%x      (float)     x position of point
%y      (float)     y position of point
%mesh   (matrix)    series of vertices making up cell mesh reformatted as
%                       an Nx2 matrix of (x,y) coords for which the final
%                       step links back to the first, see note above
%
%%Output
%------
%d_min  (float)     minimum distance between the reference point (x,y) and
%                       the mesh including both vertices and connecting
%                       line segments
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findPointToLine()  - local to this .m file
    
    %error checking
    if size(mesh, 1) < 2
        disp('Error: cell mesh contains fewer than two vertices.');
        return;
    end
    
    %calculate minimum distance to first line to initialise variable
    d_min = findPointToLine(x, y, mesh(1,:), mesh(2,:));
    
    %loop over all remaining lines in mesh keeping track of smallest dist
    for ii = 2:size(mesh, 1) - 1
        if findPointToLine(x, y, mesh(ii,:), mesh(ii+1,:)) < d_min
            d_min = findPointToLine(x, y, mesh(ii,:), mesh(ii+1,:));
        end
    end
end


function [d] = findPointToLine(x, y, A, B)
%Find distance between a single point and a line, 03/04/2020.
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
%x      (float)     x position of point
%y      (float)     y position of point
%A      (vec)       row vector of [x y] coordinates for first point of line
%B      (vec)       row vector of [x y] coordinates for second point of line
%
%Output
%------
%d      (float)     distance of point to line
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    C = [x y];
    
    %find angles
    ABC = acos(((norm(B-C))^2 + (norm(A-B))^2 - (norm(A-C))^2) / (2 * norm(B-C) * norm(A-B)));
    BAC = acos(((norm(A-B))^2 + (norm(A-C))^2 - (norm(B-C))^2) / (2 * norm(A-B) * norm(A-C)));
    
    %test whether point falls to side of line
    if ABC < (pi/2) && BAC < (pi/2)
        %if point falls to the side of the line
        d = norm(det([A-B; A-[x y]]))/norm(A-B);
    else
        %find closest end point
        if norm(A-C) < norm(B-C)
            d = norm(A-C);
        else
            d = norm(B-C);
        end
    end
end