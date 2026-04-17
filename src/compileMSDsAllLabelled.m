function [] = compileMSDsAllLabelled(app)
%Compile MSDs and apparent diffusion coefficients for all states and
%molecules in a labelled dataset, Oliver Pambos, 14/11/2022.
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
%This code cycles through all labelled molecules in the dataset, compiling
%large matrices to hold all MSD data for all molecules as well as for each
%diffusive state. This includes both partial and pure (doubly-truncated)
%states. MSDs are processed using two different approaches to averaging: on
%a molecule-by-molecule basis, using the cell array of matrices MSD_all,
%which minimises bias from longer molecules; and on step-by-step basis,
%using the matrix MSD_global, which treats all localisations equally in its
%calculation. These matrices are also compiled with the option to restrict
%molecules and sections to a given length, and both also contain MSD
%calculations for all molecules, ignoring the class labels. After compiling
%these initial matrices the function then computes apparent diffusion
%coefficients, D*, for all states, as well as for all molecules, and
%displays this either as a scatter plot for molecule-by-molecule means with
%standard errors of the mean, or as line plots in the case where equal
%weighting is applied to all localisations.
%
%This code also takes advantage of the regular structure of labelled data
%to enable it to be flexible to operate on data labelled from different
%sources (manually labelled, labelled with ML, labelled using changepoint
%analysis).
%
%Update 07/03/2024: the active labelled dataset is now copied to the
%substruct `InsightData` through the `Source data` GUI component.
%Downstream analysis code, including this function, now operate directly
%on this dedicated substruct. This greatly simplifies and generalises the
%analysis codebase, enabling functions such as this one to operate on any
%labelled dataset defined dynamically during runtime. This also enables
%analysis of future labelling types without having to locally hardcode
%rules, and eliminates the need for state variables to keep track of the
%current analysis target.
%
%A new optional `fast mode` has been introduced which restricts MSD
%calculations to only the data used for computation of the diffusion
%coefficients. This greatly improves performance but restricts the
%available plotting range as longer lag times are not calculated. A future
%update will introduce a third option which will construct MSDs up to the
%maximum displayed lag time, providing a balance between the two
%approaches.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%app    (handle)    main GUI handle
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%compileMSDMatrix()
%convertLabelLocsToUm() - local to this .m file
%compileMSDMatrices()   - local to this .m file
%findMSDLims()          - local to this .m file
%findNSections()        - local to this .m file
%plotMSDLines()         - local to this .m file
%plotMSDScatter()       - local to this .m file
%computeDStars()        - local to this .m file
    
    %obtain from the GUI user selections for source data, minimum span to use for MSD, upper limit for the lag time to display in MSD curves, and the averaging method
    min_locs_MSD     = app.MinimumlocalisationsforMSDSpinner.Value;
    averaging_method = app.ProcessaveragesDropDown.Value;
    N_classes   = size(app.movie_data.params.class_names,1);
    N_steps     = app.NumberofstepsforDcalculationSpinner.Value;
    fast_mode   = app.FastmodeCheckBox.Value;
    
    %re-assess x-axis plot limit based on available data range
    if fast_mode
        plot_lim = N_steps ./ app.movie_data.params.frame_rate;
        app.LagtimetodisplaysSpinner.Value = plot_lim;
    else
        plot_lim = app.LagtimetodisplaysSpinner.Value;
    end
    
    labelled_mols = app.movie_data.results.InsightData.LabelledMols;
    
    %convert localisation data to micrometers - in future versions this conversion may be more efficiently applied immediately before data presentation
    [labelled_mols] = convertLabelLocsToUm(labelled_mols, app.movie_data.params.px_scale);
    
    %get the MSD matrices for all molecules and all states; MSD_global is used for plotting MSDs as lines, MSD_all is used for equivalent scatter plot
    [MSD_global, MSD_all] = compileMSDMatrices(labelled_mols, N_classes, min_locs_MSD, 1/app.movie_data.params.frame_rate, fast_mode, N_steps);

    switch averaging_method
        case 'Molecule-by-molecule'
            %collate all data for MSD scatter pots with molecule-by-molecule mean averaging
            %loop over classes
            for ii = 1:N_classes+1
                %loop over all lag times
                for jj = 1:size(MSD_all{ii,1}, 1)
                    %extract the non-zero elements
                    non_zero_elements = MSD_all{ii,1}(jj,4,:);
                    non_zero_elements = non_zero_elements(non_zero_elements ~= 0);
                    
                    %calculate mean and SEM for all data - these should be pre-allocated
                    all_means(ii,jj) = mean(non_zero_elements);
                    all_SEMs(ii,jj)  = std(non_zero_elements)/sqrt(size(non_zero_elements,3));
                end
            end
            
            %generate the lag time information
            t = (1 / app.movie_data.params.frame_rate) : (1 / app.movie_data.params.frame_rate) : (size(all_means, 2) / app.movie_data.params.frame_rate);
            
            %produce scatterplot of MSDs for all molecules, and for all classes
            figure('MenuBar', 'none'); h_axes_scatter = gca;
            plotMSDScatter(h_axes_scatter, all_means, all_SEMs, t, app.movie_data.params.event_label_colours, app.movie_data.params.class_names, plot_lim);
            
            %compute D*
            [DStars, fits] = computeDStars(all_means(:,1:N_steps), t(1,1:N_steps), app.DcalculationmethodDropDown.Value, app.LocalisationerrormSpinner.Value, 1/app.movie_data.params.frame_rate);
            
            %future version may allow optional plotting of fitted lines in onto figure here

        case 'All localisations'
            %plot the MSD lines plot
            figure('MenuBar', 'none'); h_axes_lines = gca;
            [all_means, t] = plotMSDLines(h_axes_lines, MSD_global, app.movie_data.params.event_label_colours, app.movie_data.params.class_names, plot_lim);
            
            %compute D*
            [DStars, fits] = computeDStars(all_means(:,1:N_steps), t(1,1:N_steps), app.DcalculationmethodDropDown.Value, app.LocalisationerrormSpinner.Value, 1/app.movie_data.params.frame_rate);
            
            %future version may allow optional plotting of fitted lines in onto figure here
            
        otherwise
        error("IVK:compileDStarAllMols:UnknownAveragingMethod");
    end
    
    %display D* values inside the GUI, and write to the results struct
    string_out = "D* All trajectories: " + num2str(DStars(1), '%.4f') + " " + char(956) + "m" + char(178) + "s" + char(8315) + char(185);
    for ii = 2:size(DStars, 1)
        string_out = string_out + newline + "D* " + app.movie_data.params.class_names{ii-1, 1} + ": " + num2str(DStars(ii), '%.4f') +...
            " " + char(956) + "m" + char(178) + "s" + char(8315) + char(185);       %I love unicode
    end
    app.textout.Value = string_out;
    app.movie_data.results.InsightData.DStars = DStars;
