function [] = genHeatmap(app)
%Generate heatmaps of all states, Oliver pambos, 23/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genHeatmap
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
%This function integrates into the main GUI existing heatmapping functions
%that previously operated on saved analysis files, as well as my earlier
%SMLM image reconstruction code developed for SuperCell and tat-transport
%projects from 2019 - 2021. This code is integrated into the GUI here prior
%to public release to enable users to better explore spatial information in
%their data.
%
%There is some performance overhead in that heatmap data is processed for
%all heatmaps including those not requested by the user. As there is no lag
%in figure generation using typical datasets on a basic desktop machine,
%this has been retained in favour of code readability by eliminating
%multiple switch statements.
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%transformCoordinates() - local to this .m file
%generate2DHeatmap()    - local to this .m file
%plotHeatmap()          - local to this .m file
%plotClassHeatmap()     - local to this .m file
%createColorMap()       - local to this .m file
%drawCellOutline()      - local to this .m file
%reconstructImage()     - local to this .m file
%gaussianPSF()          - local to this .m file
%getSubstructName()     - local to this .m file
%getSourceDescription() - local to this .m file
    
    %get user inputs from GUI
    cell_len_um     = app.ModelcelllengthmSpinner.Value;
    cell_wid_um     = app.ModelcellwidthmSpinner.Value;
    bin_wid_um      = app.HeatmapBinsizenmSpinner.Value / 1000;
    width_fig       = app.HeatmapfigurewidthpxSpinner.Value;
    height_fig      = app.HeatmapfigureheightpxSpinner.Value;
    classes_to_plot = app.HeatmapAvailableDatasetsTree.CheckedNodes;
    heatmap_style   = app.HeatmapstyleDropDown.Value;
    PSF_FWHM_um     = app.ReconstructionPSFFWHMSpinner.Value / 1000;
    bg_colour       = app.BackgroundcolourDropDown.Value;
    
    %calc number of bins based on cell dimensions and bin size
    N_bins_x = ceil(cell_len_um / bin_wid_um);
    N_bins_y = ceil(cell_wid_um / bin_wid_um);

    %get relevant column indices
    idx_long = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Longitude');
    idx_lat  = findColumnIdx(app.movie_data.params.column_titles.tracks, 'Latitude');    
    
    %determine selected substruct name from the dropdown
    selected_value      = app.InsightsSourcedataDropDown.Value;
    substruct_name      = getSubstructName(selected_value);
    source_description  = getSourceDescription(selected_value);
    
    %init empty heatmap for all locs
    accumulated_heatmap = zeros(N_bins_y, N_bins_x);
    
    %init heatmaps for each class
    N_classes     = length(app.movie_data.params.class_names);
    class_heatmaps  = zeros(N_bins_y, N_bins_x, N_classes);
    
    %gen reference PSF if required for reconstruction
    if strcmp(heatmap_style, 'Normalised image reconstruction')
        PSF = gaussianPSF(PSF_FWHM_um, bin_wid_um);
    end
    
    %loop over cells
    for ii = 1:size(app.movie_data.results.(substruct_name).LabelledMols, 1)
        curr_cell_data  = app.movie_data.results.(substruct_name).LabelledMols{ii, 1}.Mol;
        curr_cell_locs  = curr_cell_data(:, [idx_long, idx_lat]);
        classes         = curr_cell_data(:, end);
        
        %filter and transform coords
        [X, Y, valid] = transformCoordinates(curr_cell_locs, cell_len_um, cell_wid_um);
        
        %plot either regular 2D heatmap or reconstructed image
        if strcmp(heatmap_style, '2D binned heatmap')
            %add all locs in current cell to general heatmap
            all_heatmap_data    = generate2DHeatmap(X, Y, valid, N_bins_x, N_bins_y, cell_len_um, cell_wid_um);
            accumulated_heatmap = accumulated_heatmap + all_heatmap_data;
            
            %accumulate class heatmaps with segmented data in curr cell
            for kk = 1:N_classes
                class_valid = valid & (classes == kk);
                class_heatmap_data = generate2DHeatmap(X, Y, class_valid, N_bins_x, N_bins_y, cell_len_um, cell_wid_um);
                class_heatmaps(:, :, kk) = class_heatmaps(:, :, kk) + class_heatmap_data;
            end

        elseif strcmp(heatmap_style, 'Normalised image reconstruction')
            %add all locs in curr cell to general reconstructed image
            all_reconstructed_image = reconstructImage(X, Y, valid, N_bins_x, N_bins_y, cell_len_um, cell_wid_um, PSF);
            accumulated_heatmap     = accumulated_heatmap + all_reconstructed_image;
            
            %accumulate reconstructed images for each class with segmented data in curr cell
            for kk = 1:N_classes
                class_valid = valid & (classes == kk);
                class_reconstructed_image = reconstructImage(X, Y, class_valid, N_bins_x, N_bins_y, cell_len_um, cell_wid_um, PSF);
                class_heatmaps(:, :, kk) = class_heatmaps(:, :, kk) + class_reconstructed_image;
            end
        end

    end

    %plot single heatmap containing all localisations for all classes if requested by user
    if any(strcmp({classes_to_plot.Text}, 'All localisastions combined'))
        plotHeatmap(accumulated_heatmap, cell_len_um, cell_wid_um, source_description, width_fig, height_fig, bg_colour);
    end

    %plot heatmaps for each class requested by user
    for kk = 1:N_classes
        if any(strcmp({classes_to_plot.Text}, app.movie_data.params.class_names{kk}))
            colour_map = createColourMap(app.movie_data.params.event_label_colours(kk, :), bg_colour);
            plotClassHeatmap(class_heatmaps(:, :, kk), cell_len_um, cell_wid_um, colour_map, app.movie_data.params.class_names{kk}, source_description, width_fig, height_fig, bg_colour);
        end
    end
