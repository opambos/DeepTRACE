function [common] = findCommonAnnotatedTracks(all_labels, annotation_fields)
%Finds the completed track annotations that are common to multiple
%annotation sources, Oliver Pambos, 12/08/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findCommonAnnotatedTracks
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
%This function is an improvement of the findCommonTracks() function, which
%it calls, and then filters the results to ensure that all common tracks
%also contain fully annotated localisations. The original function has been
%left unmodified as it is used elsewhere.
%
%Inputs
%------
%all_labels         (struct)        struct of cell arrays where each cell
%                                       array contains an annotation
%                                       source, see calling function
%annotation_fields  (cell_array)    Nx1 cell array of char arrays, each of
%                                       which contains the char array of
%                                       the exact struct in
%                                       app.movie_data.results which
%                                       contains the annotation source data
%
%Output
%------
%common (mat)   Nx2 matrix of fully-annotated tracks that are common to all
%                   annotation sources, columns are,
%                       col1: Cell ID
%                       col2: Mol ID
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%findCommonTracks()
    
    %find common tracks across multiple annotation fields
    varargin = cellfun(@(field) all_labels.(field), annotation_fields, 'UniformOutput', false);
    common = findCommonTracks(varargin{:});
    
    %loop over all annotation fields and check for '-1' in each track, eliminating those that are not fully annotated
    for ii = 1:numel(annotation_fields)
        cell_array = all_labels.(annotation_fields{ii});
        
        %loop over each common track
        to_remove = false(size(common, 1), 1);
        for jj = 1:size(common, 1)
            %find the corresponding entry in the cell array
            idx = find(cellfun(@(x) x.CellID == common(jj, 1) && x.MolID == common(jj, 2), cell_array));
            
            %if any Labels vector contains a -1, mark it for removal
            if any(cell_array{idx, 1}.Labels == -1)
                to_remove(jj) = true;
            end
        end
        
        %remove the marked tracks, and move to next annotation source
        common(to_remove, :) = [];
    end
end