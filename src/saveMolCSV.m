function [] = saveMolCSV(app, result_ID, cell_ID, mol_ID, video_name)
%Export CSV data of a molecule that has been segmented/classified using the
%human annotation tool, Oliver Pambos, 14/11/2022.
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
%This subroutine takes in the ID of the molecule from the LabelledMols
%substruct, and exports the associated CSV file. This is used in by the
%system to package the CSV labelled molecule data with its corresponding
%video illustration to enable faster illustration when preparing for public
%presentation of data.
%
%Inputs
%------
%app        (struct)    main GUI data struct
%result_ID  (int)       ID of the molecule in the LabelledMols substruct (note that this is not mol_ID used elsewhere in the code)
%cell_ID    (int)       unique cell ID in the original main struct
%mol_ID     (int)       unique molecule ID in the original main struct
%video_name (str)       name of the video to be saved, unique identifiers are also appended to this string
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %append cell and mol numbers to file name; also handles error in case user forgets to enter a video name
    if exist('video_name', 'var')
        video_name = string(video_name) + "_C" + num2str(cell_ID) + "_M" + num2str(mol_ID);
    else
        video_name = "unnamed_video_C" + num2str(cell_ID) + "_M" + num2str(mol_ID);
    end
    
    if ~exist(fullfile(app.movie_data.params.ffPath, 'Saved molecule videos', video_name), 'dir')
        mkdir(fullfile(app.movie_data.params.ffPath, 'Saved molecule videos', video_name));
    end
    
    %generate a table from the saved column titles, and write to disk
    T = array2table(app.movie_data.results.VisuallyLabelled.LabelledMols{result_ID, 1}.Mol);
    T.Properties.VariableNames = app.movie_data.params.column_titles.tracks;
    writetable(T, fullfile(app.movie_data.params.ffPath, 'Saved molecule videos', video_name, strcat(video_name, '_labelled.csv')));
end