end


function [labelled_mols] = convertLabelLocsToUm(labelled_mols, px_scale_nm)
%Convert labelled molecule localisations from pixels to micrometers, Oliver
%Pambos, 14/11/2022.
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
%
%Input
%-----
%labelled_mols  (struct)    labelled molecule substruct, with units of pixels
%px_scale_nm    (float)     pixel scale in nm per pixel
%
%Output
%------
%labelled_mols  (struct)    labelled molecule substruct, with units of micrometers
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    for ii = 1:size(labelled_mols,1)
        labelled_mols{ii,1}.Mol(:,1:2) = labelled_mols{ii,1}.Mol(:,1:2) .* (px_scale_nm/1000);
    end
    
end



function [MSD_global, MSD_all] = compileMSDMatrices(labelled_mols, N_classes, min_locs_MSD, frame_rate, fast_mode, N_steps)
%Compiles matrices of MSD lag time data from labelled molecules used for
%computation of mean and SEM values for plotting and D* calculation,
%Oliver Pambos, 14/11/2022.
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
%This function mines the labelled dataset labelled_mols, computing MSDs for
%every molecule, and every span of classified sections of molecules, to
%produce two matrices that can be used to plot MSD-lag time plots as well
%as compute the apparent diffusion coefficients D*. The matrix MSD_global
%takes the mean MSD value for all lag times across all molecules and spans
%for a given class on a localisation-by-localisation basis; essentially for
%each class, all step sizes for a given lag time are averaged across all
%spans and molecules, and this value is then divided by the number of
%entries to obtain the MSD; this results in a bias towards MSDs from longer
%lasting molecules, and should be avoided. The matrix MSD_all however
%stores all MSD data for all molecules and spans separately, enabling the
%calling function to compute the mean MSD for each lag time on a molecule-
%by-molecule, or span-by-span basis, minimising this bias in the analysis.
%
%Given that the user selects the averaging method via the GUI prior to
%calling this function, only one of these matrices is required; in future
%versions this function could be split into two different functions, or
%conditional statements incorporated such that only one matrix is
%contructed (MSD_all, or MSD_global).
%
%A new optional `fast mode` has been introduced which restricts MSD
%calculations to only the data used for computation of the diffusion
%coefficients. This greatly improves performance but restricts the
%available plotting range as longer lag times are not calculated. A future
%update will introduce a third option which will construct MSDs up to the
%maximum displayed lag time, providing a balance between the two
%approaches.
%
%Inputs
%------
%labelled_mols  (struct)    labelled molecule substruct, with units of
%                               micrometers
%N_classes      (int)       number of classes/states in the labelled data
%min_locs_MSD   (int)       minimum number of localisations required in any
%                               span for inclusion in the dataset
%frame_rate     (float)     frame rate of fluorescence video recording
%fast_mode      (bool)      in fast mode, lag times are only computed over
%                               the range required for D* calculation
%N_steps        (int)       maximum lag time to be used for the D*
%                               calculation; in fast mode this determines
%                               the size of the range of lag times to
%                               compute
%
%Outputs
%-------
%MSD_global (mat)   3D matrix with dimensions of lag time, columns (see
%                       below), and classes (first class is all
%                       trajectories) columns are as follows,
%                           1. sum of squared Euclidean distances from all
%                               steps of given lag time, units are input
%                               units for (x,y) squared
%                           2. number of entries collected
%                           3. lag time in seconds
%                           4. mean squared Euclidean distance for given
%                               lag time across this trajectory, units are
%                               input units for (x,y) squared
%                       3rd dimension
%                           (:,:,1)     MSD for all molecules ignoring
%                                           states
%                           (:,:,N)     MSD for state N-1
%MSD_all    (cell)  cell array of MSD data from every molecule in the
%                       dataset,
%                           each cell {ii,1} is a different class/state,
%                           with {1,1} being all trajectories dimension of
%                           matrices inside each cell are XxYxZ where,
%                               X (rows) are individual lag times for the
%                                   given molecule
%                               Y are columns (see below)
%                               Z are sections or molecules
%                       columns are,
%                           1. sum of squared Euclidean distances from all
%                               steps of given lag time in the molecule
%                           2. number of entries from the molecule used to
%                               obtain the sum of step sizes in column 1
%                           3. lag time, in seconds
%                           4. MSD (mean squared Euclidean distance) for
%                               given lag time across the trajectory
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %pre-allocation of the MSD global matrix, this has the form described in the function header above
    if fast_mode
        MSD_lim = N_steps;
    else
        MSD_lim = findMSDLims(labelled_mols);
    end
    MSD_global = zeros(MSD_lim,4,N_classes+1);
    
    %pre-allocation of MSD_all cell array, this has the form described in the function header above
    spans_per_class = findNSections(labelled_mols, N_classes);
    MSD_all{1,1}    = zeros(MSD_lim, 4, size(labelled_mols,1));
    for ii = 2:N_classes + 1
        MSD_all{ii,1} = zeros(MSD_lim,4,spans_per_class(ii-1));
    end
    
    f = waitbar(0,'Computing MSDs for every molecule and labelled span, across every class...');
    
    %keep track of how many MSDs of each class have been written to the MSD_all array so far
    class_pos = ones(1,N_classes);
    
    %loop over all labelled molecules
    for ii = 1:size(labelled_mols, 1)
        
        %check all labels are valid
        if all(labelled_mols{ii,1}.Mol(:,end) > 0 & labelled_mols{ii,1}.Mol(:,end) <= N_classes)
            
            %step 1: if trajectory contains enough localisations, compute the MSD for the whole molecule, and store this in MSD_global(:,:,1)
            
            if size(labelled_mols{ii,1}.Mol, 1) >= min_locs_MSD
                if fast_mode
                    MSD_mol = compileMSDMatrixFast(labelled_mols{ii,1}.Mol(:,1:3), frame_rate, N_steps);
                else
                    MSD_mol = compileMSDMatrix(labelled_mols{ii,1}.Mol(:,1:3), frame_rate);
                end
                MSD_global(1:size(MSD_mol,1), 1:2 , 1) = MSD_global(1:size(MSD_mol,1), 1:2 , 1) + MSD_mol(:,1:2);
                
                %add the raw MSD data to the MSD_all list and increment the current position
                MSD_all{1,1}(1:size(MSD_mol,1), : , ii) = MSD_mol;
            end
            
            %step 2: repeat with all labelled sections of the molecule, and store this in MSD_global(:,:,N+1)
            
            %find the start row of every unique section by calling diff() on the class column
            %note that I've intentionally added a fake final section one row index after end of matrix to avoid an additional if-else statement inside the loop
            section_starts  = [1; find(diff(labelled_mols{ii, 1}.Mol(:, end)) ~= 0) + 1; size(labelled_mols{ii, 1}.Mol(:, end),1) + 1];
            N_sections      = numel(section_starts) - 1;
            
            %loop over sections, obtain MSD data for section, and combine with global MSD data
            for jj = 1:N_sections
                %obtain the section, and it's class label
                section     = labelled_mols{ii, 1}.Mol(section_starts(jj):section_starts(jj+1)-1, :);
                class_label = section(1,end);
                
                %if the section is long enough, compute its MSD, and add it to the global MSD for that class
                if size(section,1) >= min_locs_MSD
                    if fast_mode
                        MSD_section = compileMSDMatrixFast(section(:,1:3), frame_rate, N_steps);
                    else
                        MSD_section = compileMSDMatrix(section(:,1:3), frame_rate);
                    end
                    MSD_global(1:size(MSD_section,1), 1:2, class_label + 1) = MSD_global(1:size(MSD_section,1), 1:2, class_label + 1) + MSD_section(:,1:2);
                    
                    %add the raw MSD data to the MSD_all list and increment the current position
                    MSD_all{class_label+1,1}(1:size(MSD_section,1), : , class_pos(class_label)) = MSD_section;
                    class_pos(class_label) = class_pos(class_label) + 1;
                end
            end
        end
        
        waitbar(ii/size(labelled_mols, 1), f, "Computed " + num2str(ii) + "/" + num2str(size(labelled_mols, 1)) + " trajectories");
    end
    
    close(f);
    
    %loop over MSDs matrices for different states, and construct cols 3 and 4 of MSD_global based on accumulated data
    for ii = 1:size(MSD_global,3)
        valid_rows = MSD_global(:, 2, ii) > 0;
        
        MSD_global(valid_rows, 3, ii) = find(valid_rows) .* frame_rate;
        MSD_global(valid_rows, 4, ii) = MSD_global(valid_rows, 1, ii) ./ MSD_global(valid_rows, 2, ii);
    end
