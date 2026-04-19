function [longitude, latitude, longitude_abs, latitude_abs, beyond_mesh] = convertToCellCoords(x, y, mesh, mesh_left, mesh_right, midline, contour_len)
%Convert a pair of (x,y) FOV coordinates to normalised cell coordinates,
%22/05/2024.
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
%This function provides a conversion of coordinates from the FOV frame to
%normalised and absolute cell coordinates to enable plotting of heatmaps,
%and cell projections, as well as training of models on cellular coordinates.
%
%The output cell coordinate system is positive for the left side of the
%cell (defined from pole 1 to pole 2), and negative for the right side.
%The origin of the coordinate system is at the cell centre, and normalised
%cell coordinates run from -0.5 to +0.5 in both longitude (long axis), and
%latitude (short axis).
%
%This function natively handles positions outside of the cell boundary.
%These cases occur when filtering is performed either by a native external
%pipeline such as LoColi, or when filtering is performed using the
%ROIVertices substruct which contains an expanded and downsampled version
%of the cell mesh.
%
%Identification of cell mesh side is performed using a simple polygon
%hittest using half of the cell mesh, bounded by the midline. This process
%is computationally intensive although typically only takes a couple of
%seconds to process a typical SMLM dataset. A future version may use a more
%computationally efficient approach of which there are many obvious
%candidates.
%
%There are potentially losses in accuracy that are the result of
%inaccuracies in the penultimate pair of mesh points next to each cell
%pole which results from the mesh construction from the active contour
%model of the microbeTracker and Oufti pipelines. As a result, a small
%number of datapoints extremely close to the cell poles may contain slight
%errors. This can be mitigated, as described in the header documentation,
%by passing the third and third-to-last points together with the final
%point into the function. Furthermore, latitude calculations are normalised
%by an average width of the final triangular polygone that make up the
%first and last segment of each half cell mesh.
%
%This function also handles extraordinarily rare scenaria in which some
%localisations miss the hittest against both sides of cell due the reasons
%described above, but also extend beyond the cell midline, such that the
%nearest point of the cell mesh is the cell pole. In such cases the
%algorithm computes the longitude and latitude by extending a virtual line
%from the cell pole, and projecting the line onto this. In order to be able
%to later filter out the points obtained in this way by calling functions
%the bool 'beyond_mesh' is returned from the function
%
%Note that consistency is required in unity between all input variables;
%the intention at the time of writing this code is that variables passed
%to function are in units of pixels.
%
%Inputs
%------
%x              (float) coordinate of point in field of view in pixels
%                           in x-axis
%y              (float) coordinate of point in field of view in pixels
%                           in y-axis
%mesh           (mat)   microbeTracker-formatted mesh (Nx4 matrix)
%                           containing points along both arms of the
%                           segmented cell boundary
%mesh_left      (mat)   Nx2 matrix containing the left hand arm of the
%                           cell mesh
%mesh_right     (mat)   Nx2 matrix containing the right hand arm of the
%                           cell mesh
%midline        (mat)   Nx2 matrix containing the midpoint between the
%                           pairs of vertices on each arm of the cell
%                           mesh
%contour_len    (float) total contour length along midline
%
%Output
%------
%longitude      (float) position along long cell axis in normalised
%                           cellular coordinates
%latitude       (float) position along short cell axis in normalised
%                           cellular coordinates
%longitude_abs  (float) raw contour length along the cell midline of the
%                           reference point projected onto the midline
%                           this is transformed such that the origin is
%                           at the midpoint of the midline
%latitude_abs   (float) absolute distance between reference point and its
%                           projection on the cell midline
%beyond_mesh    (bool)  returns 'true' if the cellular coordinates were
%                           computed from extrapolation beyond the pole
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findPointOnLine() - local to this .m file
%hitTestCellSides() - local to this .m file
%computeLatitude() - local to this .m file
%findCoordsBeyondPole() - local to this .m file
    
    %keep track of rare events where localisation extends beyond cell mesh
    beyond_mesh = false;
    
    %find the closest (projected) point on the cell midline, and its distance
    [closest_point, smallest_dist] = findPointOnLine(x, y, [midline(1, 1), midline(1, 2)], [midline(2, 1), midline(2, 2)]);
    closest_segment = 1;
    %loop over remaining points on midline
    for ii = 2:size(midline, 1) - 1
        [curr_point, curr_dist] = findPointOnLine(x, y, [midline(ii, 1), midline(ii, 2)], [midline(ii+1, 1), midline(ii+1, 2)]);
        if curr_dist < smallest_dist
            smallest_dist   = curr_dist;
            closest_point   = curr_point;
            closest_segment = ii;
        end
    end
    
    %construct a partial contour (up to the projected point)
    contour_up_to_point = [midline(1:closest_segment,:); closest_point];
    
    %measure the contour length up to the projected position to get the absolute longitudinal position
    longitude_abs = 0;
    for ii = 1:size(contour_up_to_point, 1) - 1
        longitude_abs = longitude_abs + pdist([contour_up_to_point(ii,:); contour_up_to_point(ii+1,:)]);
    end
    
    %normalise by the total contour length of the midline to obtain longitude
    longitude = longitude_abs/contour_len;
    
    %obtain polarity of latitude from hittest against each side of cell mesh
    side = hitTestCellSides(x, y, mesh, mesh_left, mesh_right);
    switch side
        case "left"
            D = mesh(closest_segment, 1:2);
            E = mesh(closest_segment + 1, 1:2);
        case "right"
            D = mesh(closest_segment, 3:4);
            E = mesh(closest_segment + 1, 3:4);
        otherwise
            % << error handling >>
    end
    
    %compute normalised latitude by measuring distance along line perpendicular from midline to edge of cell
    latitude = computeLatitude(closest_point, [x,y], D, E);
    
    switch side
        case "left"
            latitude_abs = smallest_dist;
        case "right"
            latitude_abs = smallest_dist * -1;
            latitude     = latitude * -1;
        otherwise
            % << error handling >>
    end
    
    %Handle end-point scenaria as described in the function header
    if latitude == inf || latitude == -inf || longitude <= 0
        beyond_mesh = true;

        %obtain the relevant two midline points
        A = midline(closest_segment, 1:2);
        B = midline(closest_segment+1, 1:2);

        if longitude == 1
            [A, B] = deal(B, A);
        end
        
        %compute distance projected along this virual line (longitude_abs) extending beyond the cell pole,
        %and the perpendicular distance from this line (latitude_abs)
        [longitude_abs, latitude_abs] = findCoordsBeyondPole(x, y, A, B);
        if strcmp(side, "right")
            latitude_abs = -latitude_abs;
        end
        latitude     = latitude_abs / ((norm(D - A) + norm(E - B))/2);
        
        %longitudinal distance is negative if it is before the first pole
        if closest_segment == 1
            longitude_abs = (-1) * longitude_abs;
        elseif closest_segment == size(midline, 1) - 1
            longitude_abs = longitude_abs + contour_len;
        end
        
        %normalise
        longitude = longitude_abs / contour_len;
    end
    
    %translatate longitude to be zero at cell centre; placing origin of coordinate system at cell centre
    longitude       = longitude - 0.5;
    longitude_abs   = longitude_abs - (contour_len/2);
    
    %rescale normalised latitude range to (-0.5 : +0.5) consistient with longitude
    latitude = latitude / 2;
