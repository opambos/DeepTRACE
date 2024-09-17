function [] = trainRNN(app)
%Train arbitrary RNN model on annotated data, Oliver Pambos, 15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: trainRNN
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
%This code is a refactoring of trainModel.m, which itself is a refactoring
%of earlier GUI-embedded RNN training implementation present in the main
%branch, and several local versions. This version generates any available
%RNN model architecture in a single function, based on user input during
%runtime.
%
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%computeMetricsPadded()
%computeMetrics()
%defineModelLayers()        - local to this .m file
%storeMetadata()            - local to this .m file
%computeClassWeights()      - local to this .m file
%getTrainingOptions()       - local to this .m file
%shuffleBySegment()         - local to this .m file
%transposeTrainValData()    - local to this .m file
%changepointWeightedLoss()  - local to this .m file
%genChangepointMasks()      - local to this .m file
    
    %get inputs from pop-up app
    popup = getRNNSettings(app);
    uiwait(popup.genRNNSettingsFigure);
    
    app.textout.Value = 'Preparing model';

    %obtain model_type string
    model_name = app.ModeltypeDropDown.Value;
    switch model_name
        case "Bidirectional LSTM (BiLSTM)"
            model_type = "BiLSTM";
        case "Long Short-Term Memory (LSTM)"
            model_type = "LSTM";
        case "Bidirectional Gated Recurrent Unit (BiGRU)"
            model_type = "BiGRU";
        case "Gated Recurrent Unit (GRU)"
            model_type = "GRU";
    end
    
    %store metadata and variables used for feature scaling and training with model
    storeMetadata(app, model_type);
    
    %compute class weights
    app.textout.Value = 'Computing class weights';
    [~, class_weights] = computeClassWeights(app);
    
    %generate layers
    layers = defineModelLayers(app);
    
    %generate temporary reformatted versions of train and val datasets
    [train_data_tp, train_labels_tp, val_data_tp, val_labels_tp] = transposeTrainValData(app.movie_data.results.train_data,...
                                                                                         app.movie_data.results.train_labels,...
                                                                                         app.movie_data.results.val_data,...
                                                                                         app.movie_data.results.val_labels);
    
    %shuffle again the training and validation data this time by segment (in whole track mode this has no effect)
    [train_data_tp, train_labels_tp]    = shuffleBySegment(train_data_tp, train_labels_tp);
    [val_data_tp, val_labels_tp]        = shuffleBySegment(val_data_tp, val_labels_tp);
    
    %set training options
    options = getTrainingOptions(val_data_tp, val_labels_tp, true, app.movie_data.state.training.max_epochs,...
                                                                   app.movie_data.state.training.batch_size,...
                                                                   app.movie_data.state.training.learn_rate,...
                                                                   app.movie_data.state.training.val_interval,...
                                                                   app.movie_data.state.training.val_patience);
    
    %train model with requested loss function
    switch app.movie_data.state.training.loss_fn
        case "Class weighted"
            lossFcn = @(YPred, YTrue) crossentropy(YPred, YTrue, Weights=class_weights, WeightsFormat='C');
            app.movie_data.models.(model_type).model = trainnet(train_data_tp, train_labels_tp, layers, lossFcn, options);
            
        case "Transition and class weighted"
            app.movie_data.models.(model_type).model = trainnet(train_data_tp, train_labels_tp, layers, ...
                @(YPred, YTrue) changepointWeightedLoss(YPred, YTrue, class_weights), options);
    end
    
    %compute metrics on test data
    if app.movie_data.results.padding
        [accuracy, precision, recall, f1_score, ~] = computeMetricsPadded(app.movie_data.models.(model_type).model, app.movie_data.results.test_data, app.movie_data.results.test_labels, true);
    else
        [accuracy, precision, recall, f1_score, ~] = computeMetrics(app.movie_data.models.(model_type).model, app.movie_data.results.test_data, app.movie_data.results.test_labels, true);
    end
    app.textout.Value = "Accuracy: " + num2str(accuracy) + newline + "Precision: " + num2str(precision) + newline + "Recall: " + num2str(recall) + newline + "F1 Score: " + num2str(f1_score);