end


function [global_range] = findMSDLims(labelled_mols)
%Finds the upper limit for MSD lag times, Oliver Pambos, 14/11/2022.
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
%This function finds the largest frame separation between localisations in
%any molecule. This is subsequently used by the calling function to
%pre-allocate the matrix MSD_global.
%
%It may be tempting to refactor this code to find the minimum memory
%allocation for each individual state by scanning the length of individual
%states inside all molecules, and then pre-allocating into varied-length
%matrices indexed inside a cell array to completely eliminate padding.
%However, there are a number of reasons to avoid this,
%   1. the computational overhead of span extraction is greater than the
%       overhead associated with the padded data even when state occupancy
%       is highly heterogeneous.
%   2. all MSD matrices being the same size enables this code and functions
%       that call it to operate inside a 3D array which improves
%       performance and ease of reading vs matrices embedded in a cell
%       array
%   3. the code is more concise, easier to read, and more portable to other
%       applications
%
%Notes for future version: this function is an opportunity to also scan all
%labelled molecule data to check that all labels IDs fall within the
%allowed list (i.e. none are <0 or >size(class_names,1)).
%
%Input
%-----
%labelled_mols  (struct)    labelled molecule substruct
%
%Output
%------
%global_range   (vec)       row vector containing the longest lag time in each labelled state
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    global_range = 0;
    %loop over labelled molecules, if the range of frames is larger than current global range, increase global range
    for ii = 1:size(labelled_mols,1)
        local_range = max(labelled_mols{ii,1}.Mol(:,3)) - min(labelled_mols{ii,1}.Mol(:,3)) + 1;

        if max(labelled_mols{ii,1}.Mol(:,3)) - min(labelled_mols{ii,1}.Mol(:,3)) > global_range
            global_range = local_range;
        end
    end
