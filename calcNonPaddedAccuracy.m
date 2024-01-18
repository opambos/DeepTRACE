function [accuracy] = calcNonPaddedAccuracy(model, data, labels)
%Calculate the accuracy of the model on the non-padded region of the data,
%Oliver Pambos, 28/04/2023.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcNonPaddedAccuracy
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
%This function provides a more accurate measure of model accuracy using
%only the non-padded regions of molecular trajectories. Neural network
%models trained using MATLAB's trainNetwork() function require a all
%trajectories to be of the same length. Rather than crop the trajectories
%to the shortest length one approach offered by the InVivoKinetics software
%is to instead pad all but the longest trajectory with zeros.
%
%Unfortunately MATLAB's trainNetwork() implementation does not allow for
%masking where the network's weights would only be updated for non-padded
%datapoints; as a workaround I have added another feature (always the final
%feature in the dataset) that indicates with a 1 or 0 whether the datapoint
%is a padded entry. The idea is that the network will quickly learn that
%this feature indicates which rows to ignore.
%
%As a consequence the accuracy metrics need to be based only on analysis of
%the non-padded (real) data; this function is a means to perform that
%metric. Note that I do not see any obvious way to alter MATLAB's default
%training visualisation; this function provides a way to obtain a more
%reliable indicator of accuracy when run on a hold out test.
%
%Input
%-----
%model      (mdl)       trained model (must be of NN type)
%data       (cell)      test data in the format of a Nx1 cell for N
%                           trajectories; each cell is of dimension MxP
%                           containing one trajectory where M is the number
%                           of features, and P is the length of the
%                           trajectory (including padding with zeros); the
%                           final row is the padding feature
%labels     (cell)      labels of the test set in the format of a 1xN cell
%                           for N trajectories; each cell is the sequence
%                           of labels for a trajectory in the form of a
%                           row vector (includes padding with zeros)
%
%Output
%------
%accuracy   (double)    accuracy of the model (range 0 - 1)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    N_mols              = numel(data);
    correct_predictions = 0;
    N_nonpadded_obs     = 0;
    
    for i = 1:N_mols
        %predict labels
        [predicted_labels, ~]   = classify(model, data{i});
        
        %identify non-padded rows (assumes final feature is padding indicator)
        nonpadded_idx           = data{i}(end,:) == 1;
        
        %keep track of accuracy metrics for non-padded points
        correct_predictions     = correct_predictions + sum(predicted_labels(nonpadded_idx) == labels{i}(nonpadded_idx));
        N_nonpadded_obs         = N_nonpadded_obs + sum(nonpadded_idx);
    end
    
    accuracy = correct_predictions / N_nonpadded_obs;
end

