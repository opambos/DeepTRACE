function [msd_result] = compileMSDMatrix(track, t_interframe)
%Compiles matrix of mean square displacements for a single track,
%Oliver Pambos, 03/07/2019.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: compileMSDMatrix
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
%Simple MSD matrix compiler that can be used by external functions to
%produce diffusion coefficients and diffusion histograms.
%
%This function outputs both the averaged and non-averaged squared Euclidean
%distances together with the number of entries used for each lag time in
%order to aid different methods of aggregating statistics in external f'ns.
%Zeros are intentionally left in MSD matrix to aid aggregation of data from
%many trajectories.
%
%Inputs
%------
%track          (mat)   Nx3 matrix, trajectory of a single molecule composed of N localisations,
%                           columns are,
%                               1. x
%                               2. y
%                               3. frame number (do not have to be contiguous)
%t_interframe   (float) time interval between frames in seconds
%
%Output
%------
%msd_result     (mat)   matrix containing MSD values with respective time lags
%                           columns are,
%                               1. sum of squared Euclidean distances from all steps of given lag time, units are input units for (x,y) squared
%                               2. number of entries collected
%                               3. lag time in seconds
%                               4. mean squared Euclidean distance for given lag time across this trajectory, units are input units for (x,y) squared
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %remove track number offset and initialise results matrix
    track(:,3) = track(:,3) - min(track(:,3)) + 1;
    msd_result = zeros(max(track(:,3)), 2);
    
    %loop over all pairs of localisations track (all possible time delays)
    for ii = 1:size(track, 1)
        for jj = ii+1:size(track, 1)
            delta_frame = track(jj, 3) - track(ii, 3);
            
            %if its not the same localisation, compute the distance and update the results patrix
            if delta_frame > 0
                distance_sq = pdist([track(ii, 1:2); track(jj, 1:2)], 'squaredeuclidean');
                msd_result(delta_frame, 1) = msd_result(delta_frame, 1) + distance_sq;
                msd_result(delta_frame, 2) = msd_result(delta_frame, 2) + 1;
            end
        end
    end
    
    %calculating mean for each time lag
    valid_idx = msd_result(:, 2) > 0;
    msd_result(valid_idx, 4) = msd_result(valid_idx, 1) ./ msd_result(valid_idx, 2);
    
    %produce a third column containing the lag time
    msd_result(:,3) = (1:size(msd_result,1))' .* t_interframe;
    
end