end


function [total_spans] = findNSections(labelled_mols, N_classes)
%Finds the number of individual sections (or whole trajectories) for each
%class across all labelled molecules, Oliver Pambos, 14/11/2022.
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
%
%Inputs
%------
%labelled_mols  (struct)    substruct containing a set of labelled molecules
%N_classes      (int)       number of classes used to label the dataset
%
%Output
%------
%N_sections     (vec)       row vector of total number of either whole
%                               trajectories or sections of trajectories
%                               for each state, this is used to
%                               pre-allocate matrices in
%                               compileMSDsAllLabelledMols
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    total_spans = zeros(1, N_classes);

    %loop over mols 
    for ii = 1:size(labelled_mols, 1)
        column_vector = labelled_mols{ii, 1}.Mol(:, end); % extracting column of interest from each matrix
    
        for jj = 1:N_classes
            %identifying where the class (jj) starts and ends
            is_class = (column_vector == jj);
            start_ends = diff([0; is_class; 0]);
    
            %counting the number of spans where the class starts
            spans_count = sum(start_ends == 1);
            
            %updating the total spans count for current class
            total_spans(jj) = total_spans(jj) + spans_count;
        end
    end

end


function [mean_MSDs, t] = plotMSDLines(h_axes_lines, MSD_global, class_colours, class_names, plot_lim)
%Plot MSD of all labelled molecules and sections as line plots, Oliver
%Pambos, 14/11/2022.
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
%
%Inputs
%------
%h_axes     (handle)    axes handle
%MSD_global (mat)       MSD global matrix, this has the form,
%                           coloumns
%                               1. sum of squared Euclidean distances from all steps of given lag time, units are input units for (x,y) squared
%                               2. number of entries collected
%                               3. lag time in seconds
%                               4. mean squared Euclidean distance for given lag time across this trajectory, units are input units for (x,y) squared
%                           3rd dimension
%                           (:,:,1)     MSD for all molecules ignoring states
%                           (:,:,N)     MSD for state N-1
%
%Output
%------
%mean_MSDs  (mat)       MxN matrix of the mean MSD for M states with N lag times
%t          (vec)       row vector of lag times in seconds
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    h_datasets = cell(1, size(MSD_global,3));
    
    %store the plotted data in a simple matrix for D* calculation later
    mean_MSDs = [];  %SHOULD BE PRE-ALLOCATED
    t = [];  %SHOULD BE PRE-ALLOCATED; this variable is there purely to ensure that there are no gaps in the output data

    %trim the trailing zeros before plotting
    plot_data = MSD_global(:,:,1);
    rows_nonzero = find(any(plot_data, 2), 1, 'last');
    plot_data = plot_data(1:rows_nonzero, :);
    
    %plot the full trajectory data
    h_datasets{1} = plot(h_axes_lines, [0; plot_data(:,3)], [0; plot_data(:,4)], 'Color', 'k');
    hold on; box on;
    
    %keep data for D* calculation later
    mean_MSDs(1, 1:size(plot_data,1)) = plot_data(:,4)';
    t(1, 1:1:size(plot_data,1)) = plot_data(:,3)';
    
    %loop over remaining classes
    for ii = 2:size(MSD_global,3)
        %trim the trailing zeros before plotting
        plot_data = MSD_global(:,:,ii);
        rows_nonzero = find(any(plot_data, 2), 1, 'last');
        plot_data = plot_data(1:rows_nonzero, :);
        %plot the data
        h_datasets{ii} = plot(h_axes_lines, [0; plot_data(:,3)], [0; plot_data(:,4)], 'Color', class_colours(ii-1,:));
        
        %keep data for D* calculation later
        t(ii, 1:size(plot_data,1))          = plot_data(:,3)';
        mean_MSDs(ii, 1:size(plot_data,1))  = plot_data(:,4)';
    end
    
    %styling the plot
    xlim([0 , plot_lim]);
    y_lims = get(h_axes_lines, 'YLim');
    ylim(h_axes_lines, [0 y_lims(2)]);
    xlabel('Lag time (s)');
    ylabel('MSD (μm^{2})');
    title('MSD-lag time plot computed with equal weighting to all steps');
    class_names = ['Full trajectories'; class_names];
    legend([h_datasets{:}], class_names{:}, 'Location', 'northwest');
    