end


function [X, Y, valid] = transformCoordinates(data, cell_len_um, cell_wid_um)
%Perform coordinate transform onto heatmap, Oliver Pambos, 23/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: transformCoordinates
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
%This function takes the position of each localisation and transforms it to
%its true position within the model cell. Note that this is necessary due
%to the definition of latitude when cell coordinates are engineered. The
%latitude is defined as the distance between the cell midline and the
%perpendicular cell boundary between the closest point on the midline and
%the intersection of a virtual line extending from this closest midline
%point through the localisation and the cell boundary. As a consequence,
%for a localisation in an end cap, a value of +0.49 can be very close to
%the cell midline if it is very close to the cell pole. These latitude
%coordinates therefore need to be transformed back into a model cell before
%generating a heatmap to ensure they are positioned correctly.
%
%As this function is already processing cellular coordinates, for
%efficiency this function also constructs a list of valid localisations,
%which enables later functions to restrict plotting to only localisations
%that originally fell within the cell boundary. This enables a great deal
%of flexibility in other parts of the system, and in input data analysis
%pipelines to capture localisations outside of the cell boundary that may
%otherwise influence the data analysis when discarded - for example missing
%localisations breaking up tracks which are membrane-peripheral - this
%greatly improves data analysis of membrane proteins, periplasmic
%components, and surface proteins such as those involved in gliding
%motility.
%
%Possible performance improvements from vectorizing the loop, but time
%taken to thoroughly test the change is not currently worth the small
%performance gain for this process which is virtually instant with typical
%experimental datasets.
%
%Inputs
%------
%data           (mat)   Nx2 matrix of (x,y) coordinates
%cell_len_um    (float) model cell length in major axis (in micrometers)
%cell_wid_um    (float) model cell width in minor axis (in micrometers)
%
%Output
%------
%X      (vec)   column vector of localisation x-data
%Y      (vec)   column vector of localisation y-data, corresponding to X
%valid  (vec)   boolean column vector, with 'True' identifying which
%                   entries of X and Y fall inside the cell boundary
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None

    %scale data to cell length and width
    X = data(:, 1) * cell_len_um;
    Y = data(:, 2) * cell_wid_um;

    %boolean array to keep track of valid data points (those falling inside cell boundary)
    valid = true(size(X));
    
    %rescale latitude (Y) by cell fractional distance of loc from cell midline to cell boundary at that point, which varies inside end caps
    for ii = 1:size(X, 1)
        %compute whether loc longitude positions it within an end cap
        cap_pos = abs(X(ii)) - (cell_len_um / 2 - cell_wid_um / 2);
        
        %if in end cap, calc radius at that longitude, then scale
        if cap_pos > 0
            radius = sqrt((cell_wid_um / 2)^2 - cap_pos^2);
            %scale latitude based on the position within the cap.
            Y(ii) = Y(ii) * (radius / (cell_wid_um / 2));
            
            %mark loc as invalid if it falls outside the calculated radius
            if abs(Y(ii)) > radius
                valid(ii) = false;
            end
        
        %if it's not in the end cap, still assign invalid if outside of cell boundary
        elseif abs(Y(ii)) > cell_wid_um/2
            valid(ii) = false;
        end
    end
