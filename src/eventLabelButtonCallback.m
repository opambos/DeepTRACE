function [] = eventLabelButtonCallback(app, btn)
%Callbacks for dynamically generated state labelling buttons in the human
%annotation system, Oliver Pambos, 29/10/2022.
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
%This function was split into a separate .m file on 15/05/2024 as it is
%required outside the scope of regenerateLabelButtons to enable keyboard
%control of the dynamically generated buttons directly from the main GUI.
%
%
%Inputs
%------
%app    (handle)    main GUI handle
%btn    (handle)    handle to button object
%
%Output
%------
%app    (handle)    main GUI handle, now with the generated buttons
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    app.movie_data.state.current_label = btn.Text;
    addPartialVisualLabel(app);
    focus(app.DeepTRACEUIFigure);
end
