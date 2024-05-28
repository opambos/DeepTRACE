function [d_min] = findPointToMeshDist(x, y, mesh)
%Find distance between a single point and a cell mesh, Oliver Pambos,
%03/04/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findPointToMeshDist
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD, UK
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%LEGAL DISCLAIMER
%THIS CODE IS INTENDED FOR USE ONLY BY INDIVIDUALS WHO HAVE RECEIVED
%EXPLICIT AUTHORIZATION FROM THE AUTHOR, OLIVER JAMES PAMBOS. ANY FORM OF
%COPYING, REDISTRIBUTION, OR UNAUTHORIZED USE OF THIS CODE, IN WHOLE OR IN
%PART, IS PROHIBITED. BY USING THIS CODE, USERS SIGNIFY THAT THEY HAVE
%READ, UNDERSTOOD, AND AGREED TO BE BOUND BY THE TERMS OF SERVICE PRESENTED
%UPON SOFTWARE LAUNCH, INCLUDING THE REQUIREMENT FOR CO-AUTHORSHIP ON ANY
%RELATED PUBLICATIONS. THIS APPLIES TO ALL LEVELS OF USE, INCLUDING PARTIAL
%USE OR MODIFICATION OF THE CODE OR ANY OF ITS EXTERNAL FUNCTIONS.
%
%USERS ARE RESPONSIBLE FOR ENSURING FULL UNDERSTANDING AND COMPLIANCE WITH
%THESE TERMS, INCLUDING OBTAINING AGREEMENT FROM THE APPROPRIATE
%PUBLICATION DECISION-MAKERS WITHIN THEIR ORGANIZATION OR INSTITUTION.
%
%NOTE: UPON PUBLIC RELEASE OF THIS SOFTWARE, THESE TERMS MAY BE SUBJECT TO
%CHANGE. HOWEVER, USERS OF THIS PRE-RELEASE VERSION ARE STILL BOUND BY THE
%CO-AUTHORSHIP AGREEMENT FOR ANY USE MADE PRIOR TO THE PUBLIC RELEASE. THE
%RELEASED VERSION WILL BE AVAILABLE FROM A DESIGNATED ONLINE REPOSITORY
%WITH POTENTIALLY DIFFERENT USAGE CONDITIONS.
%
%
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
%Find distance between a single point and a line, Oliver Pambos,
%03/04/2020.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findPointToLine
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD, UK
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%LEGAL DISCLAIMER
%THIS CODE IS INTENDED FOR USE ONLY BY INDIVIDUALS WHO HAVE RECEIVED
%EXPLICIT AUTHORIZATION FROM THE AUTHOR, OLIVER JAMES PAMBOS. ANY FORM OF
%COPYING, REDISTRIBUTION, OR UNAUTHORIZED USE OF THIS CODE, IN WHOLE OR IN
%PART, IS PROHIBITED. BY USING THIS CODE, USERS SIGNIFY THAT THEY HAVE
%READ, UNDERSTOOD, AND AGREED TO BE BOUND BY THE TERMS OF SERVICE PRESENTED
%UPON SOFTWARE LAUNCH, INCLUDING THE REQUIREMENT FOR CO-AUTHORSHIP ON ANY
%RELATED PUBLICATIONS. THIS APPLIES TO ALL LEVELS OF USE, INCLUDING PARTIAL
%USE OR MODIFICATION OF THE CODE OR ANY OF ITS EXTERNAL FUNCTIONS.
%
%USERS ARE RESPONSIBLE FOR ENSURING FULL UNDERSTANDING AND COMPLIANCE WITH
%THESE TERMS, INCLUDING OBTAINING AGREEMENT FROM THE APPROPRIATE
%PUBLICATION DECISION-MAKERS WITHIN THEIR ORGANIZATION OR INSTITUTION.
%
%NOTE: UPON PUBLIC RELEASE OF THIS SOFTWARE, THESE TERMS MAY BE SUBJECT TO
%CHANGE. HOWEVER, USERS OF THIS PRE-RELEASE VERSION ARE STILL BOUND BY THE
%CO-AUTHORSHIP AGREEMENT FOR ANY USE MADE PRIOR TO THE PUBLIC RELEASE. THE
%RELEASED VERSION WILL BE AVAILABLE FROM A DESIGNATED ONLINE REPOSITORY
%WITH POTENTIALLY DIFFERENT USAGE CONDITIONS.
%
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