end


function [heatmap_data] = generate2DHeatmap(X, Y, valid, N_bins_x, N_bins_y, cell_len_um, cell_wid_um)
%Generate binned 2D heatmap data of localisations in a model cell, Oliver
%Pambos, 04/09/2021.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: generate2DHeatmap
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
%This function generates a 2D heatmap of localisations by binning the valid
%longitude and latitude coordinates of the localisations into a specified
%along the major and minor model cell axes.
%
%Inputs
%------
%X              (vec)   column vector of x-coordinates of localisations
%Y              (vec)   column vector of y-coordinates of localisations
%valid          (vec)   boolean column vector indicating valid
%                           localisations, being those which fall within
%                           the cell boundary
%N_bins_x       (int)   number of bins along the x-axis (major, or longitudinal axis)
%N_bins_y       (int)   number of bins along the y-axis (minor, or latitudinal axis)
%cell_len_um    (float) length of model cell in micrometers
%cell_wid_um    (float) width of model cell in micrometers
%
%Output
%------
%heatmap_data   (mat)   Matrix representing the 2D heatmap of binned localisations
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %filter locs to include only those falling within cell boundary
    X_valid = X(valid);
    Y_valid = Y(valid);
    
    %define bin edges
    x_edges = linspace(-cell_len_um/2, cell_len_um/2, N_bins_x + 1);
    y_edges = linspace(-cell_wid_um/2, cell_wid_um/2, N_bins_y + 1);
    
    %generate histogram
    heatmap_data = histcounts2(Y_valid, X_valid, y_edges, x_edges);
end


function plotHeatmap(heatmap_data, cell_len, cell_wid, source_description, width_fig, height_fig, bg_colour)
%Plot a heatmap for all localisations, Oliver Pambos, 23/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotHeatmap
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
%heatmap_data       (mat)   heatmap data to be plotted
%cell_len           (float) length of the model cell along its major axis (in micrometers)
%cell_wid           (float) width of the model cell along its minor axis (in micrometers)
%source_description (str)   description of the source of annotations to be used in the figure title
%width_fig          (int)   width of figure (in pixels)
%height_fig         (int)   height of figure (in pixels)
%bg_colour          (str)   determines the background colour of the plot,
%                               and start of the colour map; options are,
%                                   "Black" (default)
%                                   "White"
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%drawCellOutline()
    
    switch bg_colour
        case "Black"
            bg_code         = 'k';
            txt_code        = 'w';
            mesh_style_str  = 'w--';
        case "White"
            bg_code         = 'w';
            txt_code        = 'k';
            mesh_style_str  = 'k--';
        otherwise
            %default to black, text white, and mesh white with dashed lines
            bg_code         = 'k';
            txt_code        = 'w';
            mesh_style_str  = 'w--';
    end
    
    figure('Position', [100, 100, width_fig, height_fig]);
    
    %plotting
    imagesc([-cell_len / 2, cell_len / 2], [-cell_wid / 2, cell_wid / 2], heatmap_data);
    axis equal; axis off;
    set(gcf, 'Color', bg_code);
    colormap('hot');
    title("Density heatmap of all localisations " + source_description, 'Color', txt_code, 'FontSize', 16);
    
    %colour bar
    cb = colorbar('south');
    set(cb, 'Color', txt_code, 'FontSize', 12);
    ylabel(cb, 'Normalised density of localisations', 'Color', txt_code, 'FontSize', 16);
    
    %cell outline
    drawCellOutline(cell_len, cell_wid, mesh_style_str);
