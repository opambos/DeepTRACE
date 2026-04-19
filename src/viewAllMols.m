function [] = viewAllMols(app)
%Produce an illustration of every molecule in a dataset and export to PDF,
%30/03/2023.
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
%This function takes some time to render hundreds of molecules. Currently
%there is no native way to construct a multi-page PDF with MATLAB, so these
%are saved as separate documents.
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
%plotColourTrack()
%getFeatureStats()
    
    %initialise some sensible values for display
    mol_per_page = 32;
    N_rows = 4;
    N_cols = 8;
    
    %ensure feature ranges exist for colouring by feature
    getFeatureStats(app, true);
    
    feat_idx = findColumnIdx(app.movie_data.params.column_titles.tracks, app.GalleryFeatureDropDown.Value);
    plot_style = app.TrackcolouringDropDown.Value;
    
    %generate a list of unique cell and molecule IDs
    mol_list = [];
    count = 1;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        %obtain all mol_IDs for current cell
        curr_molIDs = unique(app.movie_data.cellROI_data(ii).tracks(:,4));
        
        for jj = 1:size(curr_molIDs, 1)
            mol_list(count, 1) = ii;
            mol_list(count, 2) = curr_molIDs(jj);
            count = count+1;
        end
    end
    
    N_windows = ceil(size(mol_list,1) / mol_per_page);
    app.textout.Value = "Producing overview of all images, this may take several minutes, please do not interact with the computer until this has completed....";
    
    %loop over individual pages to be generated
    for ii = 1:N_windows
        %enable user to exit gallery production
        if app.StopgalleryButton.Value
            app.StopgalleryButton.Value = false;
            return;
        end
        figure;
        %generate a new page
        t = tiledlayout(N_rows,N_cols); t.TileSpacing = 'tight'; t.Padding = 'none';
        
        %obtain range of molecules to display
        start_mol = (ii - 1) * mol_per_page + 1;
        end_mol = min(ii * mol_per_page, size(mol_list,1));
        
        %display each molecule in a separate tile
        for jj = start_mol:end_mol
            cell_ID  = mol_list(jj,1);
            mol_ID   = mol_list(jj,2);
            track = app.movie_data.cellROI_data(cell_ID).tracks(app.movie_data.cellROI_data(cell_ID).tracks(:,4) == mol_ID,:);
            
            ax1 = nexttile(t);
            
            %plot the overlay
            hold on; axis equal; axis off;
            title(ax1, ['Cell ' num2str(cell_ID) '; Mol ' num2str(mol_ID)]);
            colormap(ax1, gray);
            imagesc(ax1, app.movie_data.cellROI_data(cell_ID).overlay);
            
            %plot track according to user style selection
            switch plot_style
                case "Feature"
                    plotColourTrack(ax1, 'Colour', 'Feature', [track(:,1) - app.movie_data.cellROI_data(cell_ID).overlay_offset(2), track(:,2) - app.movie_data.cellROI_data(cell_ID).overlay_offset(1)], 0, track(:, feat_idx), app.movie_data.params.feature_stats(:, feat_idx));
                case "Classified state"
                    
                otherwise
                    
            end
        end
        
        drawnow;
        %save the page
        % set(gcf, 'WindowState', 'maximized');
        % filename = strcat('Dataset_overview',app.movie_data.params.title{1, 1},'_page_',num2str(ii),'.pdf');
        % exportgraphics(gcf,filename,'ContentType','vector');
        % app.textout.Value = (strcat('Progress: ', num2str(end_mol), '/', num2str(size(mol_list,1))));
    end
    
    app.textout.Value = "Completed gallery illustration of all molecules in dataset";
end