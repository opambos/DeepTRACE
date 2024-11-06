function [] = genAlignedVideo(data, t, time_range, autoscale_x, xlim_min, xlim_max, bin_wid, frame_delay, file_pathname, feature_name)
%Using the aligned event data, this function plots the step size histogram
%over time as a video, visualising clearly any heterogeneity in the
%distribution, Oliver Pambos, 10/11/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genAlignedVideo
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
%
%Inputs
%------
%data           (mat)   step sizes of all movements into the state, aligned at the transition step;
%                           each row represents an event, each row is a series of localisations
%t              (vec)   time relative to the transition event, each entry relates to corresponding column of the matrix 'data'
%time_range     (vec)   2-element row vector containing the lower and upper time limits to display
%autoscale_x    (bool)  determines whether to autoscale the X-axis (feature axis)
%xlim_min       (float) upper limit of x-axis to display
%xlim_max       (float) upper limit of x-axis to display; distribution can be very long-tailed and can vary substantially between frames;
%                           fixing limits also stabilizes video; units depend on feature used
%bin_wid        (float) histogram bin width, units depend upon feature used
%frame_delay    (float) time between frames in animated video output, in seconds
%file_pathname  (str)   path and file name of output animated gif file
%feature_name   (str)   name of the feature to be plotted
%
%Output
%------
%None - video is saved to disk, and rendered in an external window
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None

    %trim matrix 'data' and row vector 't' based on the time range
    valid_idx   = (t >= time_range(1)) & (t <= time_range(2));
    data        = data(:, valid_idx);
    t           = t(valid_idx);
    
    %determine global ylim, set this to be 10% larger than max value; this stabilizes video
    max_count = 0;
    for ii = 1:size(data, 2)
        column_data = data(:, ii);
        column_data = column_data(column_data ~= 0);
        [counts, ~] = histcounts(column_data, 'BinWidth', bin_wid, 'Normalization', 'probability');
        max_count = max(max_count, max(counts));
    end
    ylim_max = 1.1 * max_count;
    
    %create a directory for video if it doesn't already exist
    video_out_dir = 'Aligned event videos';
    if ~exist(video_out_dir, 'dir')
        mkdir(video_out_dir);
    end
    
    h_progress = waitbar(0, 'Creating histograms...');
    
    %loop over columns
    for ii = 1:size(data, 2)
        waitbar(ii/size(data, 2), h_progress);
        
        %extract current column ignoring zeros
        column_data = data(:, ii);
        column_data = column_data(column_data ~= 0);
        
        %generate histogram, and set style
        fig = figure('visible','off', 'Position', [100, 100, 1200, 800]); % Increase figure size
        h = histogram(column_data, 'BinWidth', bin_wid, 'Normalization', 'probability', 'FaceColor', 'black', 'EdgeColor', 'white', 'LineWidth', 2);
        set(gcf, 'Color', 'white');
        
        %set axis properties
        ax = gca;
        ax.FontSize     = 20;
        ax.YAxis.Limits = [0 ylim_max];
        title(sprintf('Time relative to event: %.2f s', t(ii)));
        xlabel(feature_name, 'FontSize', 24);
        ylabel('Normalised frequency', 'FontSize', 24);
        ax.LineWidth = 2;
        if ~autoscale_x
            ax.XAxis.Limits = [xlim_min, xlim_max];
        end
        
        %set Y-axis ticks
        N_ticks             = max(4, min(7, floor(ylim_max * 10)));
        tick_step           = round(ylim_max / N_ticks, 1);
        ax.YAxis.TickValues = 0:tick_step:ylim_max;

        %capture plot as high resolution image
        frame       = getframe(fig);
        [imind, cm] = rgb2ind(frame2im(frame), 256);
        
        %save animated gif
        if ii == 1
            imwrite(imind, cm, file_pathname, 'gif', 'Loopcount', inf, 'DelayTime', frame_delay);
        else
            imwrite(imind, cm, file_pathname, 'gif', 'WriteMode', 'append', 'DelayTime', frame_delay);
        end
        
        close(fig);
    end
    
    close(h_progress);
end

