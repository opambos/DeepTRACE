function [] = plotColourTrack(h_axes, method, style, track, colour_data, feature_data, feature_stats)
%Plot a track onto an existing figure, using colours to illustrate track
%information, Oliver Pambos, 09/05/2023.
%
%AUTHOR: OLIVER JAMES PAMBOS, DEPARTMENT OF PHYSICS, UNIVERSITY OF OXFORD
%CONTACT: oliver.pambos@physics.ox.ac.uk
%
%ATTRIBUTION AND DISCLAIMER
%This code was conceived and developed entirely by Oliver James Pambos, and
%is distributed as part of DeepTRACE.
%
%If this code contributes to results presented in a scientific publication,
%the following article should be cited:
%
%   https://doi.org/10.1101/2025.05.15.654348
%
%The publicly available version of DeepTRACE, including documentation and
%updates, is available at:
%
%   https://github.com/opambos/DeepTRACE
%
%For full license, attribution, and citation terms, see the LICENSE and
%NOTICE files distributed with DeepTRACE.
%
%Copyright 2022-2026 Oliver James Pambos
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
%feature_data   (vec)       column vector holding a single feature column
%feature_stats  (mat)       4xN matrix holding [min, max, mean, stdev] for all features
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
        case 'Colour_Feature'
            %colour track according to feature
            
            %error handling
            if nargin < 7
                error('ErrorInplotColourTrack:ColourFeature:MissingInputs', 'Missing args');
            end
            if numel(feature_data) ~= size(track,1)
                error('ErrorInplotColourTrack:ColourFeature:BadLength', 'feature_data must have same number of rows as track.');
            end
            if size(feature_stats) ~= 4
                error('ErrorInplotColourTrack:ColourFeature:BadStatsInput', 'feature_range must be a 1×4 vector [min, max, mean, stdev].');
            end
            
            %=======================
            %define some colour maps - will be replaced with switch statement
            %=======================
            %red-white-blue
            half = 128;
            cmap = [ones(half, 1), linspace(0, 1, half)', linspace(0, 1, half)';     %red to white
                    linspace(1, 0, half)',  linspace(1, 0, half)', ones(half, 1)];   %white to blue
            
            N_colours = 256;    %256 colour levels
            cmap  = [ linspace(1, 0, N_colours)',  zeros(N_colours, 1), linspace(0, 1,N_colours)' ];
            
            % %red-white
            % cmap  = [ones(N_colours, 1), ...         %red stays 1
            %          linspace(0, 1, N_colours)', ...  %green goes from 0 to 1
            %          linspace(0, 1, N_colours)'];     %blue goes from 0 to 1
            
            %==================================
            %scale the features to global range
            %==================================
            % %normalise values to min-max
            % span  = diff(feature_stats(1:2, :));
            % 
            % %handle division by zero in strange arbitrary features
            % if span == 0
            %     span = eps;
            % end
            % t_norm = max(min((feature_data - feature_stats(1, 1)) ./ span, 1), 0);
            
            %scale by mean and one standard deviation of global
            mu     = feature_stats(3, 1);
            sigma  = feature_stats(4, 1);
            
            k      = 1; %how many standard deviations to saturate colours
            low    = mu - k*sigma;
            high   = mu + k*sigma;
            
            %normalise feature data by mean and standard deviation
            t_norm = max(min((feature_data - low) ./ max(high-low, eps), 1), 0);
            
            %colour lookup for all steps in track for plotting
            idx         = floor(t_norm * (size(cmap, 1)-1)) + 1;
            seg_colours = cmap(idx(2:end), :);
            
            for ii = 1:size(track,1)-1
                plot(h_axes, track(ii:ii+1, 1), track(ii:ii+1, 2), 'Color', seg_colours(ii, :), 'LineWidth', 1.5);
            end
            
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

            seg_colours = colour_data(feature_data(2:end), :);
            
            for ii = 1:size(track,1)-1
                plot(h_axes, track(ii:ii+1,1), track(ii:ii+1,2), 'Color', seg_colours(ii,:), 'LineWidth', 1.5);
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