end


function [] = plotMSDScatter(h_axes_scatter, all_means, all_SEMs, t, class_colours, class_names, plot_lim)
%Plot a scatter with error bars for all labelled molecules and sections,
%Oliver Pambos, 14/11/2022.
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
%
%Inputs
%------
%h_axes         (handle)    axes handle
%all_means      (mat)       matrix of mean MSD for all classes; rows are
%                               class, columns are lag times
%                                   1: MSD data for all molecules (ignoring
%                                       classes and sections)
%                                   2 - N: MSD data for individual classes;
%                                       N = class number + 1 as first row
%                                       is all molecules
%all_SEMs       (mat)       matrix of SEMs of MSD for all classes; rows are
%                               class, columns are lag times
%                                   1: MSD data for all molecules (ignoring
%                                       classes and sections)
%                                   2 - N: MSD data for individual classes;
%                                       N = class number + 1 as first row
%                                       is all molecules
%t              (vec)       row vector of lag times for respective columns
%                               in all_means and all_SEMs
%class_colours  (mat)       Nx3 matrix of colours as 8-bit RGB triplets,
%                               each row represents a different diffusive
%                               state/class
%plot_lim       (float)     stores the upper limit of the x-axis for plotting
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    h_datasets = cell(1, size(all_means, 1));
    %h_datasets{1} = errorbar(h_axes_scatter, [0 t], [0 all_means(1,:)], [0 all_SEMs(1,:)], 'ko', 'MarkerSize', 10, 'LineWidth', 1);
    h_datasets{1} = errorbar(h_axes_scatter, [0 t], [0 all_means(1,:)], [0 all_SEMs(1,:)], 'o-', 'Color', 'k', 'MarkerSize', 10, 'LineWidth', 1);
    hold on; box on;
    for ii = 2:size(all_means,1)
        h_datasets{ii} = errorbar(h_axes_scatter, [0 t], [0 all_means(ii,:)], [0 all_SEMs(1,:)], '-o', 'Color', class_colours(ii-1,:), 'MarkerSize', 10, 'LineWidth', 1);
    end

    %styling the plot
    xlim([0 plot_lim]);
    y_lims = get(h_axes_scatter, 'YLim');
    ylim(h_axes_scatter, [0 y_lims(2)]);
    xlabel('Lag time (s)');
    ylabel('MSD (μm^{2})');
    title('MSD-lag time plot computed molecule-by-molecule');
    class_names = ['Full trajectories'; class_names];
    legend([h_datasets{:}], class_names{:}, 'Location', 'northwest');
