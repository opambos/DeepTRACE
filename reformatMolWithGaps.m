function [new_mol] = reformatMolWithGaps(mol)
%Reformat labelled molecule with gaps and contiguous frame numbers, Oliver
%Pambos, 25/05/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: reformatMolWithGaps
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
%This function identifies missing frames in a labelled molecule, mol, using
%diff() on the frame numbers, it then constructs a matrix of insertion
%locations in a new matrix, and loops through this matrix copying over the
%relevant sections of the old molecule leaving empty rows. Each time a new
%group of empty empty frames are inserted, the missing row numbers are
%generated in the gap, and the state label is copied from the most recent
%classification across the gap.
%
%Input
%-----
%mol       (mat)    labelled molecule data, rows are localisations, column 3 is frame number
%Output
%------
%new_mol   (mat)    labelled molecule data, reformatted such that missing localisations are now represented by rows
%                       of zeros, with retained frame numbers; note that state label is copied from the row above
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %if there are rows missing, add the missing rows
    if size(mol,1) < (mol(end,3) - mol(1,3) + 1)
        
        %pre-allocate for new molecule
        new_mol      = zeros((mol(end,3) - mol(1,3)) + 1, size(mol,2));
        
        %find the missing rows in mol
        changes(:,1) = diff(mol(:,3));
        insertion_mat = find(changes>1);
        
        %construct a matrix containing start and end rows for missing rows in new_mol
        for ii = 1:size(insertion_mat,1)
            insertion_mat(ii,2) = insertion_mat(ii,1) + changes(insertion_mat(ii,1)) - 1;
        end
        
        old_idx = 1;
        new_idx = 1;
        %loop over insertions
        for ii = 1:size(insertion_mat, 1)
            %number of rows to copy before inserting empty rows
            rows_to_copy = insertion_mat(ii, 1) - old_idx + 1;
            
            %copy rows from mol to new_mol
            new_mol(new_idx:(new_idx + rows_to_copy - 1), :) = mol(old_idx:(old_idx + rows_to_copy - 1), :);
            
            %update indices
            old_idx = old_idx + rows_to_copy;
            new_idx = new_idx + rows_to_copy;
        
            %calculate number of empty rows to insert
            N_empty = insertion_mat(ii, 2) - insertion_mat(ii, 1);
            
            %insert frame numbers into empty rows
            if N_empty > 0
                start_frame = mol(insertion_mat(ii, 1), 3) + 1;
                end_frame = (start_frame + N_empty - 1);
                
                new_mol(new_idx:(new_idx + N_empty - 1), 3) = start_frame:end_frame;

                %copy final column (label) to empty rows
                new_mol(new_idx:(new_idx + N_empty - 1), end) = mol(insertion_mat(ii, 1), end);
            end
            
            new_idx = new_idx + N_empty;
        end
        
        %copy any remaining rows from mol to new_mol
        if old_idx <= size(mol, 1)
            new_mol(new_idx:end, :) = mol(old_idx:end, :);
        end
        
    else
        new_mol = mol;
    end
    
end