end


function [layers] = defineModelLayers(app)
%Define the model layers dynamically based on user input during runtime,
%Oliver Pambos 15/09/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: defineModelLayers
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
%This code is a refactoring of trainModel.m, which itself is a refactoring
%of earlier GUI-embedded RNN training implementation present in the main
%branch, and several local versions. This version generates any available
%RNN model architecture in a single function, based on user input during
%runtime.
%
%
%Inputs
%------
%app    (handle)    main GUI handle
%
%Output
%------
%layers (lyr)       layer array holding layer definitions of the model
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %accommodate padding in whole track mode, until replaced by masking
    if app.movie_data.results.padding == true
        N_features  = numel(app.movie_data.models.temp_params.feature_names) + 1;   %extra padding feature
        N_classes   = size(app.movie_data.params.class_names, 1) + 1;               %additional class for padded region of track
    else
        N_features  = numel(app.movie_data.models.temp_params.feature_names);
        N_classes   = size(app.movie_data.params.class_names, 1);
    end
    
    %initialize empty list of layers with a name for the input layer
    layers = [sequenceInputLayer(N_features, 'Name', 'input_layer')];
    
    %add RNN layers based on user selection
    for ii = 1:app.movie_data.state.RNN.N_layers
        %insert appropriate RNN layer based on model type
        switch app.ModeltypeDropDown.Value
            case 'Long Short-Term Memory (LSTM)'
                layers = [layers; lstmLayer(app.movie_data.state.RNN.N_units, ...
                    'OutputMode', 'sequence', ...
                    'InputWeightsL2Factor', app.movie_data.state.RNN.input_weights_L2, ...
                    'RecurrentWeightsL2Factor', app.movie_data.state.RNN.recurrent_weights_L2, ...
                    'BiasL2Factor', app.movie_data.state.RNN.bias_L2, ...
                    'Name', sprintf('LSTM_layer_%d', ii))]; %name each LSTM layer with its index
    
            case 'Bidirectional LSTM (BiLSTM)'
                layers = [layers; bilstmLayer(app.movie_data.state.RNN.N_units, ...
                    'OutputMode', 'sequence', ...
                    'InputWeightsL2Factor', app.movie_data.state.RNN.input_weights_L2, ...
                    'RecurrentWeightsL2Factor', app.movie_data.state.RNN.recurrent_weights_L2, ...
                    'BiasL2Factor', app.movie_data.state.RNN.bias_L2, ...
                    'Name', sprintf('BiLSTM_layer_%d', ii))];
    
            case 'Gated Recurrent Unit (GRU)'
                layers = [layers; gruLayer(app.movie_data.state.RNN.N_units, ...
                    'OutputMode', 'sequence', ...
                    'InputWeightsL2Factor', app.movie_data.state.RNN.input_weights_L2, ...
                    'RecurrentWeightsL2Factor', app.movie_data.state.RNN.recurrent_weights_L2, ...
                    'BiasL2Factor', app.movie_data.state.RNN.bias_L2, ...
                    'Name', sprintf('GRU_layer_%d', ii))];
    
            case 'Bidirectional Gated Recurrent Unit (BiGRU)'
                layers = [layers; bigruLayer(app.movie_data.state.RNN.N_units, ...
                    'OutputMode', 'sequence', ...
                    'InputWeightsL2Factor', app.movie_data.state.RNN.input_weights_L2, ...
                    'RecurrentWeightsL2Factor', app.movie_data.state.RNN.recurrent_weights_L2, ...
                    'BiasL2Factor', app.movie_data.state.RNN.bias_L2, ...
                    'Name', sprintf('BiGRU_layer_%d', ii))];
    
            otherwise
                error('Unsupported model type selected.');
        end
    
        %if it's not the final stacked RNN layer, add intra-stack dropout
        if ii < app.movie_data.state.RNN.N_layers
            layers = [layers; dropoutLayer(app.movie_data.state.RNN.interlayer_dropout, ...
                'Name', sprintf('dropout_following_RNN_layer_%d', ii))];
        end
    end
    
    %add attention layer if selected
    if app.movie_data.state.RNN.attn
        N_key_channels = app.movie_data.state.RNN.N_units;  %number of key channels is number of hidden units here
        layers = [layers; selfAttentionLayer(app.movie_data.state.RNN.N_heads, N_key_channels, ...
            'Name', 'self_attention')];
        
        %add layer normalization after attention
        layers = [layers; layerNormalizationLayer('Name', 'attention_norm')];
    end
    
    %add the final dropout layer
    layers = [layers; dropoutLayer(app.movie_data.state.RNN.post_RNN_dropout, 'Name', 'final_dropout')];
    
    %add fully connected and softmax layers
    layers = [layers;
        fullyConnectedLayer(N_classes, 'Name', 'fully_connected');
        softmaxLayer('Name', 'softmax')];
