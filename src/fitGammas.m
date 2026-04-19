function [] = fitGammas(app, h_axes, h_hist, binned_data)
%Fit Gamma mixture model to binned diffusion coefficient plot, 01/12/2024.
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
%This function applies fits to a pre-existing histogram figure, whose axes,
%plotting handles and binned data are passed as inputs. This function is
%designed to be called from genDHistograms, and has various GUI inputs to
%determine the style of the fitting used. This function is called when the
%[Perform Gamma fit] checkbox is ticked.
%
%This function enables the fitting of arbitrary numbers of Gamma functions,
%plotting the individual components, and the sum. It also enables optional
%user input for the initial guesses for the diffusion coefficient D and
%'occupancy' (relative integrated area) for individual Gamma components. If
%the user does not provide these optional inputs, or the number of inputs
%and requested components is inconsistent, then initial guesses are
%generated with equal occupancy, and with uniformly spaced diffusion
%coefficients across the range 0 to 0.5 um^2/s.
%
%The fitting process is restricted to positive diffusion coefficients,
%using the method described in M. Stracy et al., PNAS, 2015 (DOI:
%10.1073/pnas.1507592112). This is performed using lsqcurvefit.
%
%Colours selected for each fit are obtained from the state/class colours
%present in the RGB-state matrix app.movie_data.params.event_label_colours.
%When further components are requested, exceeding the number of entries,
%further colours are generated with a uniform random number generator for
%RGB triplets.
%
%Inputs
%------
%app            (handle)    main GUI handle
%h_axes         (handle)    handle for axes containing histogram
%h_hist         (handle)    histogram/bar chart handle, but the physicist
%                               in me couldn't bring myself to call it
%                               h-bar
%binned_data    (mat)       Nx2 mat with columns of bin_centres and counts
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    bin_centres = binned_data(:, 1);
    counts      = binned_data(:, 2);
    N_gammas    = app.DiffusionHistNumberofGammasSpinner.Value;
    N_steps     = app.DiffusionHistMaxlagframesSpinner.Value;
    
    %get total area under histogram for scaling
    integrated_area = sum(counts);
    
    %========================================
    %Set init guesses for fits (D & A values)
    %========================================
    if app.DiffusionHistSetmanualinitialGammafitparametersCheckBox.Value
        
        table_data = app.DiffusionHistGammaInitialValues.Data;
        
        %if number of rows in tables matches requested number of Gammas (this is no longer really req'd as checks are handled by GUI)
        if size(table_data, 1) == N_gammas
            %use the table values as init guesses
            D_values = table_data.Coefficients;
            A_values = table_data.Occupancy;
            
            init_guess = zeros(1, 2 * N_gammas);
            init_guess(1:2:end) = D_values;
            init_guess(2:2:end) = A_values;
        else
            %fallback to automatic values (uniformly distributed)
            %warning("Incorrect number of initial guesses for requested Gamma components. Switching to automatic initialisation.");
            init_guess = zeros(1, 2 * N_gammas);
            init_guess(1:2:end) = linspace(0.1, 0.5, N_gammas);
            init_guess(2:2:end) = integrated_area / N_gammas;
        end
    else
        %automatic init
        init_guess          = zeros(1, 2 * N_gammas);
        init_guess(1:2:end) = linspace(0.1, 0.5, N_gammas);
        init_guess(2:2:end) = integrated_area / N_gammas;
    end
    
    %=====================
    %Perform Gamma fitting
    %=====================
    %set lower and upper bounds for params
    lb = zeros(size(init_guess));
    ub = [repmat(max(bin_centres), 1, N_gammas), repmat(integrated_area, 1, N_gammas)]; %[D, A]
    
    %define Gamma PDF f'n and objective f'n for lsqcurvefit
    gamma_PDF = @(x, params, n) sum(cell2mat(arrayfun(@(i) params(2*i) .* (n / params(2*i-1))^n .* x.^(n-1) .* exp(-n .* x ./ params(2*i-1)) ./ factorial(n-1), 1:N_gammas, 'UniformOutput', false)), 2);
    objective_fn = @(params, x) gamma_PDF(x, params, N_steps);
    
    %perform fitting, with suppressed output
    options = optimset('Display', 'off');
    fitted_params = lsqcurvefit(objective_fn, init_guess, bin_centres, counts, lb, ub, options);
    
    %get fitted D (odds) and A (evens) parameters
    fitted_D = fitted_params(1:2:end);
    fitted_A = fitted_params(2:2:end);
    
    %evaluate fitted values at bin centres
    y_fit = gamma_PDF(bin_centres, fitted_params, N_steps);
    
    %define plot colours: use known colours for states first, then go to random colours
    event_colours   = app.movie_data.params.event_label_colours;
    N_colours       = size(event_colours, 1);
    if N_gammas <= N_colours
        colours = event_colours(1:N_gammas, :);
    else
        colours = [event_colours; rand(N_gammas - N_colours, 3)];
    end
    
    areas   = zeros(1, N_gammas);
    h_fits  = gobjects(N_gammas, 1);
    
    %===============
    %Plot Gamma fits
    %===============
    hold(h_axes, 'on');
    for ii = 1:N_gammas
        %define & plot an individual Gamma f'n
        single_gamma_PDF    = fitted_A(ii) .* (N_steps / fitted_D(ii))^N_steps .* bin_centres.^(N_steps - 1) .* exp(-N_steps .* bin_centres ./ fitted_D(ii)) ./ factorial(N_steps - 1);
        h_fits(ii)          = plot(h_axes, bin_centres, single_gamma_PDF, '-', 'LineWidth', 2, 'Color', colours(ii, :));
        
        %integrate area under curve for occupancy
        areas(ii) = trapz(bin_centres, single_gamma_PDF);
    end
    
    %plot sum of Gammas
    h_sum_fit = plot(h_axes, bin_centres, y_fit, 'k--', 'LineWidth', 2);
    hold(h_axes, 'off');
    
    %compute occupancies for each fit (as %)
    occupancies_pc = (fitted_A / sum(fitted_A)) * 100;
    
    %==============
    %Display legend
    %==============
    if strcmp(app.DiffusionHistStateDropDown.Value, "Stack states")
        %legend for stacked plot
        state_names             = flipud(app.movie_data.params.class_names);    %flipud to match flipped order of states in genDHistogram()
        gamma_legend_entries    = arrayfun(@(ii) sprintf('D%d = %.2f (%.1f%%)', ii, fitted_D(ii), occupancies_pc(ii)), 1:N_gammas, 'UniformOutput', false);
        legend_entries          = [state_names; gamma_legend_entries'; {'Total Fit'}];
        legend(h_axes, [h_hist(:); h_fits; h_sum_fit], legend_entries, 'Location', 'Best');
    else
        %legend for non-stacked plots
        legend_entries      = cell(1, N_gammas + 2); %single Gamma components + sum + histogram
        legend_entries{1}   = 'Histogram Data';
        for ii = 1:N_gammas
            legend_entries{ii + 1} = sprintf('D%d = %.2f (%.1f%%)', ii, fitted_D(ii), occupancies_pc(ii));
        end
        legend_entries{end} = 'Sum of Gammas';
        legend(h_axes, [h_hist; h_fits; h_sum_fit], legend_entries, 'Location', 'Best');
    end
    

    %=======================
    %Display results to user
    %=======================
    %update table with normalized percentages
    updated_table = table(fitted_D', (occupancies_pc / 100)', 'VariableNames', {'Coefficients', 'Occupancy'});
    app.DiffusionHistGammaInitialValues.Data = updated_table;
    
    %present fitting results to user; normalize A values to sum to 1
    normalized_A_textout    = fitted_A / sum(fitted_A);
    fitted_params_text      = arrayfun(@(ii) sprintf('Component %d: D = %.4f, A = %.4f', ii, fitted_D(ii), normalized_A_textout(ii)), 1:N_gammas, 'UniformOutput', false);
    app.textout.Value       = sprintf("Fitted Parameters:\n%s", strjoin(fitted_params_text, newline));
    
    %update table with fitted parameters if checkbox is not selected
    if ~app.DiffusionHistSetmanualinitialGammafitparametersCheckBox.Value
        rel_occupancy = areas / sum(areas);
        new_table_data = table(fitted_D', rel_occupancy', 'VariableNames', {'Coefficients', 'Occupancy'});
        app.DiffusionHistGammaInitialValues.Data = new_table_data;
    end
    
    %====================================
    %Generate residuals plot if requested
    %====================================
    if app.DiffusionHistPlotresidualsCheckBox.Value
        residuals       = counts - y_fit;
        res_fig         = figure('Name', 'Residuals', 'NumberTitle', 'off');
        ax_residuals    = axes(res_fig);
        plot(ax_residuals, bin_centres, residuals, 'b-', 'LineWidth', 1.5);
        title(ax_residuals, 'Residuals to Gamma mixture fit');
        xlabel(ax_residuals, 'Diffusion coefficient (\mum^2/s)');
        ylabel(ax_residuals, 'Residuals');
        grid(ax_residuals, 'on');
        set(ax_residuals, 'Box', 'on');
    end
end