end


function [DStars, fits] = computeDStars(MSDs, t, mode, loc_prec, t_interframe)
%Compute D* for all diffusive states, Oliver Pambos, 14/11/2022.
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
%Apparent diffusion coefficient is computed as a linear fit to the MSD vs
%lag time data. This function computes D* for all (lag time, MSD) pairs
%passed to it; to reduce the range of fitting pass only a subset of
%(lag time, MSD) pairs.
%
%D* calculation is performed using three methods,
%       D* = MSD/4t without factoring in localisation precision
%       D* = MSD/4t - (sigma^2)/t
%       D* = MSD/t without factoring in dimensionality or localisation
%           precision
%
%While the time t can be passed into this function as a single row vector
%for many classes, t can also be passed as a matrix with the same number of
%rows as the matrix of MSDs. This latter option is more robust as it
%handles errors rare cases where a specific lag time entry many be missing
%in the MSD matrix in all molecules. In practice this could only happen for
%samples with exceptionally large amount of blinking, very small numbers of
%trajectories, and a large memory parameter during tracking. Note that
%specific error handling is not yet implemented for scenarios where this
%function is passed a pair of matrices where the number of rows in t is >1
%and less than the number of rows in MSD.
%
%Inputs
%------
%MSDs           (mat)   NxM matrix containing M MSD values for N+1 states,
%                           in units of micrometers squared
%t              (vec)   row vector of lag times associated with with the
%                           respective columns of the matrix MSDs, in
%                           seconds
%mode           (str)   string containg the mode for calculating D*; this
%                           is passed from the text contents of the GUI
%                           mode dropdown
%                           app.DcalculationmethodDropDown.Value, options
%                           are,
%                               'MSD/4t': D* = MSD/4t without factoring in
%                                   localisation precision
%                               'Correct for localisation error':
%                                   D* = MSD/4t - (sigma^2)/t 
%                               '4D*': D* = MSD/t without factoring in
%                                   dimensionality or localisation precision
%loc_prec       (float) localisation precision/error
%t_interframe   (float) time between frames; this contant is required in
%                           addition to t for robustness to handle rare
%                           cases where a sparse dataset may result in
%                           missed lag times
%
%Output
%------
%DStars (vec)   N+1 column vector of the apparent diffusion coefficients of
%                   N diffusive states, in units of micrometers squared per
%                   second element 1 is D* for all molecules, ignoring
%                   classifications elements >= 2 are D* for each
%                   individual labelled state/class
%fits   (mat)   linear fits to the MSD data,
%                   col 1: gradient of MSD/t
%                   col 2: y-axis offset
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %if t was passed as a row vector, duplicate it for each class, see notes in header
    if size(t,1) == 1 && size(MSDs,1) > 1
        t = repmat(t, size(MSDs, 1), 1);
    end
    
    %populate a matrix of fits to the averaged MSDs; column 1 is gradient of MSD/t, column 2 is y-axis offset
    fits = zeros(size(MSDs,1), 2);
    DStars = zeros(size(MSDs,1), 1);
    
    %perform a linear fit to the (lag time, MSD) data
    for ii = 1:size(MSDs,1)
        fits(ii,:) = polyfit(t(ii,:), MSDs(ii,:), 1);
    end
    
    %modify the fits according to mode requested by user
    switch mode
        case 'MSD/4t'
            DStars(:,1) = fits(:,1)./4;
            
        case 'Correct for localisation error'
            DStars(:,1) = (fits(:,1)./4) - loc_prec/t_interframe;
            
        case '4D*'
            %no action currently required

        otherwise
            error("IVK:computeDStars:UnknownDiffusionCalculationMethod");
    end
end