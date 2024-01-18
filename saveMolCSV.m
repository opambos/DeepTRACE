function [] = saveMolCSV(app, result_ID, cell_ID, mol_ID, video_name)
%Export CSV data of a molecule that has been segmented/classified using the
%Event Labeller tool, Oliver Pambos, 14/11/2022.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: saveMolCSV
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