end



function [] = plotClassHeatmap(heatmap_data, cell_len, cell_wid, colour_map, class_name, source_description, width_fig, height_fig, bg_colour)
%Plot the heatmap for a single class for all segmented localisations in the
%dataset, Oliver Pambos, 23/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: plotClassHeatmap
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
%heatmap_data       (mat)   heatmap data to be plotted
%cell_len           (float) length of the model cell along its major axis (in micrometers)
%cell_wid           (float) width of the model cell along its minor axis (in micrometers)
%colour_map         (mat)   colour map for the specific class to be plotted
%class_name         (str)   name of the class
%source_description (str)   description of the source of annotations to be used in the figure title
%width_fig          (int)   width of figure (in pixels)
%height_fig         (int)   height of figure (in pixels)
%bg_colour          (str)   determines the background colour of the plot,
%                               and start of the colour map; options are,
%                                   "Black" (default)
%                                   "White"
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%drawCellOutline()
    
    switch bg_colour
        case "Black"
            bg_code         = 'k';
            txt_code        = 'w';
            mesh_style_str  = 'w--';
        case "White"
            bg_code         = 'w';
            txt_code        = 'k';
            mesh_style_str  = 'k--';
        otherwise
            %default to black, text white, and mesh white with dashed lines
            bg_code         = 'k';
            txt_code        = 'w';
            mesh_style_str  = 'w--';
    end
    
    figure('Position', [100, 100, width_fig, height_fig]);
    
    %min-max normalize heatmap (0 to 1)
    scaled_heatmap_data = (heatmap_data - min(heatmap_data(:))) / (max(heatmap_data(:)) - min(heatmap_data(:)));
    
    %plotting
    imagesc([-cell_len / 2, cell_len / 2], [-cell_wid / 2, cell_wid / 2], scaled_heatmap_data);
    axis equal; axis off;
    set(gcf, 'Color', bg_code);
    colormap(colour_map);
    title("Density heatmap for localisations in the class '" + lower(class_name) + "' " + source_description, 'Color', txt_code, 'FontSize', 16);
    
    %colour bar
    h_cb = colorbar('south');
    set(h_cb, 'Color', txt_code, 'FontSize', 12);
    ylabel(h_cb, 'Normalised density of localisations', 'Color', txt_code, 'FontSize', 16);
    
    %cell outline
    drawCellOutline(cell_len, cell_wid, mesh_style_str)
    
    %ensure displaying full range of data
    clim([0 1]);
end


