function [model_size] = calcModelSize(N_features, N_units, N_layers, N_classes, attn, model_type)
%Compute size of an RNN model, Oliver Pambos, 15/09/2024.
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
%Computes the size of an RNN model prior to training.
%
%Inputs
%------
%N_features     (int)   number of features in use
%N_units        (int)   number of recurrent units in each layer
%N_layers       (int)   number of RNN layers
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
        params_attn = calcAttentionParams(N_units, is_bidirectional);
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
    
    total_params = 0;
    for ii = 1:N_layers
        if ii == 1
            %first layer: input size = N_features
            total_params = total_params + ((N_features + N_units) * 4 * N_units + 4 * N_units);
        else
            %subsequent layers: input size = N_units
            total_params = total_params + ((N_units + N_units) * 4 * N_units + 4 * N_units);
        end
    end
end


function [total_params] = calcBiLSTMParams(N_features, N_units, N_layers)
%Compute parameter contribution from BiLSTM layers, Oliver Pambos,
%15/09/2024.
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


function [total_params] = calcGRUParams(N_features, N_units, N_layers)
%Compute parameter contribution from GRU layers, Oliver Pambos, 15/09/2024.
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
    
    total_params = 0;
    for ii = 1:N_layers
        if ii == 1
            total_params = total_params + ((N_features + N_units) * 3 * N_units + 3 * N_units);
        else
            total_params = total_params + ((N_units + N_units) * 3 * N_units + 3 * N_units);
        end
    end
end


function [total_params] = calcBiGRUParams(N_features, N_units, N_layers)
%Compute parameter contribution from BiGRU layers, Oliver Pambos,
%15/09/2024.
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


function [params_attn] = calcAttentionParams(N_units, is_bidirectional)
%Compute parameter contribution from attention layer, Oliver Pambos,
%15/09/2024.
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
%Computes the parameter count contribution from self-attention.
%
%Inputs
%------
%N_units            (int)   number of recurrent units in each layer
%is_bidirectional   (bool)  boolean value determining whether layer is
%                               bidirectional
%
%Output
%------
%params_attn        (int)   total parameter contribution from attention layer
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %determine input size to attention layer
    if is_bidirectional
        input_size = 2 * N_units;      %BiLSTM/BiGRU output dimension
    else
        input_size = N_units;          %LSTM/GRU output dimension
    end
    
    key_channels = N_units;
    
    params_attn = 4 * input_size * key_channels + 3 * key_channels + input_size;
end


function [params_fc] = calcFCParams(N_units, N_classes, is_bidirectional)
%Compute parameter contribution from fully connected layer, Oliver Pambos,
%15/09/2024.
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