end


function [projected_point, d] = findPointOnLine(x, y, A, B)
%Find the closest point on a line segment AB to a reference point, and find
%this minimum distance, 23/05/2024.
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
%Projected_point here is the closest point on the line AB of the point
%(x,y); it is essentially the projected point on the line. If it is not to
%the side of the line AB, then the projected point is actually the closest
%of its endpoints A or B.
%
%Inputs
%------
%x  (float) x-coordinate of reference point
%y  (float) y-coordinate of reference point
%A  (float) [x, y] coordinates of first point of the midline segment
%               closest to the reference point
%B  (float) [x, y] coordinates of second point of the midline segment
%               closest to the reference point
%
%Output
%------
%projected_point    (float) closest point on the current midline segment to
%                               the reference point [x,y]; this can also be
%                               thought of as the projection of [x,y] onto
%                               the segment AB.
%d                  (float) distance between [x,y] and projected_point,
%                               this is effectively absolute latitude
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    C = [x y];
    
    %calc angles using law of cosines
    ABC = acos(((norm(B-C))^2 + (norm(A-B))^2 - (norm(A-C))^2) / (2 * norm(B-C) * norm(A-B)));
    BAC = acos(((norm(A-B))^2 + (norm(A-C))^2 - (norm(B-C))^2) / (2 * norm(A-B) * norm(A-C)));
    
    %check whether point C falls within region adjacent to segment AB
    if ABC < (pi/2) && BAC < (pi/2)
        %calculate projection of point C onto line AB
        t = dot(B-A, C-A) / dot(B-A, B-A);
        %ensure projection is restricted to between 0 and 1
        t = max(0, min(t, 1));
        %calculate closest point based on t
        projected_point = A + t * (B - A);
        %calc distance from C to the closest point
        d = norm(C - projected_point);
        
    else
        %if it's not adjacent to segment AB, choose the nearest endpoint
        if norm(A-C) < norm(B-C)
            projected_point = A;
            d = norm(A-C);
        else
            projected_point = B;
            d = norm(B-C);
        end
    end
end