end


function [options] = getTrainingOptions(val_data, val_labels, show_plot, max_epochs, batch_size, learn_rate, val_interval, val_patience)
%Returns the training options for use with the trainnet function, Oliver
%Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: getTrainingOptions
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
%Returns training options. This function was introduced to minimise
%repetitions of training option definitions in multiple training functions.
%
%Inputs
%------
%app        (handle)    main GUI handle
%
%Output
%------
%options    (obj)       object containing training options
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    if show_plot
        plot_option = 'training-progress';
    else
        plot_option = 'none';
    end
    
    options = trainingOptions('adam', ...
        'MaxEpochs', max_epochs, ...
        'MiniBatchSize', batch_size, ...
        'InitialLearnRate', learn_rate, ...
        'Verbose', 0, ...
        'Plots', plot_option, ...
        'Metrics', 'accuracy', ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropPeriod', 2, ...
        'LearnRateDropFactor', 0.3, ...
        'ValidationData', {val_data, val_labels}, ...
        'ValidationFrequency', val_interval, ...
        'ValidationPatience', val_patience, ...
        'Shuffle', 'every-epoch', ...
        'OutputNetwork', 'best-validation-loss');
end


function [classes, class_weights] = computeClassWeights(app)
%Balance class weights by the inverse of the frequency with which they
%occur, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: computeClassWeights
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
%Computes class weights from the inverse of their relative frequency across
%the training data.
%
%Inputs
%------
%app            (handle)    main GUI handle
%
%Output
%------
%classes        (cell)      cell array of classes, in this case stored as
%                               strings of the integers, which are used as
%                               look-up IDs for the real class names found
%                               in app.movie_data.params.class_names
%class_weights  (vec)       row vector of relative class weights (there are
%                               not required to be normalised)
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %concat train labels into single matrix
    train_labels_concat = vertcat(app.movie_data.results.train_labels{:});
    
    %get classes (categoricals in matlab store all possible categories, even if not all categories actually appear in data)
    unique_classes  = categories(train_labels_concat);
    N_classes       = numel(unique_classes);
    
    %count frequency of each class across all annotations in training set
    class_counts = zeros(1, N_classes);
    for ii = 1:N_classes
        class_counts(ii) = sum(sum(train_labels_concat == unique_classes{ii}));
    end
    
    %compute class weights by inverse of class frequencies, and then normalise
    class_weights = 1 ./ class_counts;
    class_weights = class_weights / sum(class_weights) * N_classes;
    
    %define classes for classification layer
    classes = unique_classes;
end


