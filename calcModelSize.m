function [model_size] = calcModelSize(N_features, N_units, N_layers, N_heads, N_classes, attn, model_type)
%Compute size of an RNN model, Oliver Pambos, 15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcModelSize
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
%Computes the size of an RNN model prior to training.
%
%Inputs
%------
%N_features     (int)   number of features in use
%N_units        (int)   number of recurrent units in each layer
%N_layers       (int)   number of RNN layers
%N_heads        (int)   number of attention heads
%N_classes      (int)   number of classes
%attn           (bool)  True if attention is used, False otherwise
%model_type     (str)   type of RNN used, options are,
%                           'Long Short-Term Memory (LSTM)'
%                           'Bidirectional LSTM (BiLSTM)'
%                           'Gated Recurrent Unit (GRU)'
%                           'Bidirectional Gated Recurrent Unit (BiGRU)'
%
%Output
%------
%model_size (int)       total size of model, in trainable parameters
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%calcLSTMParams()       - local to this .m file
%calcBiLSTMParams()     - local to this .m file
%calcGRUParams()        - local to this .m file
%calcBiGRUParams()      - local to this .m file
%calcAttentionParams()  - local to this .m file
%calcFCParams()         - local to this .m file
    
    %calculate total recurrent parameters based on model type
    switch model_type
        case 'Long Short-Term Memory (LSTM)'
            total_params_rnn = calcLSTMParams(N_features, N_units, N_layers);
            is_bidirectional = false;
        case 'Bidirectional LSTM (BiLSTM)'
            total_params_rnn = calcBiLSTMParams(N_features, N_units, N_layers);
            is_bidirectional = true;
        case 'Gated Recurrent Unit (GRU)'
            total_params_rnn = calcGRUParams(N_features, N_units, N_layers);
            is_bidirectional = false;
        case 'Bidirectional Gated Recurrent Unit (BiGRU)'
            total_params_rnn = calcBiGRUParams(N_features, N_units, N_layers);
            is_bidirectional = true;
        otherwise
            error('Unsupported model type selected.');
    end
    
    %calculate attention layer parameters if used
    if attn
        params_attn = calcAttentionParams(N_units, N_heads);
    else
        params_attn = 0;
    end
    
    %calculate fully connected layer parameters
    params_fc = calcFCParams(N_units, N_classes, is_bidirectional);
    
    %combine all params
    model_size = total_params_rnn + params_attn + params_fc;
end


function [total_params] = calcLSTMParams(N_features, N_units, N_layers)
%Compute parameter contribution from LSTM layers, Oliver Pambos,
%15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcLSTMParams
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
%Computes the parameter count contribution from LSTM layers.
%
%Inputs
%------
%N_features     (int)   number of features in use
%N_units        (int)   number of recurrent units in each layer
%N_layers       (int)   number of LSTM layers
%
%Output
%------
%total_params   (int)   total contribution from LSTM layers
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    params_per_layer = (N_features + N_units) * 4 * N_units + 4 * N_units;
    total_params = N_layers * params_per_layer;
end


function total_params = calcBiLSTMParams(N_features, N_units, N_layers)
%Compute parameter contribution from BiLSTM layers, Oliver Pambos,
%15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcBiLSTMParams
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
%Computes the parameter count contribution from BiLSTM layers.
%
%Inputs
%------
%N_features     (int)   number of features in use
%N_units        (int)   number of recurrent units in each layer
%N_layers       (int)   number of BiLSTM layers
%
%Output
%------
%total_params   (int)   total parameter contribution from BiLSTM layers
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    total_params = 0;
    for ii = 1:N_layers
        if ii == 1
            total_params = total_params + 2 * (4 * N_features * N_units + 4 * N_units * N_units + 4 * N_units);
        else
            total_params = total_params + 2 * (4 * 2 * N_units * N_units + 4 * N_units * N_units + 4 * N_units);
        end
    end
end


function total_params = calcGRUParams(N_features, N_units, N_layers)
%Compute parameter contribution from GRU layers, Oliver Pambos, 15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcGRUParams
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
%Computes the parameter count contribution from GRU layers.
%
%Inputs
%------
%N_features     (int)   number of features in use
%N_units        (int)   number of recurrent units in each layer
%N_layers       (int)   number of GRU layers
%
%Output
%------
%total_params   (int)   total parameter contribution from GRU layers
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    total_params = N_layers * ((N_features + N_units) * 3 * N_units + 3 * N_units);
end


function total_params = calcBiGRUParams(N_features, N_units, N_layers)
%Compute parameter contribution from BiGRU layers, Oliver Pambos,
%15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcBiGRUParams
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
%Computes the parameter count contribution from BiGRU layers.
%
%Inputs
%------
%N_features     (int)   number of features in use
%N_units        (int)   number of recurrent units in each layer
%N_layers       (int)   number of BiGRU layers
%
%Output
%------
%total_params   (int)   total parameter contribution from BiGRU layers
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    total_params = 0;
    for ii = 1:N_layers
        if ii == 1
            total_params = total_params + 2 * (3 * N_features * N_units + 3 * N_units * N_units + 3 * N_units);
        else
            total_params = total_params + 2 * (3 * 2 * N_units * N_units + 3 * N_units * N_units + 3 * N_units);
        end
    end
end


function params_attention = calcAttentionParams(N_units, N_heads)
%Compute parameter contribution from attention layer, Oliver Pambos,
%15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcAttentionParams
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
%Computes the parameter count contribution from self-attention.
%
%Inputs
%------
%N_units    (int)   number of recurrent units in each layer
%N_heads    (int)   number of attention heads
%
%Output
%------
%total_params   (int)   total parameter contribution from attention layer
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    params_attention = N_units * ((N_units / N_heads) * 3 * N_heads + N_units);
end


function params_fc = calcFCParams(N_units, N_classes, is_bidirectional)
%Compute parameter contribution from fully connected layer, Oliver Pambos,
%15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: calcFCParams
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
%Computes the parameter count contribution from the fully-connected layer.
%
%Inputs
%------
%N_units            (int)   number of recurrent units in each layer
%N_classses         (int)   number of output classes
%is_bidirectional   (bool)  determines whether requested RNN layer is
%                               bidirecitonal
%
%Output
%------
%total_params   (int)   total contribution of output layer, in number of
%                           parameters
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if is_bidirectional
        params_fc = 2 * N_units * N_classes + N_classes;
    else
        params_fc = N_units * N_classes + N_classes;
    end
end