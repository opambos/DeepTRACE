function [common] = findCommonTracks(varargin)
%Finds the tracks in common between annotation sets, Oliver Pambos,
%05/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: findCommonTracks
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
%This code has been adapted from an earlier external tool used for data
%exploration of saved analysis files, and incorporated into the main GUI.
%
%
%Inputs
%------
%varargin   (cell)  variable number of input cell arrays, one for each set
%                       annotation source
%
%Output
%------
%common (mat)   Nx2 matrix of tracks that are common to all annotation
%                   datasets, columns are,
%                       col1: Cell ID
%                       col2: Mol ID
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if nargin < 2
        error('At least two sets of annotations are required');
    end
    
    common_keys = cell2mat(cellfun(@(x) [x.CellID, x.MolID], varargin{1}, 'UniformOutput', false));
    for ii = 2:nargin
        model_keys = cell2mat(cellfun(@(x) [x.CellID, x.MolID], varargin{ii}, 'UniformOutput', false));
        common_keys = intersect(common_keys, model_keys, 'rows');
    end
    common = common_keys;
end