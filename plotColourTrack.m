function [] = plotColourTrack(h_axes, method, style, track, colour_data)
%Plot a track onto an existing figure, using colours to illustrate track
%information, Oliver Pambos, 09/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotColourTrack
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
%Plotting options here are controlled by a series of method and style
%definitions to be defined by selection boxes in the GUI.
%
%Note that no consideration is given for missing frames that may results
%from the use of a memory during tracking; if there is a missing
%localisation in a trajectory this localistion will not progress the colour
%sequence.
%
%Inputs
%------
%h_axes         (handle)    axes handle
%method         (str)       method for colouring the track
%track          (mat)       tracks data where the first two columns represent (x,y) coordinates, final column is state label, and each row is a localisation
%colour_data    (mat)       Nx3 matrix of RGB values containing rules for assigning colours to steps; not required for some methods
%                               for some gradient methods these represent start and end points for interpolation
%                               for statewise methods each row represents a unique state
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%drawArrowLine()
    
    control_str = strcat(method, '_', style);
    hold(h_axes, "on");
    
    switch control_str
        case 'Time_Lines'
            %colour trajectory according to row number using colours determined by linear interpolation of the colour_data input
            
            %determine the number of steps in the trajectory
            N_steps = size(track, 1);
            
            %calculate the color for each step using linear interpolation
            step_colours = interp1(linspace(1, N_steps, size(colour_data, 1)), colour_data, 1:N_steps, 'linear');
            
            %plot each step with a different color
            for i = 1:N_steps-1
                x = track(i:i+1, 1);
                y = track(i:i+1, 2);
                plot(x, y, 'Color', step_colours(i, :), 'LineWidth', 1);
            end
            
            %plot the first step in green, and the last step in red
            plot(track(1, 1), track(1, 2), '*', 'Color', colour_data(1,:));
            plot(track(end, 1), track(end, 2), '*', 'Color', colour_data(end,:));
            
        case 'Time_Arrows'
            %colour trajectory according to row number using colours determined by linear interpolation of the colour_data input, and add arrows

            %estimate sensible sizes for the arrowheads; using max range as estimate of approx scale as user could conceivably enter any source data
            max_range = max([max(track(:,1)) - min(track(:,1)), max(track(:,2)) - min(track(:,2))]);
            arrow_len = max_range/50;
            arrow_wid = arrow_len/2;
            
            %calculate the color for each step using linear interpolation
            step_colours = interp1(linspace(1, size(track, 1), size(colour_data(:,:), 1)), colour_data(:,:), 1:size(track, 1), 'linear');
            
            for ii = 2:size(track,1)
                drawArrowLine(h_axes, track(ii-1,1), track(ii-1,2), track(ii,1), track(ii,2), step_colours(ii,:), arrow_len, arrow_wid, 'filled');
            end

        case 'Step size_User defined range'
            %colour trajectory based on step size using a user-specified [min max] range
            %to enable visual interrogation of step sizes and global comparison between trajectories - currently not implemented
            
            %defined range is used for either direct user input or enforcing consistent global colour scheme between molecules
            error("IVK:plotColourTrack:StepSizeRangeNotImplemented", "Error: user-defined step size range is not yet implemented");
            
        case 'Step size_Auto range'
            %colour trajectory based on step size to enable visual interrogation of step sizes
            %using an automatically assigned step size range based on normalised linear
            %interpolation between largest and smallest step size in current trajectory
            
            %obtain distances between (x,y) values - not passed from tracks matrix here for versatility, and there is very low overhead here
            dists_and_colours = zeros(size(track,1)-1, 4);  %structure is [distance, R, G, B]
            for ii = 1:size(track,1)-1
                dists_and_colours(ii,1) = pdist([track(ii,1:2);track(ii+1,1:2)]);
            end
            
            %range of possible step sizes to normalise colour space
            range_step_sizes = [min(dists_and_colours(:,1)) max(dists_and_colours(:,1))];
            
            %set RGB values based on distances - replace with vectorised version later
            for ii = 1:size(dists_and_colours,1)
                %compute the normalised step size between the smallest and largest step size, and use this to linearly interpolate RGB triplet
                norm_dist = (dists_and_colours(ii,1) - range_step_sizes(1)) / (range_step_sizes(2) - range_step_sizes(1));
                dists_and_colours(ii,2:4) = (1 - norm_dist)*colour_data(1, :) + norm_dist*colour_data(end, :);
            end
            

            for ii = 1 : size(track,1) - 1
                %note that this currently just uses the first and last colours in the colour_data matrix, not the intermediate colours
                plot(h_axes, track(ii:ii+1,1), track(ii:ii+1,2), 'Color', dists_and_colours(ii,2:4), 'LineWidth', 1.5);
            end
            
        case 'Labelled_Arrows'
            %colour trajectory using state labels (if these exist), and add arrows to indicate direction of motion of molecule
            
            %ensure there is an entry in the colour matrix for every state used, and that default unclassified state label (-1) is not present
            if any(unique(track(:,end)) < 1) || any(unique(track(:,end)) > size(colour_data,1))
                error("IVKplotColourTrack:MethodLabelledStyleArrows:NotEnoughColours", "The track contains more unique states labels than there are colours passed to the to the function.");
            end
            
            %estimate sensible sizes for the arrowheads; using max range as estimate of approx scale as user could conceivably enter any source data
            max_range = max([max(track(:,1)) - min(track(:,1)), max(track(:,2)) - min(track(:,2))]);
            arrow_len = max_range/50;
            arrow_wid = arrow_len/2;
            
            for ii = 1:size(track,1) - 1
                drawArrowLine(h_axes, track(ii,1), track(ii,2), track(ii+1,1), track(ii+1,2), colour_data(track(ii,end),:), arrow_len, arrow_wid, 'filled');
            end

        case 'Labelled_Statewise'
            %colour trajectory using state labels (if these exist)
            
            if any(unique(track(:,end)) < 1) || any(unique(track(:,end)) > size(colour_data,1))
                error("IVKplotColourTrack:MethodStatewise:NotEnoughColours", "The track contains more unique states labels than there are colours passed to the to the function.");
            end
            
            for ii = 1:size(track,1) - 1
                plot(h_axes, track(ii:ii+1,1), track(ii:ii+1,2), 'Color', colour_data(track(ii,end),:), 'LineWidth', 1.5);
            end
            
        case 'Rainbow_Lines'
            %colour trajectory using the jet colour map (reversed) such that
            %molecules are labelled by time from blue to red; colour sequence
            %ignores memory parameter
            
            %colour a track usign the jet colour map, note that missing localisations due to implementation of the memory parameter are not considered
            colours = jet(size(track,1)-1);
            colours = flipud(colours);
            
            for ii = 1:size(track,1)-1
                plot(h_axes, track(ii:ii+1,1), track(ii:ii+1,2), 'Color', colours(ii,:), 'LineWidth', 1.5);
            end
            
        otherwise
            error("IVK:plotColourTrack:MethodUnknown", "Error in plotColourTrack(): method and style combination is not currently available");
    end
    hold(h_axes, "off");

end
