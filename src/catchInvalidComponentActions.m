function [data_present] = catchInvalidComponentActions(app, contents)
%Screens the current app handles to check whether the contents contains
%valid substructs required for onward code to prevent execution of code
%prior to valid data being loaded, 13/07/2025.
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
%This code streamlines and condenses the process of checks performed prior
%to execution of callbacks. This modularisation greatly reduces the work
%required to build new modules as the programmer can call this function to
%issue a number of tests, eliminating the need for code written locally to
%perform specific checks to avoid errors before they appear. This greatly
%simplifies the process of building new modules as each operation across
%DeepTRACE requires a specific set of conditions to be met. This handles
%errors that may arise from control inversion should a user attempt to
%perform operations in the wrong order.
%
%Furthermore, this approach enables each condition to be given an English-
%language description of the situation that triggers the action not to be
%performed, which can be understood by the end user, and this function maps
%this directly to the app.textout field in the main GUI. The result is a
%much cleaner and more compact code, more reliable error checking, and
%better user feedback.
%
%This function is given the app handles, and an arbitrary length cell array
%of strings, each element of which corresponds to a scenario or type of
%data that can be present during runtime in order perform the required
%action.
%
%Each case in the switch statement tests a different condition, these are,
%   "annotations"               do annotations exist (e.g. ground truth,
%                                   human annotations, model annotations)
%   "track inspector populated" does the track inspector UIAxes contain
%                                   any plotted data
%   "class names"               have class names been defined already
%   "model"                     is there a currently loaded model
%   "insight data"              has a results dataset been transferred to
%                                   the results.InsightData substruct for
%                                   presentation
%   "discovery source data"     has source data been selected in the
%                                   [Discovery] tab's dropdown menu
%   "imported track data"       is the raw imported track data
%                                   (cellROI_data) located present
%   "video files"               are the raw fluorescence video files linked
%                                   to in the params substruct
%
%Inputs
%------
%app        (handle)    main GUI handle
%contents   (cell)      cell array of strings describing types of data
%                           present in substructs
%
%Output
%------
%data_present   (bool)  true if data exists, false if not
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %single return value instructing calling code whether to proceed
    data_present = false;
    
    if ~isprop(app, "movie_data")
        app.textout.Value = "This operation is not available as there is currently no loaded data." + newline + "To load a data analysis file, click [File] > [Load analysis].";
        return;
    end

    %store results from each requested contents check
    check = false(numel(contents), 1);

    acc_error_str = "";
    
    %loop over data types, checking each is present
    for ii = 1:numel(contents)
        switch(contents{ii})
            case "annotations"
                if isfield(app.movie_data, "results")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "There are currently no track segmentation sources loaded. Please either load an analysis file containing annotation sources or perform either (i) human annotation, (ii) model annotaiton, or (iii) import ground truth to carry out this operation.";
                end
                
            case "class names"
                if isfield(app.movie_data, "params") && isfield(app.movie_data.params, "class_names") && ~isempty(app.movie_data.params.class_names)
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "There is no valid list of class names. Please load a valid analysis file or start human annotation of the dataset to define the class names.";
                end
                
            case "model"
                if isfield(app.movie_data, "models") && isfield(app.movie_data.models, "current_model")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "There is no active loaded model. To load a model, navigate to the [ML classification] tab, and select the [Classify using model] subtab to locate the model loading options.";
                end
            
            case "track inspector populated"
                if isprop(app.AnnotationUIAxes, "Children") && ~isempty(app.AnnotationUIAxes.Children)
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The track inspector is currently not populated. To display a track in an external figure window, please first display a track internally using the [Display track] button.";
                end
            
            case "insights axes populated"
                if isprop(app.UIAxes_compiled_events, "Children") && ~isempty(app.UIAxes_compiled_events.Children)
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The insights plotting axes are currently not populated. To perform this operation please first display the relevant data in the axes.";
                end
            
            case "human annotator populated"
                if isprop(app.UIAxes_event_labeller, "Children") && ~isempty(app.UIAxes_event_labeller.Children)
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "This function is only available when the human annotator has been populated with data. To perform this operation please begin the human annotation process.";
                end
                
            case "ML axes populated"
                if isprop(app.MLDataView, "Children") && ~isempty(app.MLDataView.Children)
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The ML classification plotting axes are currently not populated. To perform this operation please first display the relevant data in the axes.";
                end

            case "human annotation data"
                if isfield(app.movie_data, "results") && isfield(app.movie_data.results, "VisuallyLabelled")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "Human annotation data does not yet exist in the loaded dataset. To perform this oepration please begin the human annotation process.";
                end
                
            case "insight data"
                if isfield(app.movie_data, "results") && isfield(app.movie_data.results, "InsightData")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The annotation source has not yet been transferred to the active insights data for analysis. To rectify this move to the [Insights] tab, select the [Dataset overview] subtab, and select an annotation source from the [Source data] dropdown menu.";
                end
                
            case "discovery source data"
                if ~strcmp(app.DiscoverySourceDataDropDown.Value, '<< Select dataset >>')
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The source data for discovery mode has not been set. Please select an annotation source from the [Source data] dropdown menu of the [Discovery] tab.";
                end
            
            case "imported track data"
                if isfield(app.movie_data, "cellROI_data") && isfield(app.movie_data.cellROI_data, "tracks")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The currently loaded analysis file does not contain raw imported tracks. Either load a new DeepTRACE analysis file, or import data using [File] > [Load new data].";
                end
                
            case "video files"
                if isfield(app.movie_data, "params") && isfield(app.movie_data.params, "ffPath") && isfield(app.movie_data.params, "ffFile") && ~isempty(app.movie_data.params.ffPath) && ~isempty(app.movie_data.params.ffFile)
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The currently loaded analysis file does not contain an indexed link to the raw fluorescence video files. Either load a new DeepTRACE analysis file, or import data using [File] > [Load new data].";
                end
                
            case "file path"
                if isfield(app.movie_data, "params") && isfield(app.movie_data.params, "ffPath") && ~isempty(app.movie_data.params.ffPath)
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "No file path is currently defined; the path is recorded when loading data. Either load a new DeepTRACE analysis file, or import data using [File] > [Load new data].";
                end
                
            case "tracks column titles"
                if isfield(app.movie_data, "params") && isfield(app.movie_data.params, "column_titles") && isfield(app.movie_data.params.column_titles, "tracks") && ~isempty(app.movie_data.params.column_titles.tracks)
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The tracks column titles (feature names) are currently undefined, suggesting that feature engineering has not yet been performed. Either load a new DeepTRACE analysis file, or import data using [File] > [Load new data].";
                end
                
            case "training split"
                if isfield(app.movie_data, "results") && isfield(app.movie_data.params, "train")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The training data has not yet been generated. Either load a new DeepTRACE analysis file, or generate the training dataset.";
                end
                
            case "training source data"
                if ~strcmp(app.SourcedataDropDown.Value, '<< Select dataset >>')
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "The source data for training data generation has not been set. Please select an annotation source from the [Source data] dropdown menu of the [Generate training data] sub-tab inside the [ML classification] tab.";
                end
                
            case "model feature names"
                if isfield(app.movie_data, "models") && isfield(app.movie_data.models, "temp_params") && isfield(app.movie_data.models.temp_params, "feature_names")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "There is no active loaded model. To load a model, navigate to the [ML classification] tab, and select the [Classify using model] subtab to locate the model loading options.";
                end
                
            case "RF model"
                if isfield(app.movie_data, "models") && isfield(app.movie_data.models, "RF")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "There is no loaded random forest model.";
                end
                
            case "RF metrics"
                if isfield(app.movie_data, "models") && isfield(app.movie_data.models, "RF") && isfield(app.movie_data.models.RF, "metrics")
                    check(ii) = true;
                else
                    acc_error_str = acc_error_str + newline + newline + "Random forest SHAP metrics need to be evaluated before displaying values.";
                end
                
            otherwise
                
        end
    end
    
    %assign proceed flag if all data types exist
    if all(check)
        data_present = true;
    else
        %display to user list of insufficiencies encountered in current loaded data
        app.textout.Value = "This operation is currently unavailable with the loaded data, the following descriptions describe each piece of missing data, and how to rectify the problem through the GUI," + acc_error_str;
    end
end