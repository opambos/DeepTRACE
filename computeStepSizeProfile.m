function [step_sizes] = computeStepSizeProfile(movie_data, N_lim, h_axes)
%Compile a histogram of steps from all tracks in original data, Oliver
%Pambos, 19/12/2021.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeStepSizeProfile
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
%movie_data     (struct)    main struct (originally derived from LoColi)
%N_lim          (int)       maximum number of steps to take from each track
%                               tracks are truncated to this number, use
%                               zero or a -ve number to prevent truncation
%
%Output
%------
%step_sizes     (vec)       column vector containing all step sizes in data
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %pre-allocate step_sizes
    N_mol = 0;
    for ii = 1:size(movie_data.cellROI_data,1)
        if ~isempty(movie_data.cellROI_data(ii).tracks)
            N_mol = N_mol + size(unique(movie_data.cellROI_data(ii).tracks(:,4)),1);
        end
    end
    step_sizes = zeros(N_mol,1);
    
    idx = 1;
    %loop over cells
    for ii = 1:size(movie_data.cellROI_data,1)
        if ~isempty(movie_data.cellROI_data(ii).tracks)
            tracklist = unique(movie_data.cellROI_data(ii).tracks(:,4));
            %loop over all tracks in cell
            for jj = 1:size(tracklist,1)
                track = movie_data.cellROI_data(ii).tracks(movie_data.cellROI_data(ii).tracks(:,4) == tracklist(jj), 1:2);
                
                if size(track,1)-1 < N_lim || N_lim < 1
                    %if track has fewer than N_lim steps, keep everything
                    distance = zeros(size(track,1) - 1, 1);
                    for kk = 1:size(track,1)-1
                        distance(kk,1) = pdist([track(kk,1:2);track(kk+1,1:2)]);
                    end
                    idx = idx + size(track,1) - 1;
                elseif N_lim == 1
                    %if just keeping first step
                    distance = pdist([track(1,1:2);track(2,1:2)]);
                    idx = idx + 1;
                else
                    %if track had more than N_lim steps, only keep the first N_lim steps
                    distance = zeros(N_lim, 1);
                    for kk = 1:N_lim
                        distance(kk,1) = pdist([track(kk,1:2);track(kk+1,1:2)]);
                    end
                    idx = idx + N_lim;
                end
                step_sizes(idx - size(distance,1) : idx - 1,1) = distance;
            end
        end
    end
    
    %scale steps to nm
    step_sizes = step_sizes .* movie_data.params.px_scale;
    
    %plot the histogram
    h = histogram(h_axes, step_sizes);
    h.FaceColor = 'black';
    h.EdgeColor = 'white';
    h.LineWidth = 2;
    h_axes.YLim = [0 ceil(max(h.Values) * 1.1)];
    h_axes.XLim = [0 max(h.BinEdges)];
    xlabel(h_axes, 'Step size (nm)'); ylabel(h_axes, 'Frequency');
    title(h_axes, 'All step sizes present in dataset');
    box(h_axes, 'on');
end