function colour_map = createColourMap(RGB, bg_colour)
%Construct custom colour map for the class running from black to its
%defined colour, Oliver Pambos, 23/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: createColorMap
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
%RGB        (vec)   3-element row vector containing the colour of a class
%bg_colour  (str)   determines the background colour of the plot, and start
%                       of the colour map; options are,
%                           "Black" (default)
%                           "White"
%
%Output
%------
%colour_map (mat)   256x3 matrix representing the colour map transitioning
%                        from black to the specified RGB color
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    switch bg_colour
        case "Black"
            bg_code = 0;
        case "White"
            bg_code = 1;
        otherwise
            %default to black
            bg_code = 0;
    end

    %generate colormap that transitions using a colour map from the background colour to the specified RGB colour
    colour_map = [linspace(bg_code, RGB(1), 256)', linspace(bg_code, RGB(2), 256)', linspace(bg_code, RGB(3), 256)'];
end


function [] = drawCellOutline(cell_len, cell_wid, mesh_style_str)
%Annotate onto a heatmap a cell boundary, Oliver Pambos, 23/05/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: drawCellOutline
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
%This function draws onto an already open, currently focused plot, the
%outline of the model cell. Plotting is fast enough that user refocusing of
%figures is not relevant here, but could in future pass axes handles from
%calling function if necessary.
%
%Inputs
%------
%cell_len   (float) length of model cell, in micrometers
%cell_wid   (float) width of model cell, in micrometers
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %define a semi-circle
    theta = linspace(-pi/2, pi/2, 100);
    
    %left cap
    x_cap_left = (-cell_len / 2 + cell_wid / 2) - cell_wid / 2 * cos(theta);
    y_cap_left = -cell_wid / 2 * sin(theta);
    
    %right cap
    x_cap_right = (cell_len / 2 - cell_wid / 2) - cell_wid / 2 * cos(theta + pi);
    y_cap_right = cell_wid / 2 * sin(theta + pi);
    
    %combine caps to create continuous outline
    x_outline = [x_cap_left, fliplr(x_cap_right), x_cap_left(1)];
    y_outline = [y_cap_left, fliplr(y_cap_right), y_cap_left(1)];
    
    hold on;
    plot(x_outline, y_outline, mesh_style_str, 'LineWidth', 2);
end


function [reconstructed_image] = reconstructImage(X, Y, valid, N_bins_x, N_bins_y, cell_len_um, cell_wid_um, PSF)
%Generate a STORM-like reconstructed super-resolution image from
%localisation coordinate data, Oliver Pambos, 04/09/2021.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: reconstructImage
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
%This is a heavily simplified, edited version of my super-res image
%reconstruction code developed for the tat-export project 2019 - 2021. Here
%I have removed the sub-pixel computations to improve performance and to
%make the code more readable. The model cell dimensions have been
%incorporated here to set the size of the blank image.
%
%Inputs
%------
%X              (vec)   Nx1 column vector of x-coordinates to place in the image
%Y              (vec)   Nx1 column vector of y-coordinates to place in the image
%valid          (vec)   Nx1 bool column vector identifying which entries in X and Y
%                           to include in the reconstructed image
%N_bins_x       (int)   number of bins in the x-axis of reconstructed image
%N_bins_y       (int)   number of bins in the y-axis of reconstructed image
%cell_len_um    (float) length of model cell in micrometers
%cell_wid_um    (float) width of model cell in micrometers
%PSF            (mat)   matrix containing the PSF to be placed at each
%                           localisation in reconstructed image
%
%Output
%------
%reconstructed_image    (mat)   matrix containing reconstructed image
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %find PSF peak pos - critical when PSF matrix width is even
    [psf_center_y, psf_center_x] = find(PSF == max(PSF(:)), 1);
    
    %keep only valid points within cell
    X_val = X(valid);
    Y_val = Y(valid);
    
    %initialize blank reconstructed image and set bins
    reconstructed_image = zeros(N_bins_y, N_bins_x);
    x_bin_wid = cell_len_um / N_bins_x;
    y_bin_wid = cell_wid_um / N_bins_y;
    
    %loop through localizations adding PSFs to reconstructed image
    for ii = 1:size(X_val, 1)
        %calculate pos'n of loc in image
        x_pos = round((X_val(ii) + cell_len_um / 2) / x_bin_wid);
        y_pos = round((Y_val(ii) + cell_wid_um / 2) / y_bin_wid);
        
        %calc extents of PSF the image
        x_lo = max(1, x_pos - psf_center_x + 1);
        x_hi = min(N_bins_x, x_pos + size(PSF, 2) - psf_center_x);
        y_lo = max(1, y_pos - psf_center_y + 1);
        y_hi = min(N_bins_y, y_pos + size(PSF, 1) - psf_center_y);
        
        %calc corresponding PSF ranges
        PSF_x_lo = 1 + (x_lo - (x_pos - psf_center_x + 1));
        PSF_x_hi = size(PSF, 2) - ((x_pos + size(PSF, 2) - psf_center_x) - x_hi);
        PSF_y_lo = 1 + (y_lo - (y_pos - psf_center_y + 1));
        PSF_y_hi = size(PSF, 1) - ((y_pos + size(PSF, 1) - psf_center_y) - y_hi);
        
        %add PSF to image
        reconstructed_image(y_lo:y_hi, x_lo:x_hi) = reconstructed_image(y_lo:y_hi, x_lo:x_hi) + PSF(PSF_y_lo:PSF_y_hi, PSF_x_lo:PSF_x_hi);
    end
end


function [PSF] = gaussianPSF(FWHM, bin_wid_um)
%Construct the model PSF, Oliver Pambos, 04/09/2021.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: gaussianPSF
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
%Standard deviation now used, via FWHM = 2*sqrt(2*ln(2))*sigma.
%
%Inputs
%------
%FWHM       (float) Full Width Half Maximum of PSF
%bin_wid_um (float) bin width in micrometers
%
%Output
%------
%PSF        (mat)   matrix containing the normalized PSF (sums to 1)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %convert to stdev, define extent of PSF matrix, and initialise empty grid
    st_dev      = FWHM / (2 * sqrt(2 * log(2)));
    PSF_extent  = st_dev * 6;
    x           = -PSF_extent : bin_wid_um : PSF_extent;
    [X, Y]      = meshgrid(x, x);
    
    %generate PSF matrix, by solving Gaussian equation for each pixel, then perform integral normalisation
    PSF = exp(-(X.^2 + Y.^2) / (2 * st_dev^2));
    PSF = PSF / sum(PSF(:));
end


function [substruct_name] = getSubstructName(value)
%Helper function for mapping annotation source to a text description for
%plotting, Oliver Pambos, 08/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getSubstructName
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
%value          (str)   string containing the user-selected dropdown option
%                           in [Insights] > [Dataset overview] tab
%
%Output
%------
%substruct_name (str)   name of the substruct containing the selected
%                           annotations
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    switch value
        case 'Human annotations'
            substruct_name = 'VisuallyLabelled';
        case 'Ground truth'
            substruct_name = 'GroundTruth';
        case 'Labels from RF'
            substruct_name = 'RFLabelled';
        case 'Labels from LSTM'
            substruct_name = 'LSTMLabelled';
        case 'Labels from BiLSTM'
            substruct_name = 'BiLSTMLabelled';
        case 'Labels from GRU'
            substruct_name = 'GRULabelled';
        case 'Labels from BiGRU'
            substruct_name = 'BiGRULabelled';
        otherwise
            error('Unknown annotation type selected.');
    end
end


function source_description = getSourceDescription(value)
%Helper function to generate the suitable text description of annotation
%source for heatmap plotting, Oliver Pambos, 08/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getSourceDescription
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
%value              (str)   string containing the user-selected dropdown
%                               option in [Insights] > [Dataset overview]
%
%Output
%------
%source_description (str)   partial title string describing the source of
%                               annotations used to generate the heatmap
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    switch value
        case 'Human annotations'
            source_description = 'from human annotations';
        case 'Ground truth'
            source_description = 'from ground truth';
        case 'Labels from RF'
            source_description = 'annotated using a random forest model';
        case 'Labels from LSTM'
            source_description = 'annotated using an LSTM model';
        case 'Labels from BiLSTM'
            source_description = 'annotated using a bidirectional LSTM model';
        case 'Labels from GRU'
            source_description = 'annotated using a GRU model';
        case 'Labels from BiGRU'
            source_description = 'annotated using a bidirectional GRU model';
        otherwise
            error('Unknown annotation type selected.');
    end
end