function [] = viewAllMols(app)
%Produce an illustration of every molecule in a dataset and export to PDF,
%Oliver Pambos, 30/03/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: viewAllMols
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

