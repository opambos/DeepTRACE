function [] = computeArrivalTimes(app)
%Computes and displays the molecule arrival times, Oliver Pambos,
%11/03/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeArrivalTimes
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
%This function compiles a histogram of molecule arrival times; the time at
%which each trajectory appears in the recording. An arrival time matrix is
%formed for each molecule in the dataset consisting of the following
%columns,
%
%   col 1: cell ID
%   col 2: mol ID
%   col 3: frame number at which molecule first appeared
%   col 4: time point at which molecule first appeared
%
%While this matrix is only currently used internally, it is intentionally
%robust against scenarios where cell_IDs do not match indices in the cell
%list (cellROI_data) for example from deletion or re-organisation in cell
%segmentation software. While this matrix is only used internally by this
%function, this is robust against such scenarios incase a future
%application requires access to this data.
%
%Note that there is scope here to optimise performance by eliminating the
%step during which an entire molecule track is assigned to mol_rows;
%however runtime for this entire function even on the slowest machines with
%the largest possible SMLM datasets is virtually instantaneous, and
%substantially slower than even the plot-to-screen functionality. It
%therefore does not currently make sense to optimise at this stage.
%
%Input
%-----
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %get total frames
    if isfield(app.movie_data.params, 'frames_per_file')
        t_experiment = sum(app.movie_data.params.frames_per_file) ./ app.movie_data.params.frame_rate;
    else
        t_experiment = fitsinfo(fullfile(app.movie_data.params.ffPath, app.movie_data.params.ffFile)).PrimaryData.Size(3) ./ app.movie_data.params.frame_rate;
    end
    
    %get the column indices
    frame_col   = findColumnIdx(app.movie_data.params.column_titles.tracks, "Frame");
    mol_ID_col  = findColumnIdx(app.movie_data.params.column_titles.tracks, "MolID");
    cell_ID_col = findColumnIdx(app.movie_data.params.column_titles.tracks, "Cell ID");
    
    %ensure that columns are found
    if frame_col == 0 || mol_ID_col == 0
        app.textout.Value = "Arrival times could not be computed as the source data does not contain frame and molecule IDs. " + ...
            "This likely results from erroneous column titles provided in the source tracking file.";
        return;
    end
    
    %initialize the new matrix to store results
    count = 0;
    for ii = 1:size(app.movie_data.cellROI_data,1)
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
            count = count + size(unique(app.movie_data.cellROI_data(ii).tracks(:,mol_ID_col)), 1);
        end
    end
    arrival_mat = zeros(count, 4);
    
    %loop over cells
    count = 0;
    for ii = 1:length(app.movie_data.cellROI_data)
        if isempty(app.movie_data.cellROI_data(ii).tracks)
            continue;
        end

        %find unique molecule IDs for current cell
        mol_IDs = unique(app.movie_data.cellROI_data(ii).tracks(:, mol_ID_col));
        
        %loop over molecules
        for jj = 1:length(mol_IDs)
            mol_ID = mol_IDs(jj);
            
            %find rows corresponding to mol_ID & record first frame data
            mol_rows = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:, mol_ID_col) == mol_ID, :);
            count    = count + 1;
            arrival_mat(count, 1:3) = [mol_rows(1, cell_ID_col), mol_ID, mol_rows(1, frame_col)];
        end
    end
    
    %convert to seconds
    arrival_mat(:,4) = arrival_mat(:,3) ./ app.movie_data.params.frame_rate;
    
    %plot the histogram
    h = histogram(app.UIAxes_compiled_events, arrival_mat(:,4), 'BinWidth', app.Binwidtharrivaltime.Value);
    h.FaceColor = 'black';
    h.EdgeColor = 'white';
    h.LineWidth = 2;
    xlabel(app.UIAxes_compiled_events, "Arrival time (s)"); ylabel(app.UIAxes_compiled_events, "Number of molecules");
    title(app.UIAxes_compiled_events, "Arrival times of molecules");
    box(app.UIAxes_compiled_events, 'on');
    app.UIAxes_compiled_events.YLim = [0 ceil(max(h.Values) * 1.05)];
    app.UIAxes_compiled_events.XLim = [0 max(h.BinEdges) + app.Binwidtharrivaltime.Value/5];    %add 1/5th of a bin to make plot more visible
end







