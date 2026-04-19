function [] = engineerFeatures(app)
%Perform feature engineering, 22/05/2024.
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
%This function enables generalisation of feature engineering to all input
%pipelines, and provides user control over the generation of engineered
%features. This function replaces the hardcoded feature engineering LoColi
%data that was previously part of the function prepData().
%
%Note that currently all features are computed without user control over
%This will be modified in a future update to enable user selection of
%engineered features, which will depend dynamically upon primary input
%features available in the input data.
%
%Note that the main data struct passed to this function contains a tracks
%substruct which always contains the columns ['x (px)', 'y (px)', 'Frame',
%'MolID'], followed by an optional block of primary features which are
%extracted from the localisation data (in the case of LoColi), or obtained
%from additional columns in the input tracking data (in the case of other
%pipelines).
%
%For performance, this code was previously executed in a single loop, with
%all changes being performed on a cell-by-cell basis. However as selective
%feature engineering was introduced, the individual functions were
%modularised into individual functions for clarity, robustness, and to
%avoid complex conditional statements.
%
%Many of the local functions that perform operations on a track-by-track
%basis uses a variable called new_col which is formed by multiple
%concatenation operations of individual tracks. This is an obvious place
%where pre-allocation and use of a running index could improve performance
%if needed.
%
%Future refactoring: the local functions for local and pairs of windows,
%could be condensed into two functions which call smaller functions only to
%perform the calculations on the local windowed data. This refactoring
%offers no performance improvement, but would significantly condense this
%.m file.
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
%engineerCellCoords()
%engineerShiftedStepSizes()
%computeLocMemDists()
%computeLocPoleDists()
%computeStepAngles()
%compileMSDMatrixFast()
%computeStepAngles()
%computeStepAnglesRelToCell()
%findColumnIdx()
%engineerTimeFromTrackStart()           - local to this .m file
%engineerPosInNm()                      - local to this .m file
%engineerTimeStep()                     - local to this .m file
%engineerExperimentTime()               - local to this .m file
%engineerTimeFromReferencePoints()      - local to this .m file
%engineerStepSize()                     - local to this .m file
%engineerShiftedStepSizes()             - local to this .m file
%engineerLocalStepSizeKurtosis()        - local to this .m file
%engineerLocalKurtosis()                - local to this .m file
%engineerDistanceFromTrackStart()       - local to this .m file
%engineerCumulativeDistanceTravelled()  - local to this .m file
%engineerRelativeStepAngle()            - local to this .m file
%engineerStepAngleAsymmetry()           - local to this .m file
%engineerStepAngleRelImage()            - local to this .m file
%engineerStepAngleRelCell()             - local to this .m file
%engineerSpotSize()                     - local to this .m file
%engineerSpotArea()                     - local to this .m file
%engineerLocalEfficiency()              - local to this .m file
%engineerLocalStraightness()            - local to this .m file
%engineerLocalFractalDimension()        - local to this .m file
%engineerLocalTrappedness()             - local to this .m file
%engineerLocalDStar()                   - local to this .m file
%engineerRollingDStarDelta()            - local to this .m file
%engineerLocalAnomalousExponent()       - local to this .m file
%engineerRollingMeanStepSizeDelta()     - local to this .m file
%engineerRollingStdDevStepSizeDelta()   - local to this .m file
%engineerRollingStdDevPosnDelta()       - local to this .m file
%engineerRollingDispersionChange()      - local to this .m file
%engineerRollingCentroidDisplacement()  - local to this .m file
%engineerSmoothedStepSize()             - local to this .m file
%engineerFramesFromEnds()               - local to this .m file
    
    
    %==========================================
    %User selects from feature engineering menu
    %==========================================
    popup = FeatureEngineeringMenu(app);
    uiwait(popup.FeatureEngineeringMenuUIFigure);
    
    %==================================================================
    %Front-load decision making to start of feature engineering process
    %==================================================================
    %if user has requested any rolling delta features, then prompt them for a rolling window size for this
    strings_to_check = {'Local change in diffusion coefficient',...
                        'Local change in mean step size',...
                        'Local change in standard deviation of step sizes',...
                        'Local change in standard deviation of positions',...
                        'Local change in dispersion of positions',...
                        'Local displacement in centroid of localisations'};
    if any(ismember(strings_to_check, app.movie_data.state.selected_features))
        popup = SlidingPairWindowSizePopUp(app);
        uiwait(popup.SlidingPairWindowSizeFigure);
    end
    
    %get from user a local window size if required
    %(note that smoothed step size is not included here as it requires a separate input for smoothing method, and so has its own app)
    strings_to_check = {'Local anomalous diffusion exponent',...
                        'Local step angle asymmetry', ...
                        'Local diffusion coefficient', ...
                        'Local efficiency', ...
                        'Local straightness', ...
                        'Local kurtosis', ...
                        'Local step size kurtosis', ...
                        'Local fractal dimension', ...
                        'Local velocity autocorrelation function', ...
                        'Local maximal excursion', ...
                        'Local trappedness'};
    if any(ismember(strings_to_check, app.movie_data.state.selected_features))
        popup = LocalWindowSizePopUp(app);
        uiwait(popup.LocalWindowSizeFigure);
    end
    
    %get from user input parameters for smoothed step size
    strings_to_check = {'Smoothed step size'};
    if any(ismember(strings_to_check, app.movie_data.state.selected_features))
        popup = SetWindowSizeStepSmoothingPopUp(app);
        uiwait(popup.StepSizeSmoothingUIFigure);
    end
    
    %get from user reference point(s) if requested
    strings_to_check = {'Set experiment reference timepoints'};
    if any(ismember(strings_to_check, app.movie_data.state.selected_features))
        popup = ReferencePointPopUp(app);
        uiwait(popup.ExperimentalReferenceTimePointsUIFigure);
    end
    
    %get from user time shifts if requested
    strings_to_check = {'Time shifted step sizes'};
    if any(ismember(strings_to_check, app.movie_data.state.selected_features))
        popup = TemporalContextPopUp(app);
        uiwait(popup.TemporallyShiftofStepSizeUIFigure);
    end
    
    %get from user time shifts if requested
    strings_to_check = {'Local trappedness'};
    if any(ismember(strings_to_check, app.movie_data.state.selected_features))
        popup = TrappedConstantsPopUp(app);
        uiwait(popup.TrappedUIFigure);
    end
    
    %clear any lingering pop-ups - I've not explicitly cleared this between calls to successive popups because there are no listener objects, and there is no intention to add any
    if exist("popup", "var")
        clear popup;
    end
    
    %==============
    %Set up waitbar
    %==============
    curr_feature    = 1;    %keeps track of current feature being engineered to inform waitbar
    N_features      = numel(app.movie_data.state.selected_features) + 3;    %3 obligatory features to engineer; update as required when adding more
    h_progress      = waitbar(0,'Preparing....', 'Name', 'Engineering features');
    
    %====================================================
    %Sort tracks data prior to feature engineering by
    %track ID with chronological frames within each track
    %====================================================
    col_frame   = findColumnIdx(app.movie_data.params.column_titles.tracks, "Frame");
    col_mol_ID  = findColumnIdx(app.movie_data.params.column_titles.tracks, "MolID");
    
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
            app.movie_data.cellROI_data(ii).tracks = sortrows(app.movie_data.cellROI_data(ii).tracks, [col_mol_ID col_frame]);
        end
    end
    
    %==============================
    %Obligatory engineered features
    %==============================
    %compute the time from start of track for all tracked localisations
    set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Time from track start"));
    waitbar(0, h_progress, 'Computing times from track start');
    engineerTimeFromTrackStart(app, h_progress);
    curr_feature = curr_feature + 1;
    
    %compute cell coordinates for all tracked localisations in dataset
    set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Cell coordinates"));
    waitbar(0, h_progress, 'Computing cell coordinates');
    engineerCellCoords(app, h_progress);
    curr_feature = curr_feature + 1;
    
    %convert localisation data to nm
    set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Coordinates in nanometers"));
    waitbar(0, h_progress, 'Converting to nanometers');
    engineerPosInNm(app, h_progress);
    curr_feature = curr_feature + 1;
    
    %============================
    %Optional engineered features
    %============================
    %compute step sizes between localisations in all tracks
    if ismember('Step size', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Step size"));
        waitbar(0, h_progress, 'Computing step sizes');
        engineerStepSize(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute the time steps between localisations in all tracks
    if ismember('Time step from previous localisation', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Time step"));
        waitbar(0, h_progress, 'Computing time steps');
        engineerTimeStep(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute smoothed step sizes
    if ismember('Smoothed step size', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Smoothed step size"));
        waitbar(0, h_progress, 'Smoothing step sizes');
        engineerSmoothedStepSize(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute time from start of experiment
    if ismember('Time since start of experiment', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Global experiment time"));
        waitbar(0, h_progress, 'Computing experiment times');
        engineerExperimentTime(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute time from all reference points
    if ismember('Set experiment reference timepoints', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Reference time point(s)"));
        waitbar(0, h_progress, 'Computing reference timepoints');
        engineerTimeFromReferencePoints(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute distance of current point from start of track
    if ismember('Current distance from start of track', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Distance from track start"));
        waitbar(0, h_progress, 'Computing distances');
        engineerDistanceFromTrackStart(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute cumulative distance travelled since start of track
    if ismember('Cumulative distance travelled', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Cumulative distance travelled"));
        waitbar(0, h_progress, 'Computing cumulative distances');
        engineerCumulativeDistanceTravelled(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute all shifted step sizes requested by user
    if ismember('Time shifted step sizes', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Time-shifted step size"));
        waitbar(0, h_progress, 'Computing time shifted step sizes');
        engineerShiftedStepSizes(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute distance-to-membrane for every tracked localisation in dataset
    if ismember('Distance to cell membrane', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Distance to cell membrane"));
        waitbar(0, h_progress, 'Computing membrane distances');
        computeLocMemDists(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute distance-to-pole for every tracked localisation in dataset
    if ismember('Distance to nearest cell pole', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Distance to cell pole"));
        waitbar(0, h_progress, 'Computing pole distances');
        computeLocPoleDists(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute spot size
    if ismember('Spot size', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Spot size"));
        waitbar(0, h_progress, 'Computing spot sizes');
        engineerSpotSize(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute spot area
    if ismember('Spot area', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Spot area"));
        waitbar(0, h_progress, 'Computing spot areas');
        engineerSpotArea(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute step angle relative to previous step for all steps in dataset
    if ismember('Step angle relative to previous step', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Step angle"));
        waitbar(0, h_progress, 'Computing step angles');
        engineerRelativeStepAngle(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute local step angle asymmetry
    if ismember('Local step angle asymmetry', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local step angle asymmetry"));
        waitbar(0, h_progress, 'Computing local step angle asymmetry');
        engineerStepAngleAsymmetry(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute step angle relative to image for all steps in dataset
    if ismember('Step angle relative to field of view', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Step angle (image axis)"));
        waitbar(0, h_progress, 'Computing step angles relative to image');
        engineerStepAngleRelImage(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute step angle relative to cell major axis for all steps in dataset
    if ismember('Step angle relative to cell major axis', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Step angle (cell axis)"));
        waitbar(0, h_progress, 'Computing step angles');
        engineerStepAngleRelCell(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute the local diffusion coefficient around every tracked localisation
    if ismember('Local diffusion coefficient', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local diffusion coefficient"));
        waitbar(0, h_progress, 'Computing diffusion coefficients');
        engineerLocalDStar(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute rolling window delta for local D*
    if ismember('Local change in diffusion coefficient', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Delta diffusion coefficient"));
        waitbar(0, h_progress, 'Computing delta diffusion coefficients');
        engineerRollingDStarDelta(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute local trappedness
    if ismember('Local trappedness', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local trappedness"));
        waitbar(0, h_progress, 'Computing local trappedness');
        engineerLocalTrappedness(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute local anomalous diffusion exponent
    if ismember('Local anomalous diffusion exponent', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local diffusion exponent"));
        waitbar(0, h_progress, 'Computing local diffusion exponents');
        engineerLocalAnomalousExponent(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute local efficiency
    if ismember('Local efficiency', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local efficiency"));
        waitbar(0, h_progress, 'Computing local efficiencies');
        engineerLocalEfficiency(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute local straightness
    if ismember('Local straightness', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local straightness"));
        waitbar(0, h_progress, 'Computing local straightnesses');
        engineerLocalStraightness(app, h_progress)
        curr_feature = curr_feature + 1;
    end
    
    %compute local kurtosis
    if ismember('Local kurtosis', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local kurtosis"));
        waitbar(0, h_progress, 'Computing local kurtosis');
        engineerLocalKurtosis(app, h_progress)
        curr_feature = curr_feature + 1;
    end
    
    %compute local step size kurtosis
    if ismember('Local step size kurtosis', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local step size kurtosis"));
        waitbar(0, h_progress, 'Computing local step size kurtosis');
        engineerLocalStepSizeKurtosis(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute local fractal dimension
    if ismember('Local fractal dimension', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local fractal dimension"));
        waitbar(0, h_progress, 'Computing local fractal dimension');
        engineerLocalFractalDimension(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute local maximal excursion
    if ismember('Local maximal excursion', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local maximal excursion"));
        waitbar(0, h_progress, 'Computing local maximal excursion');
        engineerLocalMaximalExcursion(app, h_progress)
        curr_feature = curr_feature + 1;
    end
    
    %compute local VACF
    if ismember('Local velocity autocorrelation function', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Local VACF"));
        waitbar(0, h_progress, 'Computing local velocity autocorrelation function');
        engineerLocalVACF(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute rolling window delta for mean step size
    if ismember('Local change in mean step size', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Delta mean step size"));
        waitbar(0, h_progress, 'Computing delta mean step sizes');
        engineerRollingMeanStepSizeDelta(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute rolling window delta for standard deviation of step size
    if ismember('Local change in standard deviation of step sizes', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Delta stdev step size"));
        waitbar(0, h_progress, 'Computing delta standard deviations');
        engineerRollingStdDevStepSizeDelta(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute rolling window delta for standard deviation of position
    if ismember('Local change in standard deviation of positions', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Delta stdev of position"));
        waitbar(0, h_progress, 'Computing standard deviations of positions');
        engineerRollingStdDevPosnDelta(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute rolling window of change in dispersion
    if ismember('Local change in dispersion of positions', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Change in dispersion"));
        waitbar(0, h_progress, 'Computing changes in dispersion');
        engineerRollingDispersionChange(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute rolling window of displacement between position centroids
    if ismember('Local displacement in centroid of localisations', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Centroid displacement"));
        waitbar(0, h_progress, 'Computing centroid displacements');
        engineerRollingCentroidDisplacement(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %compute track end proximity
    if ismember('Proximity to ends of track', app.movie_data.state.selected_features)
        set(h_progress, 'Name', char("Feature " + num2str(curr_feature) + "/" + num2str(N_features) + ": Track ends proximity"));
        waitbar(0, h_progress, 'Computing proximity to track ends');
        engineerFramesFromEnds(app, h_progress);
        curr_feature = curr_feature + 1;
    end
    
    %append any arbitrary features requested by user
    selected_arbitrary = intersect(app.movie_data.state.selected_features, app.movie_data.params.arbitrary_features, 'stable')';
    if ~isempty(selected_arbitrary)
        set(h_progress, 'Name', char("Feature(s) " + num2str(curr_feature) + "-" + num2str(curr_feature + numel(selected_arbitrary) - 1) + "/" + num2str(N_features) + ": Arbitrary features"));
        waitbar(0, h_progress, 'Appending remaining arbitrary features');
    else
        set(h_progress, 'Name', char("Clean-up of unused arbitrary features"));
        waitbar(0, h_progress, 'Eliminating unused data, please wait....');
    end
    engineerArbitraryFeatures(app, selected_arbitrary); %run regardless of whether there are any any requested arb features, as func performs clean-up of unused features
    
    %================================================================
    %Re-sort all tracks data by frame number (for frames containing
    %multiple locs, rows are ordered by ascending by track_ID number)
    %================================================================
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        if ~isempty(app.movie_data.cellROI_data(ii).tracks)
            app.movie_data.cellROI_data(ii).tracks = sortrows(app.movie_data.cellROI_data(ii).tracks, [col_frame col_mol_ID]);
        end
    end
    
    close(h_progress);
    
    %============
    %Class labels
    %============
    %set class labels for all mols to -1 (could have been done outside of this list)
    for ii = 1:size(app.movie_data.cellROI_data, 1)
        app.movie_data.cellROI_data(ii).tracks = cat(2, app.movie_data.cellROI_data(ii).tracks, (-1).*ones(size(app.movie_data.cellROI_data(ii).tracks, 1), 1));
    end
    
    %concatenate the class label
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'class label'];
end


function [] = engineerPosInNm(app, h_progress)
%Feature engineering for conversion of position units to nm for all tracked
%localisations in dataset, 24/05/2024.
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
%This code was moved from engineerFeatures() to modularise the code.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Converting data for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %compute x and y in nm
            new_cols = app.movie_data.cellROI_data(ii).tracks(:,1:2) .* px_scale;
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_cols];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, {'x (nm)', 'y (nm)'}];
end


function [] = engineerStepSize(app, h_progress)
%Feature engineering for step size from the previous localisation in a
%track, 24/05/2024.
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing step sizes for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute time steps
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                
                %compute distances between consecutive points
                curr_steps = [0; sqrt(sum(diff(curr_track(:, 1:2)).^2, 2)) .* px_scale];
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = [new_col; curr_steps];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
       
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step size (nm)'];
end


function [] = engineerTimeStep(app, h_progress)
%Feature engineering for the time step from the previous localisation in a
%track, 24/05/2024.
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing time steps for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute time steps
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_time_steps = [0; diff(curr_track(:, 3)) ./ app.movie_data.params.frame_rate];
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = cat(1, new_col, curr_time_steps);
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Time step interval from previous step (s)'];
end


function [] = engineerExperimentTime(app, h_progress)
%Feature engineering for the time elapsed from start of experiment,
%30/05/2024.
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
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing experiment time for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %compute times and append to tracks matrix
            new_col = app.movie_data.cellROI_data(ii).tracks(:, 3) ./ app.movie_data.params.frame_rate;
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Experiment time (s)'];
end


function [] = engineerTimeFromTrackStart(app, h_progress)
%Feature engineering for the time elapsed from start of track, 30/05/2024.
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    frame_rate  = app.movie_data.params.frame_rate;
    col_frame   = findColumnIdx(app.movie_data.params.column_titles.tracks, "Frame");
    col_mol_ID  = findColumnIdx(app.movie_data.params.column_titles.tracks, "MolID");
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing track times for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %ensure the filtered track IDs are in ascending order
            filtered_ids = sort(app.movie_data.cellROI_data(ii).filtered_track_IDs(:,1));
            
            %loop over all filtered molecules in the current cell
            for jj = 1:numel(filtered_ids)
                %get the current track and compute the time from start
                curr_track      = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:, col_mol_ID) == filtered_ids(jj), :);
                curr_intervals  = (curr_track(:, col_frame) - curr_track(1, col_frame)) ./ frame_rate;
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = cat(1, new_col, curr_intervals);
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Time from start of track (s)'];
end


function [] = engineerTimeFromReferencePoints(app, h_progress)
%Feature engineering for the time elapsed from reference point(s) provided
%by user, 29/05/2024.
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
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if isfield(app.movie_data.params, 't_ref_points') && iscell(app.movie_data.params.t_ref_points)
        t_ref_points = app.movie_data.params.t_ref_points;
    else
        app.textout.Value = "Feature engineering for reference time points skipped";
        return;
    end
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    frame_rate = app.movie_data.params.frame_rate;
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing reference time(s) for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            curr_tracks = app.movie_data.cellROI_data(ii).tracks;
            
            %pre-allocate
            curr_ref_times = zeros(size(curr_tracks, 1), size(t_ref_points, 1));
            
            %get delay from each custom reference point, and concatenate columns with existing tracks matrix
            for kk = 1:size(t_ref_points, 1)
                curr_ref_times(:,kk) = (curr_tracks(:, 3) ./ frame_rate) - t_ref_points{kk, 1};
            end
            
            %append new data
            app.movie_data.cellROI_data(ii).tracks = [curr_tracks, curr_ref_times];
        end
    end
    
    %write the new column titles
    title_t_ref_points = cellfun(@(x) ['Time from ' x ' (s)'], t_ref_points(:, 2), 'UniformOutput', false);
    app.movie_data.params.column_titles.tracks  = [app.movie_data.params.column_titles.tracks, title_t_ref_points'];
end


function [] = engineerDistanceFromTrackStart(app, h_progress)
%Feature engineering for the distance of position from start of track,
%30/05/2024.
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
%This feature is particularly powerful for scenarios involving fluorogenic
%probes which encode the start of a process. For example in experiments
%involving smFISH the start of each track encodes the point at which a
%transcript is produced, and all downstream processes of motion from this
%initial target follows a pattern that is to be investigated. The allows
%for detailed analysis for insight into motion following the triggering
%event. Another example may be fluorogenic probes that bind in the
%periplasm following cytoplasmic-periplasmic transport. It could
%also be used to study the stability of binding partners.
%
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing distances for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track and compute the time from start
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_dists = sqrt(sum((curr_track(:, 1:2) - curr_track(1, 1:2)).^2, 2)) .* px_scale;
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = cat(1, new_col, curr_dists);
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Current distance from start of track (nm)'];
end


function [] = engineerCumulativeDistanceTravelled(app, h_progress)
%Feature engineering for the cumulative distance travelled from start of
%track, 30/05/2024.
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
%Keeps track of how far the particle has moved since it first appeared.
%This is particularly useful for fluorogenic probes, for example studying
%the degradation rate of transcripts imaged with smFISH.
%
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing cumulative distances for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track and compute all distances between consecutive points
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_steps = [0; sqrt(sum(diff(curr_track(:, 1:2)).^2, 2)) .* px_scale];
                
                %compute the cumulative sum for each step in track, and concatenate this for the current molecule into the new column
                new_col = cat(1, new_col, cumsum(curr_steps));
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Cumulative distance travelled from start of track (nm)'];
end


function [] = engineerRelativeStepAngle(app, h_progress)
%Feature engineering for step angles relative to previous step, 24/05/2024.
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeStepAngles()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing step angles for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute step angles
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_angles = rad2deg(computeStepAngles(curr_track(:,1:2)));
                curr_angles = abs(curr_angles(:, 2));    %only want the magnitude of the step angle - direction is irrelevant
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = [new_col; curr_angles];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step angle relative to previous step (degrees, absolute)'];
end


function [] = engineerStepAngleRelImage(app, h_progress)
%Feature engineering for step angles relative to the image axis,
%24/05/2024.
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeStepAngles()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing step angles for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                %get the current track, and compute step angles
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_angles = rad2deg(computeStepAngles(curr_track(:,1:2)));
                curr_angles = abs(curr_angles(:, 1));    %only want the magnitude of the step angle - direction is irrelevant
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = [new_col; curr_angles];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step angle relative to image (degrees)'];
end


function [] = engineerStepAngleRelCell(app, h_progress)
%Feature engineering for step angles relative to the cell major axis,
%24/05/2024.
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
%Slight performance overhead noted in handling 'new_col'; pre-allocation
%could improve efficiency. Currently, this is not a bottleneck.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeStepAnglesRelToCell()
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing step angles for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %store the data to be concatenated with the current tracks matrix - could pre-allocate this, and keep a track of current index for improved performance
            new_col = [];
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                curr_mesh = app.movie_data.cellROI_data(ii).mesh;
                %get the current track, and compute step angles relative to cell major axis
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                curr_angles = computeStepAnglesRelToCell(curr_track(:,1:2), [curr_mesh(1,1:2); curr_mesh(end,1:2)]);
                
                %add the new data to be concatenated to the current cell's tracks data
                new_col = [new_col; curr_angles];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
        
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step angle relative to cell axis (degrees)'];
end


function [] = engineerSpotSize(app, h_progress)
%Feature engineering for spot size of all tracked localisations,
%31/05/2024.
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
%Computes double the square root of the sum of the squares of the standard
%deviation in the major an minor axes of the Gaussian fitting process
%during localisation. If Picasso is used, this falls back to using the PSF
%widths in the x and y image axes in the place of the fit to the major and
%minor axes.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findColumnIdx()
    
    %find the required columns
    col_sigma_1 = findColumnIdx(app.movie_data.params.column_titles.tracks, "Standard deviation major axis");
    col_sigma_2 = findColumnIdx(app.movie_data.params.column_titles.tracks, "Standard deviation minor axis");
    
    %if Picasso was used as localiser use PSF widths in x and y axes as approximation
    if col_sigma_1 == 0 || col_sigma_2 == 0
        col_sigma_1 = findColumnIdx(app.movie_data.params.column_titles.tracks, "PSF width x axis (px)");
        col_sigma_2 = findColumnIdx(app.movie_data.params.column_titles.tracks, "PSF width y axis (px)");
    end
    
    %fallback in case no feature present (e.g. TrackMate, non-Gaussian)
    if col_sigma_1 == 0 || col_sigma_2 == 0
        warndlg("Warning: Unable to find suitable columns in tracks file for standard deviation of localisations. Feature engineering for spot size has been skipped.", 'Warning: unable to engineer feature', 'modal');
        return;
    end
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing spot sizes for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %compute spot sizes and append to tracks matrix
            new_col = 2 .* (sqrt((app.movie_data.cellROI_data(ii).tracks(:, col_sigma_1) .* px_scale).^2 + (app.movie_data.cellROI_data(ii).tracks(:, col_sigma_2) .* px_scale).^2));
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Spot size (nm)'];
end


function [] = engineerSpotArea(app, h_progress)
%Feature engineering for spot area of all tracked localisations,
%31/05/2024.
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
%Computes the spot area using the formula A = pi * a * b, where a and b
%are the standard deviation in the major an minor axes of the Gaussian
%fitting process during localisation. If Picasso is used, this falls back
%to using the PSF widths in the x and y image axes in the place of the fit
%to the major and minor axes.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findColumnIdx()
    
    %find the required columns
    col_sigma_1 = findColumnIdx(app.movie_data.params.column_titles.tracks, "Standard deviation major axis");
    col_sigma_2 = findColumnIdx(app.movie_data.params.column_titles.tracks, "Standard deviation minor axis");
    
    %if Picasso was used as localiser use PSF widths in x and y axes as approximation
    if col_sigma_1 == 0 || col_sigma_2 == 0
        col_sigma_1 = findColumnIdx(app.movie_data.params.column_titles.tracks, "PSF width x axis (px)");
        col_sigma_2 = findColumnIdx(app.movie_data.params.column_titles.tracks, "PSF width y axis (px)");
    end
    
    %fallback in case no feature present (e.g. TrackMate, non-Gaussian)
    if col_sigma_1 == 0 || col_sigma_2 == 0
        warndlg("Warning: Unable to find suitable columns in tracks file for standard deviation of localisations. Feature engineering for spot area has been skipped.", 'Warning: unable to engineer feature', 'modal');
        return;
    end
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing spot areas for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %compute spot areas, and append to tracks matrix
            new_col = pi .* (app.movie_data.cellROI_data(ii).tracks(:, col_sigma_1) .* px_scale) .* (app.movie_data.cellROI_data(ii).tracks(:, col_sigma_2) .* px_scale);
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Spot area (nm^2)'];
end


function [] = engineerLocalDStar(app, h_progress)
%Feature engineering for local apparent diffusion coefficient for all
%tracked localisations, 17/06/2024.
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
%This algorithm computes D* from an MSD using all available points within
%the a user-defined range of frames either side of the reference point.
%
%In not requiring a full set of points in the MSD curve, this approach
%enables the system to trade accuracy at the start and end points of the
%track in order to obtain values even towards the ends of the track.
%
%The feature name in column titles has intentionally not included the
%window size enabling the user to choose the region over which the MSD is
%computed independently between different experiments; combining the
%results.
%
%A future version of this code may introduce weighting of the fitting
%process to increase the relative impact of smaller time shifts, as the
%goal here is changepoint detection/segmentation. Another future change may
%be to introduce imputation of NaN values, which would be replaced by the
%next nearest known value, or an average of the nearest known value before
%and after.
%
%Note that this replaces an earlier prototype version which obtained local
%diffusion coefficient using only step sizes between the reference point
%and all available other points in the frame window, but not allowing the
%pairwise contributions from non-reference points. The initial idea was to
%consider only the distance of the reference point to all other points in
%the small window. However this new version considers temporally-proximal
%pairwise steps to contain more useful information, particularly when exact
%changepoint detection is not the main goal, as is the case for separating
%bound particles from very slowly moving but mobile whose step sizes are
%smaller than the localisation precision. I may later re-introduce my
%earlier, deprecated code as an option here.
%
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%compileMSDMatrixFast()
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local D* for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                curr_Dstar  = zeros(size(curr_track, 1), 1);
                
                for kk = 1:size(curr_track, 1)
                    %obtain local window of track
                    lim_lo = curr_track(kk, 3) - window_size;
                    lim_hi = curr_track(kk, 3) + window_size;
                    
                    curr_window         = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    curr_window(:, 1:2) = curr_window(:, 1:2) .* (px_scale / 1000);
                    
                    %compute the MSD matrix
                    msd_result = compileMSDMatrixFast(curr_window, 1/app.movie_data.params.frame_rate, window_size);
                    
                    %calculate D* = MSD / 4t (without forcing through origin)
                    p = polyfit(msd_result(:, 3), msd_result(:, 4), 1); %use p = polyfit([0; msd_result(:, 3)], [0; msd_result(:, 4)], 1); to fit through origin
                    curr_Dstar(kk, 1) = p(1) / 4;
                end
                new_col = [new_col; curr_Dstar];
            end
            
            %a future version may impute NaNs here by taking the mean of nearest known values
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Local D* (um^2/s)'];
end


function [] = engineerRollingDStarDelta(app, h_progress)
%Feature engineering for the rolling difference of window pairs of local
%D* values, 19/06/2024.
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
%This function computes the difference between D* from MSDs in two small
%adjacent windows around each localisation in all tracks of the dataset.
%The D* value is D* = MSD/4t, with no correction applied for localisation
%error. Note that the fit is performed by a linear fit to the MSD-lag time
%data including and additonal point at the origin, (t, MSD) = (0, 0).
%
%In cases where there is insufficient data due to the at least one window
%not having enough points to form an MSD-lag time plot, the corresponding
%entry in the outputs, Dstar_ratio, and Dstar_delta, are set to zero.
%If there is a scenario in which one window contains only a single lag
%time, such as at the start or end of a track, then the D* value is
%calculated as described above, but using trigonometry as this produces the
%same output with higher performance than a call to polyfit.
%
%Note that the overall design of this function is not optimal; it would
%have been better to have processed the left and right windows separately,
%both within a conditional statement for a minimum window size. This would
%produce the same funcitonal output, but with higher performance. This
%implementation would however require careful thought of how all possible
%combinations of missing values from the memory parameter might affect the
%available lag times.
%
%Missing values are set as zero; in a future version I may update this to
%impute sensible values from neibouring data.
%
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%compileMSDMatrixFast()
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.rolling_delta_win_size;
    px_scale    = app.movie_data.params.px_scale;
    frame_rate  = app.movie_data.params.frame_rate;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing delta D* for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_Dstar_ratio = [];
            cell_Dstar_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                Dstar_ratio = zeros(size(curr_track, 1), 1);
                Dstar_delta = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first and last point
                for kk = 3:size(curr_track, 1) - 2
                    %obtain frame number limits for the window pair
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3) - 1];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size - 1];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %scale the position data to nm
                    win_left(:, 1:2)  = win_left(:, 1:2) .* (px_scale / 1000);
                    win_right(:, 1:2) = win_right(:, 1:2) .* (px_scale / 1000);
                    
                    %compute the MSD matrices
                    msd_left  = compileMSDMatrixFast(win_left, 1/frame_rate, window_size);
                    msd_right = compileMSDMatrixFast(win_right, 1/frame_rate, window_size);
                    
                    %remove empty MSD entries
                    msd_left  = msd_left(msd_left(:,1) ~= 0, :);
                    msd_right = msd_right(msd_right(:,1) ~= 0, :);
                    
                    if size(msd_left, 1) > 0 && size(msd_right, 1) > 0
                        %calculate for both windows D* = MSD / 4t; also adding a point at (0, 0)
                        if size(msd_left, 1) == 1
                            fit_left = [msd_left(1,4)/msd_left(1,3), 0];
                        elseif size(msd_left, 1) == 0
                            fit_left = [0, 0];
                        else
                            fit_left  = polyfit([0; msd_left(:, 3)], [0; msd_left(:, 4)], 1);
                        end
                        
                        if size(msd_right, 1) == 1
                            fit_right = [msd_right(1,4)/msd_right(1,3), 0];
                        elseif size(msd_right, 1) == 0
                            fit_right = [0, 0];
                        else
                            fit_right = polyfit([0; msd_right(:, 3)], [0; msd_right(:, 4)], 1);
                        end
                        
                        Dstar_left  = fit_left(1) / 4;
                        Dstar_right = fit_right(1) / 4;
                        
                        %compute ration and difference between windows
                        Dstar_ratio(kk) = Dstar_right / Dstar_left;
                        Dstar_delta(kk) = Dstar_right - Dstar_left;
                    else
                        %future interpolation/imputation to replace zeros when there is insufficient data
                   end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_Dstar_ratio = [cell_Dstar_ratio; Dstar_ratio];
                cell_Dstar_delta = [cell_Dstar_delta; Dstar_delta];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_Dstar_ratio, cell_Dstar_delta];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling D* ratio', 'Rolling D* delta (um^2/s)'];
end


function [] = engineerLocalAnomalousExponent(app, h_progress)
%Feature engineering for local anomalous diffusion exponent, 17/06/2024.
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
%Computes the anomalous exponent alpha by fitting the MSD over a specified
%window size around each point in the track. The window size is specified
%by the user, which determines the frame range used in the MSD computation.
%The maximum lag time used is half of the window size to ensure there is
%sufficient data to prevent statistical noise during the fitting process.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%compileMSDMatrixFast()
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing exponents for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:, 4) == track_ID, :);
                curr_alpha  = zeros(size(curr_track, 1), 1);
                
                for kk = 1:size(curr_track, 1)
                    %obtain local window of track
                    lim_lo = curr_track(kk, 3) - window_size;
                    lim_hi = curr_track(kk, 3) + window_size;
                    
                    curr_window         = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    curr_window(:, 1:2) = curr_window(:, 1:2) .* (px_scale / 1000);
                    
                    %compute the MSD matrix
                    msd_result = compileMSDMatrixFast(curr_window, 1/app.movie_data.params.frame_rate, window_size);
                    
                    %calculate alpha by fitting log-log MSD vs time; alpha is gradient
                    p = polyfit(log(msd_result(:, 3)), log(msd_result(:, 4)), 1);   %if the user has some future use for fitting through origin then replace with log([0; msd_result(:, 3)]) and log([0; msd_result(:, 4)])
                    curr_alpha(kk, 1)   = p(1);
                    
                    %==================================================
                    %testing: uncomment this statement block, and pause
                    %code at end to inspect fit used for alpha calc.
                    %==================================================
                    % %plot fit in log space for visual verification
                    % figure; loglog(msd_result(:, 3), msd_result(:, 4), 'o'); hold on; plot(msd_result(:, 3), exp(polyval(p, log(msd_result(:, 3)))), '-r'); title('Plot of fit in semi-log space'); hold off;
                    % 
                    % %plot fit in linear space for verification
                    % figure; hold on; title('Plot of fit in linear space');
                    % x_fit = linspace(min(msd_result(:, 3)), max(msd_result(:, 3)), 100);
                    % y_fit = exp(p(2)) * x_fit.^p(1);
                    % scatter(msd_result(:, 3), msd_result(:, 4));
                    % plot(x_fit, y_fit, '-r', 'LineWidth', 1.5);
                end
                new_col = [new_col; curr_alpha];
            end
            
            %append alpha values to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Local anomalous exponent'];
end


function [] = engineerRollingMeanStepSizeDelta(app, h_progress)
%Feature engineering for the rolling difference of window pairs of local
%mean step sizes, 19/06/2024.
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
%This function computes the difference between mean step sizes in two small
%adjacent windows around each localisation in all tracks of the dataset.
%The localisation itself is included in the second (right hand) window. The
%ratio and difference are calculated as right/left and right - left
%respectively.
%
%Note that the window ranges for data used to compute step sizes are one
%frame larger than those used to compute other parameters due to step size
%being a difference between frames rather than a static property.
%
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.rolling_delta_win_size;
    px_scale = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing mean step sizes for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_mean_ratio = [];
            cell_mean_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                mean_ratio = zeros(size(curr_track, 1), 1);
                mean_delta = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first and last point
                for kk = 2:size(curr_track, 1) -1
                    %obtain frame number limits for the window pair - see header notes
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3)];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %if enough points exist compute mean ratio and delta
                    if size(win_left, 1) > 1 && size(win_right, 1) > 1
                        %compute the mean 2D step sizes in units of nm
                        mean_left  = mean(sqrt(sum(diff(win_left(:, 1:2)).^2, 2)) .* px_scale);
                        mean_right = mean(sqrt(sum(diff(win_right(:, 1:2)).^2, 2)) .* px_scale);
                        
                        %compute the ratio and delta
                        mean_ratio(kk) = mean_right / mean_left;
                        mean_delta(kk) = mean_right - mean_left;
                    else
                        %future interpolation/imputation to replace zeros when there is insufficient data
                    end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_mean_ratio = [cell_mean_ratio; mean_ratio];
                cell_mean_delta = [cell_mean_delta; mean_delta];
            end
            
            %compute the absolute mean delta (inidicates singificance of changepoint)
            cell_mean_delta_abs = abs(cell_mean_delta);
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_mean_ratio, cell_mean_delta, cell_mean_delta_abs];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling mean step size ratio', 'Rolling mean step size delta (nm)', 'Rolling mean step size delta absolute'];
end


function [] = engineerRollingStdDevStepSizeDelta(app, h_progress)
%Feature engineering for the rolling difference of window pairs of local
%standard deviation in step sizes, 20/06/2024.
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
%This function computes the difference between mean step sizes in two small
%adjacent windows around each localisation in all tracks of the dataset.
%The reference localisation itself is used in both windows. The ratio and
%difference are calculated as right/left and right - left respectively.
%
%Note that the window ranges for data used to compute step sizes are one
%frame larger than those used to compute other parameters due to step size
%being a difference between frames rather than a static property.
%
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.rolling_delta_win_size;
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing stdev step size for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_std_ratio = [];
            cell_std_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                std_ratio = zeros(size(curr_track, 1), 1);
                std_delta = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first two and last two points
                for kk = 3:size(curr_track, 1) - 2
                    %obtain frame number limits for the window pair - see header notes
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3)];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %if enough points exist compute stdev ratio and delta
                    if size(win_left, 1) > 2 && size(win_right, 1) > 2
                        %scale the position data to nm
                        win_left(:, 1:2)  = win_left(:, 1:2) .* px_scale;
                        win_right(:, 1:2) = win_right(:, 1:2) .* px_scale;
                        
                        %compute the mean 2D step sizes
                        std_left  = std(sqrt(sum(diff(win_left(:, 1:2)).^2, 2)));
                        std_right = std(sqrt(sum(diff(win_right(:, 1:2)).^2, 2)));
                        
                        %compute the ratio and delta
                        std_ratio(kk) = std_right / std_left;
                        std_delta(kk) = std_right - std_left;
                    else
                        %future interpolation/imputation to replace zeros when there is insufficient data
                    end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_std_ratio = [cell_std_ratio; std_ratio];
                cell_std_delta = [cell_std_delta; std_delta];
            end
            
            %compute the absolute mean ratio (inidicates singificance of changepoint)
            cell_std_delta_abs = abs(cell_std_delta);
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_std_ratio, cell_std_delta, cell_std_delta_abs];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling stdev step size ratio', 'Rolling stdev step size delta (nm)', 'Rolling stdev step size delta absolute'];
end


function [] = engineerRollingStdDevPosnDelta(app, h_progress)
%Feature engineering for the rolling difference of window pairs of local
%standard deviation in coordinates, 20/06/2024.
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
%This function computes the difference between mean step sizes in two
%small adjacent windows around each localisation in all tracks of the
%dataset. The localisation itself is included in the second (right hand)
%window. The ratio and difference are calculated as right/left and
%right - left respectively.
%
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.rolling_delta_win_size;
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing stdev of positions for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_std_ratio = [];
            cell_std_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                std_ratio = zeros(size(curr_track, 1), 1);
                std_delta = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first and last two points
                for kk = 3:size(curr_track, 1) - 1
                    %obtain frame number limits for the window pair
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3) - 1];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size - 1];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %if enough points exist compute mean ratio and delta
                    if size(win_left, 1) > 1 && size(win_right, 1) > 1
                        %scale the position data to nm
                        win_left(:, 1:2)  = win_left(:, 1:2) .* px_scale;
                        win_right(:, 1:2) = win_right(:, 1:2) .* px_scale;
                        
                        %compute standard deviation in pos'n
                        std_left  = mean(std(win_left(:, 1:2)));
                        std_right = mean(std(win_right(:, 1:2)));
                        
                        %compute the ratio and delta
                        std_ratio(kk) = std_right / std_left;
                        std_delta(kk) = std_right - std_left;
                    else
                        %future interpolation/imputation to replace zeros when there is insufficient data
                    end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_std_ratio = [cell_std_ratio; std_ratio];
                cell_std_delta = [cell_std_delta; std_delta];
            end
            
            %compute the absolute mean ratio (inidicates singificance of changepoint)
            cell_std_delta_abs = abs(cell_std_delta);
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_std_ratio, cell_std_delta, cell_std_delta_abs];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling stdev position ratio', 'Rolling stdev position delta (nm)', 'Rolling stdev position delta absolute'];
end


function [] = engineerRollingDispersionChange(app, h_progress)
%Feature engineering for the rolling difference in spread of localisations
%between a pair of adjacent sliding windows, 03/07/2024.
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
%This function computes the difference between the dispersion of
%coordinates of two small adjacent windows around each localisation in
%all tracks of the dataset. The localisation itself is included in the
%second (right hand) window. The ratio and difference are calculated as
%right/left and right - left respectively.
%
%Note that calcaulations here are performed in nm rather than pixels to
%expand the capability of models trained on the delta feature to be
%applied to datasets recorded using other optical systems.
%
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.rolling_delta_win_size;
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing dipersion changes for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_disp_ratio = [];
            cell_disp_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                disp_ratio = zeros(size(curr_track, 1), 1);
                disp_delta = zeros(size(curr_track, 1), 1);
                
                for kk = 3:size(curr_track, 1) - 1
                    %define frame number limits for the window pair
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3) - 1];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size - 1];
                    
                    %construct window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %compute dispersion if enough points exist in both windows
                    if size(win_left, 1) > 1 && size(win_right, 1) > 1
                        %convert to nm (using a universal scale enables models to be trained with this feature on one system and applied to another)
                        win_left(:, 1:2)  = win_left(:, 1:2) .* px_scale;
                        win_right(:, 1:2) = win_right(:, 1:2) .* px_scale;
                        
                        %compute centroids of each window
                        centroid_left   = mean(win_left(:, 1:2));
                        centroid_right  = mean(win_right(:, 1:2));
                        
                        %compute mean distance from centroid to each point in windows (Centroid-Based Dispersion)
                        disp_left  = mean(sqrt(sum((win_left(:, 1:2) - centroid_left).^2, 2)));
                        disp_right = mean(sqrt(sum((win_right(:, 1:2) - centroid_right).^2, 2)));
                        
                        disp_ratio(kk) = disp_right / disp_left;
                        disp_delta(kk) = disp_right - disp_left;
                    else
                        %future interpolation/imputation to replace zeros when there is insufficient data
                    end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_disp_ratio = [cell_disp_ratio; disp_ratio];
                cell_disp_delta = [cell_disp_delta; disp_delta];
            end
            
            %compute the absolute mean ratio (inidicates singificance of changepoint)
            cell_disp_delta_abs = abs(cell_disp_delta);
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_disp_ratio, cell_disp_delta, cell_disp_delta_abs];
        end
    end
    
    %update col titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling dispersion ratio', 'Rolling dispersion delta', 'Rolling dispersion delta absolute'];
end


function [] = engineerRollingCentroidDisplacement(app, h_progress)
%Feature engineering for the distance between centroids of a collection of
%localisations in window pairs around the current point, 04/07/2024.
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
%This function computes the distance between centroids of points taken in
%two windows either side of the current frame in all tracks of the dataset.
%The reference localisation itself is used in the second (right hand)
%window only. The displacement is calculated as right - left.
%
%Note that calcaulations here are performed in nm rather than pixels to
%expand the capability of models trained on this feature to be applied to
%datasets recorded using other optical systems.
%
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.rolling_delta_win_size;
    px_scale    = app.movie_data.params.px_scale;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing centroid displacements for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            cell_displacement = [];
            cell_mean_delta = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                displacement = zeros(size(curr_track, 1), 1);
                
                %loop over track, omitting first and last point
                for kk = 3:size(curr_track, 1) - 1
                    %obtain frame number limits for the window pair - see header notes
                    lims_left  = [curr_track(kk, 3) - window_size, curr_track(kk, 3) - 1];
                    lims_right = [curr_track(kk, 3), curr_track(kk, 3) + window_size - 1];
                    
                    %construct the window pair
                    win_left  = curr_track(curr_track(:, 3) >= lims_left(1) & curr_track(:, 3) <= lims_left(2), 1:3);
                    win_right = curr_track(curr_track(:, 3) >= lims_right(1) & curr_track(:, 3) <= lims_right(2), 1:3);
                    
                    %if enough points exist compute mean ratio and delta
                    if size(win_left, 1) > 1 && size(win_right, 1) > 1
                        %convert to nm (using a universal scale enables models to be trained with this feature on one system and applied to another)
                        win_left(:, 1:2)  = win_left(:, 1:2) .* px_scale;
                        win_right(:, 1:2) = win_right(:, 1:2) .* px_scale;
                        
                        %compute centroids of each window
                        centroid_left   = mean(win_left(:, 1:2));
                        centroid_right  = mean(win_right(:, 1:2));
                        
                        displacement(kk) = sqrt((centroid_right(2) - centroid_left(2))^2 + (centroid_right(1) - centroid_left(1))^2);
                    else
                        %future interpolation/imputation to replace zeros when there is insufficient data
                    end
                end
                
                %append ratio and delta for current track to others in same cell
                cell_displacement = [cell_displacement; displacement];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, cell_displacement];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Rolling centroid displacement (nm)'];
end


function [] = engineerFramesFromEnds(app, h_progress)
%Feature engineering for the number of frames from start and end of the
%track, 09/07/2024.
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
%The features engineered here compute the number of frames from the current
%point to the start and end of the track. The goal here is to better learn
%the edge effects that occur when contextual information is limited at the
%track ends.
%
%This function produces four new features including both the raw number of
%captured localisations between each point and the start and end of the
%track, and the frame offset between the start and end of the track. The
%localisation offset is perhaps more useful here as the objective is to
%capture the amount of contextual information is available around each
%point, which is relatively independent of the memory parameter. However,
%missed frames may reduce the certainty with which each annotation can be
%assigned, and so both parameters for each end of the track are included.
%
%The new feature columns added are,
%   col1: Localisations from track start
%   col2: Localisations from track end
%   col3: Frames from track start
%   col4: Frames from track end
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Computing track end proximity for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %pre-allocate new cols
            new_cols    = zeros(size(app.movie_data.cellROI_data(ii).tracks, 1), 4);
            %keep track of where to insert new data into new_cols each time
            idx_start   = 1;
            
            %loop over all filtered molecules in cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                
                %calculate features
                rows_from_start = (0:size(curr_track, 1) - 1)';             %col1: rows from track start
                rows_from_end = flipud(rows_from_start);                    %col2: rows from track end
                frames_from_start = curr_track(:, 3) - curr_track(1, 3);    %col3: frames from track start
                frames_from_end = curr_track(end, 3) - curr_track(:, 3);    %col4: frames from track end
                
                %horizontally concat new cols
                idx_end = idx_start + size(curr_track, 1) - 1;
                new_cols(idx_start:idx_end, :) = [rows_from_start, rows_from_end, frames_from_start, frames_from_end];
                idx_start = idx_end + 1;
            end
            
            %append new data to current cell's tracks data
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_cols];
        end
    end
    
    %update column titles accordingly
    additional_titles = {'Localisations from track start', 'Localisations from track end', 'Frames from track start', 'Frames from track end'};
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, additional_titles];
end


function [] = engineerSmoothedStepSize(app, h_progress)
%Feature engineering for smoothed step sizes, 09/07/2024.
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
%This function generates smoothed step sizes using a moving average with a
%window size defined by the user.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if isfield(app.movie_data.state, 'step_smoothing_win_size') && app.movie_data.state.step_smoothing_win_size ~= 0
        window_size = app.movie_data.state.step_smoothing_win_size;
    else
        app.textout.Value = "User chose to cancel feature engineering for smoothed step sizes";
        return;
    end
    
    px_scale = app.movie_data.params.px_scale;
    
    %convert the smoothing method to MATLAB-compatible string option
    switch app.movie_data.state.smoothing_method
        case 'Moving mean'
            smooth_method = 'movmean';
            
        case 'Moving median'
            smooth_method = 'movmedian';
            
        case 'Gaussian kernel'
            smooth_method = 'gaussian';
            
        case 'Local linear regression (LOWESS)'
            smooth_method = 'lowess';
            
        case 'Local quadratic regression (LOESS)'
            smooth_method = 'loess';
            
        case 'Robust local linear regression (RLOWESS)'
            smooth_method = 'rlowess';
            
        case 'Robust local quadratic regression (RLOESS)'
            smooth_method = 'rloess';
            
        case 'Savitzky-Golay filter'
            smooth_method = 'sgolay';
            
        otherwise
            app.textout.Value = "Unknown smoothing method, skipping smoothing";
            return;
    end
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    
    for ii = 1:N_cells
        waitbar(ii/N_cells, h_progress, sprintf('Smoothing steps for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            %pre-allocate
            new_cols = zeros(size(app.movie_data.cellROI_data(ii).tracks, 1), 1);
            idx_start = 1;
            
            %loop over all filtered molecules in the current cell
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == app.movie_data.cellROI_data(ii).filtered_track_IDs(jj,1), :);
                
                %compute step sizes
                curr_steps = [0; sqrt(sum(diff(curr_track(:, 1:2)).^2, 2)) .* px_scale];
                
                %smooth step sizes using moving average
                smoothed_steps = [0; smoothdata(curr_steps(2:end, 1), smooth_method, window_size)];
                
                %insert smoothed steps into appropriate rows
                idx_end = idx_start + size(curr_track, 1) - 1;
                new_cols(idx_start:idx_end, 1) = smoothed_steps;
                idx_start = idx_end + 1;
            end
            
            %append new data to current cell's tracks data
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_cols];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Smoothed step size (nm)'];
end


function [] = engineerLocalEfficiency(app, h_progress)
%Feature engineering for local efficiency, 17/06/2024.
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
%Efficiency measures the directness of the particle's motion. For a series
%of N localisations, it is defined as the ratio of the squared total
%displacement (between start and end points) to the product of the number
%of steps and the sum of the squared step lengths.
%
%Efficiency is useful for identifying specific mobility states such as
%directed or constrained motion. E->1 indicates highly directed motion; and
%E->0 indicated extremely convoluted paths.
%
%There is an error checking step included to handle possible future edge
%cases from users using poorly-designed simulations in which there is zero
%step length change (ie. no movement to the data precision used). This is
%not the case for my own simulations, but prevents future abuse.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local efficiency for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                
                curr_efficiency  = zeros(size(curr_track, 1), 1);
                
                %loop over all steps in track
                for kk = 1:size(curr_track, 1)
                    %obtain local window
                    lim_lo      = curr_track(kk, 3) - window_size;
                    lim_hi      = curr_track(kk, 3) + window_size;
                    curr_window = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    
                    %compute efficiency
                    net_sq_displacement = sum((curr_window(end, 1:2) - curr_window(1, 1:2)).^2);
                    
                    sum_step_lengths_sq = sum(sum(diff(curr_window(:, 1:2)).^2, 2));
                    if sum_step_lengths_sq > 0
                        curr_efficiency(kk, 1) = net_sq_displacement / ((size(curr_window, 1) - 1) * sum_step_lengths_sq);
                    else
                        %handle rare edge cases in future poorly-designed simulations (see notes in header)
                        curr_efficiency(kk, 1) = 0;
                    end
                end
                new_col = [new_col; curr_efficiency];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Local Efficiency'];
end


function [] = engineerLocalStraightness(app, h_progress)
%Feature engineering for local straightness, 17/06/2024.
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
%Computation of straightness feature for local sliding windows. The feature
%describes the directness of a path, and is defined as the ratio of the
%distance between the start and end points of the path in the local window
%to the total length travelled over the local window.
%
%Note that as this feature is not normalised by number of points in the
%path, this would lead to an aritificial increase in the features value
%when there are fewer points towards the start and end of the path where
%the local window becomes compressed. To combat this the feature is set to
%zero (an infinitely convoluted path) in the end regions, and automatically masked out of the training data later. 
%Note that this can also be caused by the presence of photoblinking, but
%this is ignored as this can also be handled by training of this feature
%with the time from previous frame feature. While end regions can similarly
%be handled by training with the distance to track ends feature, the user
%is advised to instead use the path efficiency feature, as its
%normalisation allows more accurate representation in regions of compressed
%window size.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local straightness for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                
                curr_straight  = zeros(size(curr_track, 1), 1);
                
                %loop over every window in track, computing the feature for the current timepoint kk
                for kk = 1:size(curr_track, 1)
                    %ignore the starts and ends of each track where window contains too few points causing error in denominator
                    if kk <= window_size || kk > (size(curr_track, 1) - window_size)
                        curr_straight(kk, 1) = 0;
                        continue;
                    end
                    
                    %obtain local window
                    lim_lo      = curr_track(kk, 3) - window_size;
                    lim_hi      = curr_track(kk, 3) + window_size;
                    curr_window = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    
                    %calc for curr pos in window
                    net_displacement = sqrt(sum((curr_window(end, 1:2) - curr_window(1, 1:2)).^2));
                    sum_step_len            = sum(sqrt(sum(diff(curr_window(:, 1:2)).^2, 2)));
                    curr_straight(kk, 1)    = net_displacement ./ sum_step_len;
                end
                new_col = [new_col; curr_straight];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Local straightness'];
end


function [] = engineerLocalKurtosis(app, h_progress)
%Feature engineering for local kurtosis using the gyration tensor,
%17/06/2024.
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
%This feature is the local kurtosis obtained from projection of step sizes
%along the dominant eigenvector of the gyration tensor.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local kurtosis for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                
                %convert coordinates of curr track to nm
                curr_track(:, 1:2) = curr_track(:, 1:2) .* px_scale;
                
                %initialise values to write
                curr_kurtosis  = zeros(size(curr_track, 1), 1);
                
                %loop over every window in track, computing the feature for the current timepoint kk
                for kk = 1:size(curr_track, 1)
                    %obtain local window
                    lim_lo      = curr_track(kk, 3) - window_size;
                    lim_hi      = curr_track(kk, 3) + window_size;
                    curr_window = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    
                    %shift coordinates to relative to centre of mass, and compute gyration tensor
                    shifted_coords = curr_window(:, 1:2) - mean(curr_window(:, 1:2), 1);
                    gyration_tensor = (shifted_coords' * shifted_coords) / size(curr_window, 1);
                    
                    %find dominant eigenvector of the gyration tensor, and project points onto dominant eigenvector
                    [eigenvectors, ~]       = eig(gyration_tensor);
                    dominant_eigenvector    = eigenvectors(:, end); %last col is largest eigenvalue
                    proj_pos                = shifted_coords * dominant_eigenvector;
                    
                    %compute projected mean and std
                    mean_proj = mean(proj_pos);
                    std_proj  = std(proj_pos);
                    
                    %compute projected kurtosis
                    curr_kurtosis(kk, 1) = mean(((proj_pos - mean_proj) ./ std_proj).^4);   %could be simplified to (proj_pos ./ std_proj).^4 since mean_proj is always going to be approx. 0 after shifting coords to centre of mass
                end
                new_col = [new_col; curr_kurtosis];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Kurtosis'];
end


function [] = engineerLocalStepSizeKurtosis(app, h_progress)
%Feature engineering for local kurtosis for step sizes in each local
%window, 17/06/2024.
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
%This feature is the local kurtosis of unprojected step sizes within a
%local window.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local step size kurtosis for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                
                if isempty(curr_track)
                    continue;
                end
                
                %convert coordinates of curr track to nm
                curr_track(:, 1:2) = curr_track(:, 1:2) .* px_scale;
                
                %initialise values to write
                curr_kurtosis  = zeros(size(curr_track, 1), 1);
                
                %loop over every window in track, computing the feature for the current timepoint kk
                for kk = 1:size(curr_track, 1)
                    %obtain local window
                    lim_lo      = curr_track(kk, 3) - window_size;
                    lim_hi      = curr_track(kk, 3) + window_size;
                    curr_window = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    
                    %obtain step sizes
                    local_steps = sqrt(sum(diff(curr_window(:, 1:2)).^2, 2));
                    
                    %compute kurtosis of step sizes if enough steps are available, otherwise assign a value of zero
                    if numel(local_steps) >= 4
                        curr_kurtosis(kk, 1) = kurtosis(local_steps);
                    else
                        curr_kurtosis(kk, 1) = 0;
                    end
                end
                new_col = [new_col; curr_kurtosis];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step size kurtosis'];
end


function [] = engineerLocalFractalDimension(app, h_progress)
%Feature engineering for local fractal dimension, 17/06/2024.
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
%Feature engineering for fractal dimension as defined by Katz, M.J.,
%George, E.B. Fractals and the analysis of growth paths. Bltn Mathcal
%Biology 47, 273–286 (1985). https://doi.org/10.1007/BF02460036,
%specifically,
%Df = log(N)/(log(N) + log(d/L))
%   where N is the number of steps in a path
%         d is the maximum step size in the path
%         L is the total path length
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local fractal dimension for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                
                if isempty(curr_track)
                    continue;
                end
                
                %convert coordinates of curr track to nm
                curr_track(:, 1:2) = curr_track(:, 1:2) .* px_scale;
                
                %initialise values to write
                curr_Df  = zeros(size(curr_track, 1), 1);
                
                %loop over every window in track, computing the feature for the current timepoint kk
                for kk = 1:size(curr_track, 1)
                    %obtain local window
                    lim_lo      = curr_track(kk, 3) - window_size;
                    lim_hi      = curr_track(kk, 3) + window_size;
                    curr_window = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    
                    %calculate feature, or assign zero is window is too small
                    if size(curr_window, 1) < 2
                        curr_Df(kk, 1) = 0;
                    else
                        N_steps = size(curr_window, 1) - 1;
                        
                        %max pairwise distance between any two points
                        max_dist = max(pdist(curr_window(:, 1:2)));
                        
                        %total length of the path
                        L = sum(sqrt(sum(diff(curr_window(:, 1:2)).^2, 2)));
                        
                        %assign values
                        if L > 0 && max_dist > 0
                            curr_Df(kk, 1) = log(N_steps) / log(N_steps * max_dist / L);
                        else
                            curr_Df(kk, 1) = 0;
                        end
                    end
                    
                end
                new_col = [new_col; curr_Df];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Fractal dimension'];
end


function [] = engineerLocalTrappedness(app, h_progress)
%Feature engineering for local trappedness, 17/06/2024.
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
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%compileMSDMatrixFast()
    
    if isfield(app.movie_data.state, 'trapped_consts') && isvector(app.movie_data.state.trapped_consts)
        c1 = app.movie_data.state.trapped_consts(1);
        c2 = app.movie_data.state.trapped_consts(2);
    else
        warndlg("User did not provide constants for trappedness feature; skipping feature engineering for trappedness", "Missing inputs, skipping feature.");
        return;
    end
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    px_scale    = app.movie_data.params.px_scale;
    window_size = app.movie_data.state.local_win_size;
    lag_time    = 1 / app.movie_data.params.frame_rate;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local trappedness for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                
                if isempty(curr_track)
                    continue;
                end
                
                %convert coordinates of curr track to micrometers
                curr_track(:, 1:2) = curr_track(:, 1:2) .* (px_scale / 1000);
                
                %initialise values to write
                curr_trappedness  = zeros(size(curr_track, 1), 1);
                
                %loop over every window in track, computing the feature for the current timepoint kk
                for kk = 1:size(curr_track, 1)
                    %obtain local window
                    lim_lo      = curr_track(kk, 3) - window_size;
                    lim_hi      = curr_track(kk, 3) + window_size;
                    curr_window = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:3);
                    
                    %calculate feature, or assign zero if window too small
                    if size(curr_window, 1) < 3
                        curr_trappedness = 0;
                    else
                        %r_0 is half max pairwise dist
                        r_0 = max(pdist(curr_window(:, 1:2))) / 2;
                        
                        %compute MSD using a maximum lag of 2
                        t_interframe = 1 / app.movie_data.params.frame_rate;
                        msd_result = compileMSDMatrixFast(curr_window, t_interframe, 2);
                        
                        %compute diffusion coefficient, D, from first two time lags
                        if msd_result(1, 2) > 0 && msd_result(2, 2) > 0
                            D = (msd_result(2, 4) - msd_result(1, 4)) / (4 * msd_result(1, 3)); %MSD = 4Dt; D = MSD / 4t; note that (msd_result(2, 3) - msd_result(1, 3)) == msd_result(1, 3), this substitution improves computational efficiency
                        else
                            D = 0;
                        end
                        
                        %compute trappedness
                        if r_0 > 0 && D ~= 0
                            curr_trappedness(kk, 1) = 1 - exp(c1 - c2 * (D * lag_time / r_0^2));
                        else
                            curr_trappedness(kk, 1) = 0;
                        end
                    end
                end
                
                new_col = [new_col; curr_trappedness];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Trappedness'];
end


function [] = engineerStepAngleAsymmetry(app, h_progress)
%Feature engineering for local setp angle asymmetry, 17/06/2024.
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
%Compute step angle asymmetry for each localisation. The asymmetry
%coefficient is defined as log2 ratio of forward (0 – 30 degrees) to
%backward (150 – 180 degrees) step angles,
%   AC = log2(N_forward_angles + 1 / N_backward_angles + 1)
%
%The use of +1 here is intended to prevent division/multiplication by zero
%if there are no values present in the small window. This handles this
%situation without introducing discontinuities or requiring a piecewise
%law.
%Positive values indicate forward bias; negative values indicate backward
%bias.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeStepAngles()
    
    N_cells     = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing step angle asymmetry for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID    = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track  = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:,4) == track_ID, :);
                
                if isempty(curr_track)
                    continue;
                end
                
                %compute step angles for entire track
                track_step_angles = computeStepAngles(curr_track(:, 1:2));
                track_step_angles = [track_step_angles(:, 2), curr_track(:, 3)];
                
                if size(curr_track, 1) < 3
                    curr_asymmetry = zeros(size(curr_track, 1), 1);
                else
                    %initialise values to write
                    curr_asymmetry  = zeros(size(curr_track, 1), 1);
                    
                    %loop over every window in track, computing step asymmetry for each time point - ignore the first two
                    %points as step angles can only be engineered for points with at least two previous localisations
                    for kk = 3:size(track_step_angles, 1)
                        %obtain local window
                        lim_lo      = track_step_angles(kk, 2) - window_size;
                        lim_hi      = track_step_angles(kk, 2) + window_size;
                        
                        %ensure empty region where step sizes cannot be caculated due to insufficient previous steps is not part of calculation
                        lim_lo = max(lim_lo, curr_track(3, 3));
                        
                        curr_angles = track_step_angles(track_step_angles(:, 2) >= lim_lo & track_step_angles(:, 2) <= lim_hi, 1);
                        
                        %count step angles in forward and backward regions
                        N_fwd = sum(abs(curr_angles) <= deg2rad(30));
                        N_bwd = sum(abs(curr_angles) >= deg2rad(150));
                        
                        %compute step asymmetry
                        curr_asymmetry(kk, 1) = log2((N_fwd + 1) / (N_bwd + 1));
                    end
                end
                
                new_col = [new_col; curr_asymmetry];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Step angle asymmetry'];
end


function [] = engineerLocalVACF(app, h_progress)
%Feature engineering for local velocity autocorrelation function,
%19/12/2024.
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
%Computes local empirical velocity autocorrelation function (VACF) for each
%localisation. The VACF is defined as the mean dot product of consecutive
%step vectors within a sliding window around each localisation,
%   VACF = (1 / (N - 2)) * sum((X(i+2) - X(i+1)) · (X(i+1) - X(i)))
%
%For each localisation, step vectors are computed as the difference
%between consecutive (x, y) coordinates (i.e., the displacement between
%frames) within a local window centred on that localisation. The dot
%product of each pair of consecutive step vectors is calculated and summed
%over the window, and the result is normalized by the number of such pairs
%(N - 2). This quantifies the correlation in the particle's movement over
%short time scales.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing local VACF for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:, 4) == track_ID, :);
                
                if isempty(curr_track)
                    continue;
                end
                
                %compute VACF vals for curr track
                curr_VACF = zeros(size(curr_track, 1), 1);
                for kk = 1:size(curr_track, 1)
                    lim_lo = curr_track(kk, 3) - window_size;
                    lim_hi = curr_track(kk, 3) + window_size;
                    
                    %get (x, y) coords of curr window
                    curr_window = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:2);
                    
                    if size(curr_window, 1) > 2
                        velocities      = diff(curr_window);
                        curr_VACF(kk)   = mean(sum(velocities(1:end-1, :) .* velocities(2:end, :), 2));
                    end
                end
                new_col = [new_col; curr_VACF];
            end
            
            %append feature to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end
    
    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Local VACF'];
end


function [] = engineerLocalMaximalExcursion(app, h_progress)
%Feature engineering for local maximal excursion, 19/12/2024.
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
%Compute local maximal excursion (ME) for each localisation. Maximal
%excursion is defined as the ratio of the maximum step size to the net
%displacement within a sliding window around each localisation as
%follows,
%   ME = max(|X(i+1) - X(i)|) / |X(N) - X(1)|
%
%For each localisation, step sizes are computed within a local window
%centered on that localisation. The maximum step size in the window is
%identified, and this is divided by the net displacement (the distance
%between the first and last points in the window). This feature captures
%significant jumps relative to the overall displacement, with higher values
%indicating large isolated steps.
%
%Note that this feature does not currently account for blinking, however it
%is possible to combine the feature with the 'Time from previous
%localisation' feature to enable this to be learned directly by the model
%during training when using datasets with excessive photoblinking.
%
%Input
%-----
%app        (handle)    main GUI handle
%h_progress (handle)    handle to existing progress bar
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_cells = size(app.movie_data.cellROI_data, 1);
    window_size = app.movie_data.state.local_win_size;
    
    for ii = 1:N_cells
        waitbar(ii / N_cells, h_progress, sprintf('Computing maximal excursion for cell %d of %d', ii, N_cells));
        
        if ~isempty(app.movie_data.cellROI_data(ii).filtered_track_IDs)
            new_col = [];
            
            %loop through filtered tracks
            for jj = 1:size(app.movie_data.cellROI_data(ii).filtered_track_IDs, 1)
                track_ID = app.movie_data.cellROI_data(ii).filtered_track_IDs(jj, 1);
                curr_track = app.movie_data.cellROI_data(ii).tracks(app.movie_data.cellROI_data(ii).tracks(:, 4) == track_ID, :);
                
                if isempty(curr_track)
                    continue;
                end
                
                %evaluate maximal excursion for track
                curr_ME = zeros(size(curr_track, 1), 1);
                for kk = 1:size(curr_track, 1)
                    lim_lo = curr_track(kk, 3) - window_size;
                    lim_hi = curr_track(kk, 3) + window_size;
                    curr_window = curr_track(curr_track(:, 3) >= lim_lo & curr_track(:, 3) <= lim_hi, 1:2);
                    
                    if size(curr_window, 1) > 1
                        step_sizes = sqrt(sum(diff(curr_window).^2, 2));
                        max_step_size = max(step_sizes);
                        net_displacement = norm(curr_window(end, :) - curr_window(1, :));
                        if net_displacement ~= 0
                            curr_ME(kk) = max_step_size / net_displacement;
                        else
                            curr_ME(kk) = 0; %handle zero net displacement - useful for handling any badly-designed simulations without noise
                        end
                    end
                end
                new_col = [new_col; curr_ME];
            end
            
            %append to tracks matrix
            app.movie_data.cellROI_data(ii).tracks = [app.movie_data.cellROI_data(ii).tracks, new_col];
        end
    end

    %update column titles accordingly
    app.movie_data.params.column_titles.tracks = [app.movie_data.params.column_titles.tracks, 'Local maximal excursion'];
end


function [] = engineerArbitraryFeatures(app, selected_arbitrary)
%Erase unwanted arbitrary features to leave only those requested by user,
%10/07/2025.
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
%Append arbitrary features requested by user to keep. This brings most
%recent implementation into public repo.
%
%Input
%-----
%app                (handle)    main GUI handle
%selected_arbitrary (cell)      cell array of arbitrary features user has
%                                   requested to keep
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    arb_cols    = app.movie_data.params.arbitrary_feature_cols(:).';
    arb_names   = app.movie_data.params.arbitrary_features(:).';
    titles      = app.movie_data.params.column_titles.tracks;
    N_arbs      = numel(arb_cols);
    start_arbs  = min(arb_cols);     %start of arbitrary cols, which must be passed into f'n as a single contiguous block
    
    %exit if no arb feat in original file
    if isempty(arb_cols) || isempty(arb_names)
        return
    end

    %make room in col titles for arb feature names to be inserted to match track column contents
    titles(start_arbs+N_arbs : end+N_arbs)      = titles(start_arbs:end);
    %insert arbitrary feature names into opened up region
    titles(start_arbs : start_arbs+N_arbs-1)    = arb_names;
    app.movie_data.params.column_titles.tracks  = titles;
    
    %compute which arb features were NOT selected
    if ischar(selected_arbitrary)
        selected_arbitrary = cellstr(selected_arbitrary);
    end
    kill_list = setdiff(arb_names, selected_arbitrary, 'stable');
    
    %for non-selected arb features, remove both col headers and data cols
    if ~isempty(kill_list)
        idx_to_kill = find(ismember(app.movie_data.params.column_titles.tracks, kill_list));
        
        %remove headers
        app.movie_data.params.column_titles.tracks(idx_to_kill) = [];
        
        %remove associated numeric data
        N_cells = numel(app.movie_data.cellROI_data);
        for ii = 1:N_cells
            if ~isempty(app.movie_data.cellROI_data(ii).tracks)
                app.movie_data.cellROI_data(ii).tracks(:, idx_to_kill) = [];
            end
        end
    end
end