function [] = storeMetadata(app, model_type)
%Store metadata and variables used for feature scaling and training with
%model, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: storeMetadata
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
%This function writes the metadata associated with the the model, and its
%training to the associated model substruct of the results struct. This was
%moved from the main .mlapp file for improved readability and modularity.
%
%Inputs
%------
%app        (handle)    main GUI handle
%model_type (str)       struct name for the model in found in the results struct
%
%Output
%------
%None
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    app.movie_data.models.(model_type)                  = app.movie_data.models.temp_params;
    app.movie_data.models.(model_type).model_name       = app.ModeltypeDropDown.Value;
    [app.movie_data.models.(model_type).model_type, app.movie_data.models.current_model] = deal(model_type);
    app.movie_data.models.(model_type).class_names      = app.movie_data.params.class_names;
    app.movie_data.models.(model_type).feature_names    = app.movie_data.params.column_titles.tracks([app.movie_data.models.temp_params.feature_cols]);
    app.movie_data.models.(model_type).user             = app.UserEditField.Value;
    app.movie_data.models.(model_type).timestamp        = string(datetime);
    app.movie_data.models.(model_type).max_len          = size(app.movie_data.results.train_data{1,1}, 2);
    
    %keep track of whether data was padded
    if app.movie_data.results.padding == true
        app.movie_data.models.(model_type).windowed = false;
    else
        app.movie_data.models.(model_type).windowed = true;
    end
end


function [train_data, train_labels, val_data, val_labels] = transposeTrainValData(train_data, train_labels, val_data, val_labels)
%Transpose the data and labels in cell arrays of training and validation
%datasets to prepare data for use with trainnet(), Oliver Pambos,
%13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: transposeTrainValData
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
%Inputs
%------
%train_data     (cell)  Nx1 cell array of training data examples, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%train_labels   (cell)  Nx1 cell array of training labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%val_data       (cell)  Mx1 cell array of validation data examples, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options. Dimensions are FxT,
%                                   dim1: Feature
%                                   dim2: Timepoint
%val_labels     (cell)  Mx1 cell array of validation labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options. Dimensions are 1xT.
%
%Output
%------
%train_data     (cell)  training data reformatted so that each example is
%                           transposed to give dimensions of TxF
%train_labels   (cell)  training labels reformatted so that each example is
%                           transposed to give dimensions of Tx1
%val_data       (cell)  validation data reformatted so that each example is
%                           transposed to give dimensions of TxF
%val_labels     (cell)  validation labels reformatted so that each example
%                           is transposed to give dimensions of Tx1
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    for ii = 1:size(train_data, 1)
        train_data{ii} = transpose(train_data{ii});
        train_labels{ii} = transpose(train_labels{ii});
    end
    for ii = 1:size(val_data, 1)
        val_data{ii} = transpose(val_data{ii});
        val_labels{ii} = transpose(val_labels{ii});
    end
end


function [shuffled_data, shuffled_labels] = shuffleBySegment(data, labels)
%Reshuffle all data again by segment, Oliver Pambos, 14/08/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: shuffleBySegment
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
%Inputs
%------
%data   (cell)      Nx1 cell array of training data examples, where
%                               each cell may contain either a single
%                               sliding window or a full track depeding
%                               upon options.
%labels (cell)      Nx1 cell array of training labels, where each
%                               cell may contain either a single sliding
%                               window or a full track depeding upon
%                               options.
%
%
%Output
%------
%shuffled_data      (cell)  data after reshuffling
%shuffled_labels    (cell)  labels after reshuffling
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %shuffle indices
    shuffled_idx = randperm(numel(data));
    
    %shuffle data and labels using the shuffled indices
    shuffled_data   = data(shuffled_idx);
    shuffled_labels = labels(shuffled_idx);
end


