function [] = identifyExcludedSteps(app)
%Use string comparisons to user-selected feature names to determine which
%rows contain useless information, 13/01/2024.
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
%There are many known features that may not be available at the start or
%end of a trajectory. For example, the feature 'step size' represents the
%Euclidean distance between localisations there is no information encoded
%in the first frame. The first row of every trajectory therefore requires
%separate handling, either through cropping the rows, imputation, masking
%with a new feature, or some other process to identify or minimise the
%impact on the trained model. Currently this is handled either through
%imputation or deletion from both the training and later classified data.
%Similarly, the feature 'following step size' will have an empty entry at
%the end of the trajectory. Inluding these features would complicate
%training of the models.
%
%As many of these features have known strings assigned to them during data
%preparation, the column titles can be interpreted here using a series of
%string comparisons to automatically suggest to the user rows to remove.
%These values are returned to the GUI, where the user can override the
%decisions if necessary prior to training; this may be necessary for a
%number of reasons, for example if the localisation data comes from an
%as-yet unknown localisation algorithm with unknown feature names.
%
%This functionality may later be expanded upon by allowing the user to read
%in a file containing feature-row removal information, likely in the form
%of a dictionary/hash table.
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
    
    %ensure there are selected features to read; then zero counters
    if size(app.MLfeatures.CheckedNodes,1) == 0
        app.IgnorerowsfromstartSpinner.Value    = 0;
        app.IgnorerowsfromendSpinner.Value      = 0;
        return;
    end
    
    %compile a list of feature names
    for ii = 1:size(app.MLfeatures.CheckedNodes,1)
        feature_names{ii} = app.MLfeatures.CheckedNodes(ii).Text;
    end
    
    %zero the current values
    ignore_rows_start   = 0;
    ignore_rows_end     = 0;
    
    %interpret which rows to ignore from the list of selected feature names
    for ii = 1:length(feature_names)
        if ignore_rows_start < 1 && (strcmp(feature_names{ii}, "Time step interval from previous step (s)") || strcmp(feature_names{ii}, "Step size (nm)") || strcmp(feature_names{ii}, "Step angle relative to image (degrees)") || strcmp(feature_names{ii}, "Step angle relative to cell axis (degrees)"))
           ignore_rows_start = 1;
        elseif ignore_rows_start < 2 && (strcmp(feature_names{ii}, "Step angle relative to previous step (degrees, absolute)") || strcmp(feature_names{ii}, "Previous step size (nm)"))
            ignore_rows_start = 2;
        elseif ignore_rows_start < 3 && (strcmp(feature_names{ii}, "Second-to-last step size (nm)"))
            ignore_rows_start = 3;
        elseif ignore_rows_end < 1 && (strcmp(feature_names{ii}, "Following step size (nm)"))
            ignore_rows_end = 1;
        end
    end
    
    %update values in GUI
    app.IgnorerowsfromstartSpinner.Value    = ignore_rows_start;
    app.IgnorerowsfromendSpinner.Value      = ignore_rows_end;
end