function [side] = hitTestCellSides(x, y, mesh, mesh_left, mesh_right)
%Perform a hittest on each half of the cell defined by the mesh bounded
%midline, 23/05/2024.
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
%This function uses a simple hittest of the two halves of the cell mesh to
%identify which side to assign the reference point. This approach may be
%replaced with a more computationally efficient method in future versions.
%Performance of the simple method shown here could also be improved in a
%simple first pass through a number of approaches, for example via
%downsampling of the mesh. Note that I have implemented angle-dependent
%mesh downsampling elsewhere in the codebase which could be implemented
%on a cell-by-cell basis in the calling funciton outside of this .m file.
%
%Inputs
%------
%x          (float) x-coordinate of reference point
%y          (float) y-coordinate of reference point
%mesh       (mat)   microbeTracker-formatted mesh (Nx4 matrix) containing
%                   points along both arms of the segmented cell boundary
%mesh_left  (mat)   Nx2 matrix containing the left hand arm of the cell
%                       mesh
%mesh_right (mat)   Nx2 matrix containing the right hand arm of the cell
%                       mesh
%
%Output
%------
%side       (str)   result of hittest, states are either "left" or "right"
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findPointOnLine() - local to this .m file
    
    %hittest the two halves of the mesh
    if inpolygon(x, y, mesh_left(:,1), mesh_left(:,2))
        side = "left";
    elseif inpolygon(x, y, mesh_right(:,1), mesh_right(:,2))
        side = "right";
    else
        %if both hittests fail use whichever mesh boundary is closest to the point
        
        %find the closest point on each arm of boundary
        [~, closest_left]   = findPointOnLine(x, y, mesh(1,1:2), mesh(2,1:2));
        [~, closest_right]  = findPointOnLine(x, y, mesh(1,3:4), mesh(2,3:4));
        for ii = 2:size(mesh,1) - 1
            [curr_left, ~] = findPointOnLine(x, y, mesh(ii,1:2), mesh(ii+1,1:2));
            if curr_left < closest_left
                closest_left = curr_left;
            end

            curr_right = findPointOnLine(x, y, mesh(ii,3:4), mesh(ii+1,3:4));
            if curr_right < closest_right
                closest_right = curr_right;
            end
        end
        
        %compute which arm is closest
        if closest_left < closest_right
            side = "left";
        else
            side = "right";
        end
    end
end


function [latitude] = computeLatitude(t, C, D, E)
%Compute the normalised lattitude by measuring the fractional distance
%along a virtual line that connects the projection of the reference point
%on the midline, through the reference point, to the point where this line
%intersects the cell boundary, 23/05/2024.
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
%In regions of cell meshes with extreme curvature the intersection with the
%cell boundary may be slightly outside the current segment; however this
%rare case still provides an excellent approximation.
%
%Inputs
%------
%t  (vec)   row vector of the position of the reference point [x,y]
%               projected onto the cell midline
%C  (vec)   row vector of the position of the reference point [x,y]
%D  (vec)   row vector of the first point in the cell mesh segment that
%               corresponds to the midline segment within which the
%               reference point C is projected (t)
%E  (vec)   row vector of the second point in the cell mesh segment that
%               corresponds to the midline segment within which the
%               reference point C is projected (t)
%
%Output
%------
%latitude   (float) perpendicular distance of the reference point C from
%                       the midline, normalised by the distance between the
%                       midline and the corresponding half width of the
%                       cell at that point
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %if C happens to fall exactly on midline, return zero latitude (edge case arising from large, low resolution simulations)
    if C == t
        latitude = 0;
        return;
    end

    %define vectors
    vTC = C - t; %t to C
    vDE = E - D; %D to E
    
    %t + s*vTC = D + r*vDE; Solve for s to find intersection
    A = [vTC; -vDE]';
    b = D - t;
    
    %solve linear equation A * [s; r] = b
    params = A \ b';
    s = params(1);
    
    %calc coordinates of F on the extended line tC
    F = t + s * vTC;
    
    %calculate lengths tC and tF
    length_tC = norm(vTC);
    length_tF = norm(F - t);
    
    latitude = length_tC / length_tF;
end


function [longitude_abs, latitude_abs] = findCoordsBeyondPole(x, y, A, B)
%Compute latitude and longitude for points that exist beyond the length
%of the mesh, 23/05/2024.
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
%This works by extending the midline beyond the cell boundary. Best
%practice when calling this function is to pass the first and third points
%of the midline instead of the first and second as many segmentation tools
%produce errors close to the pole. For the second cell pole, obviously this
%is reflected (passing the final and third-to-final position).
%
%Inputs
%------
%x  (float) x-coordinate of reference point
%y  (float) y-coordinate of reference point
%A  (float) [x, y] coordinates of first point of the midline segment
%               closest to the reference point
%B  (float) [x, y] coordinates of second point of the midline segment
%               closest to the reference point
%
%Output
%------
%longitude_abs  (float) contour length from the first cell pole, along the
%                           midline up to the point at which the reference
%                           point C is projected on the cell midline
%latitude_abs   (float) perpendicular distance of the reference point C
%                           from the midline
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None

    %convert into vectors
    C = [x y];
    AB = B - A;
    AP = C - A;
    
    %project point C onto line AB
    len_projected   = dot(AP, AB) / dot(AB, AB);
    projected_point = A + len_projected * AB;
    
    %longitude is distance between projected point and cell pole
    longitude_abs = norm(projected_point - A);
    
    %latitude is perpendicular distance from P to the line AB
    if norm(AB) == 0
        latitude_abs = norm(AP);
    else
        latitude_abs = norm(cross([AB, 0], [AP, 0])) / norm(AB);
    end
end