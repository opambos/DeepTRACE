function [value] = getFITSMeta(ffFile, ffPath, param)
%Retrieves a specific parameter from FITS meta data, Oliver Pambos,
%13/11/2020.
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
%ffFile     (string)    FITS file name
%ffPath     (string)    FITS file path
%param      (string)    parameter name to look up
%
%Output
%------
%value      (string)    value found in meta data - note this is always a string, numerical data will require str2num() after f'n
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    meta_data = fitsinfo(fullfile(ffPath, ffFile));
    LUT = meta_data.PrimaryData.Keywords;
    idx = ismember(LUT(:,1), param);
    value = string(LUT(idx,2));
end