function [loss] = changepointWeightedLoss(YPred, YTrue, class_weights)
%Custom loss function using heavier weights for datapoints around regions
%of changepoints, as well as class weighting, Oliver Pambos, 13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: changepointWeightedLoss
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
%Computes the class-weighted and transition-proximal weighted loss. This
%function calculates the weighted cross-entropy loss for sequence data,
%where weights are assigned based on class importance and proximity to
%transition points (change points). Transition points are identified by
%changes in the ground truth annotations. This helps the model to focus
%more on critical transition areas, improving classification performance on
%such segments.
%
%Inputs
%------
%YPred          (dlarray)   CxWxT dlarray containing predicted
%                               probabilities for each window; dimensions
%                               are,
%                                   C: class
%                                   W: window number
%                                   T: timepoint in window
%YTrue          (dlarray)   CxWxT dlarray containing the annotations being
%                               used as ground truth; this is essentially a
%                               one-hot encoding for ground truth class
%class_weights  (vec)       1xC row vector of class weights (currently
%                               these are based entirely on dataset-wide
%                               class frequency)
%
%Output
%------
%loss           (float)     total weighted cross-entropy loss summed over
%                               all classes, windows, and timepoints;
%                               computed using both class weights and
%                               changepoint proximity mask weights
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%genChangepointMasksInLossFn()  - local to this .m file
    
    %define epsilon as smallest value for class predictions to avoid numerical instability
    epsilon = 1e-10;
    
    %changepoint additional weighting - this will be later replaced with user input
    cp_weight = 2;
    
    %clip predicted probabilities to avoid instability from log(0)
    YPred = max(YPred, dlarray(epsilon));
    
    [C, B, T] = size(YPred);
    
    %generate changepoint masks
    changepoint_masks = dlarray(genChangepointMasks(YTrue));
    
    %reformat class weights to match dimensions
    class_weights_expanded = dlarray(reshape(class_weights, [C, 1, 1]));
    class_weights_expanded = repmat(class_weights_expanded, [1, B, T]);

    %compute weights
    weights = (1 + cp_weight * changepoint_masks);
    weights = reshape(weights, [1, B, T]);
    weights = repmat(weights, [C, 1, 1]);
    weights = weights .* class_weights_expanded;
    
    %compute cross-entropy loss
    loss_per_class = -YTrue .* log(YPred);
    
    %apply weights, and compute total loss
    weighted_loss_per_class = loss_per_class .* weights;
    loss = sum(weighted_loss_per_class, 'all');
end


function [changepoint_masks] = genChangepointMasks(YTrue)
%Computes a changepoint mask for all windows for a batch, Oliver Pambos,
%13/07/2024.
%oliver.pambos@physics.ox.ac.uk
%
%
%MATLAB FUNCTION: genChangepointMasksInLossFn
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
%Generates a changepoint mask for the current batch of windows in the
%training set by processing the one-hot encoding of the ground truth
%annotations.
%
%Note that the distance (temporal) from each changepoint that defines
%inclusion in the mask is currently hardcoded. This will be updated with a
%user GUI control in a future update.
%
%Inputs
%------
%YTrue              (dlarray)   CxBxT dlarray containing the annotations
%                                   being used as ground truth for the
%                                   current batch; this is a one-hot
%                                   encoding for ground truth class
%
%Output
%------
%changepoint_masks  (mat)       BxT matrix binary mask for the current
%                                   batch for which 1 represents a
%                                   changepoint-proximal localisation, and
%                                   0 represents all other localisations,
%                                   each row represents a window of the
%                                   current batch, and each column
%                                   represents a timepoint within that
%                                   window. The dimensions are,
%                                       B: number of windows in current
%                                           batch
%                                       T: number of timepoints in each
%                                           window
%
%Dependent functions (excluding callbacks)
%-----------------------------------------
%None
    
    %distance from changepoint for inclusion in mask (will be replaced with input variable in future update)
    N = 3;
    
    [~, batchSize, timeSteps] = size(YTrue);
    changepoint_masks = zeros(batchSize, timeSteps);
    
    %loop over each window (sequence) in the batch
    for b = 1:batchSize
        temp_labels = squeeze(YTrue(:, b, :));
        temp_labels = extractdata(temp_labels);
        
        %convert sequence to row vector of states (one-hot encoding not useful for this task), and find changepoints
        [~, state_sequence] = max(temp_labels, [], 1);
        changepoints = find(diff(state_sequence) ~= 0);
        
        %generate mask
        for jj = 1:length(changepoints)
            idx_start = max(1, changepoints(jj) - N + 1);
            idx_end   = min(timeSteps, changepoints(jj) + N);
            
            changepoint_masks(b, idx_start:idx_end) = 1;
        end
    end
end