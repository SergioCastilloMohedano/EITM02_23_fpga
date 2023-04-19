function [] = behavioral_model_sim_matlab_mnist_fpga(inf_mode, single_inf, noOfIts, rounding_WB, rounding_act, write_out)
    flag_permute_dense_weights = 1;
    tic;
    start_time = toc;
    
    % Rounding Parameters
    ws_weight = 10;
    fl_weight = 4;
    ws_act = 16;
    fl_act = 10;
    ws_bias = 16;
    fl_bias = 13;
    %% Load raw parameters of the model extracted from Python

    % Conv2D #0
    tmp_strct = load('conv2d_0_bias_mnist_fpga.mat');
    conv2d_0_bias = tmp_strct.(tmp_strct.label);
    tmp_strct = load('conv2d_0_weights_mnist_fpga.mat');
    conv2d_0_weights = tmp_strct.(tmp_strct.label);

    % Dense
    tmp_strct = load('dense_bias_mnist_fpga.mat');
    dense_bias = tmp_strct.(tmp_strct.label);
    tmp_strct = load('dense_weights_mnist_fpga.mat');
    dense_weights = tmp_strct.(tmp_strct.label);

    % Size of conv2d_x_weights is 8x3x3x1 (no_ofm, row, col, channels)
    % Permute dimensions so it's (row, col, channels, no_ofm):
    conv2d_0_weights = permute(conv2d_0_weights, [2 3 4 1]);

    
    %% Load Dataset (imported from python)
    tmp_strct = load('X_train_resized_mnist_fpga.mat');
    X_train = tmp_strct.(tmp_strct.label);
    tmp_strct = load('Y_train_mnist.mat');
    Y_train = tmp_strct.(tmp_strct.label);
    tmp_strct = load('X_test_resized_mnist_fpga.mat');
    X_test = tmp_strct.(tmp_strct.label);
    tmp_strct = load('Y_test_mnist.mat');
    Y_test = tmp_strct.(tmp_strct.label);

    clear tmp_strct

    % One hot encoding of classes
    Y_test = onehotencode(categorical(Y_test),1);
    labels = ["0"; "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8"; "9"];
    labels = categorical(labels);
    classes = categories(labels);
    % Permute Dimensions of "X_train" and "X_test":
    % from (image, row, col, ch) to (row, col, ch, image)
    X_train = permute(X_train, [2 3 4 1]);
    X_test = permute(X_test, [2 3 4 1]);
    
    % Permute Dimensions of "Y_test", for som reason they are
    % different from "Y_train". They are 10x10000 instead of 10000x10
    Y_test = permute(Y_test,[2 1]);
    
    hits = 0;

    % Rounding Weights
    if rounding_WB == "true"

%        q = quantizer('fixed', 'nearest', 'saturate', [ws_weight fl_weight]);
%        conv2d_0_weights_rn = round(q, conv2d_0_weights);
%        conv2d_0_weights = conv2d_0_weights_rn;
%        clear conv2d_0_weights_rn;
        conv2d_0_weights = fi(conv2d_0_weights,1,ws_weight,fl_weight).single;
%        dense_weights_rn = round(q, dense_weights);
%        dense_weights = dense_weights_rn;
%        clear dense_weights_rn;
        dense_weights = fi(dense_weights,1,ws_weight,fl_weight).single;
%        clear q;

        q = quantizer('fixed', 'nearest', 'saturate', [ws_bias fl_bias]);
        conv2d_0_bias_rn = round(q, conv2d_0_bias);
        conv2d_0_bias = conv2d_0_bias_rn;
        clear conv2d_0_bias_rn;
        dense_bias_rn = round(q, dense_bias);
        dense_bias = dense_bias_rn;
        clear dense_bias_rn;
        clear q;

    end
    
    %% Inference Mode
    if (inf_mode == "single")
        iterations = 1;
        if ((single_inf > 0) && ( single_inf <= size(X_test,4)))
            single_inf = single_inf;
        else
            single_inf = int32(rand()*size(X_test,4));
            disp("Test Input is out of range (>10,000).")
            disp("Test Input chosen randomly to be:")
            disp(single_inf);
        end
    elseif (inf_mode == "multi")
        if ((noOfIts > size(X_test,4)) || (noOfIts <= 0))
            disp("Number Of Iterations is out of Test Set range.")
            disp("Number Of Iterations has been set to 1,000")
            iterations = 1000;
        else
            iterations = noOfIts;
        end
    else
        disp("ERROR: 'inf_mode' parameter not specified correctly.");
        return
    end

    %% Inference
    for ii = 1:iterations
        
        if (inf_mode == "single")
            ifm_00 = X_test(:,:,:,single_inf);
        else
            ifm_00 = X_test(:,:,:,ii);
        end
        
        % 0ST CONVOLUTIONAL LAYER
        % no of Output Feature Maps after 1st Convolutional Layer
        noOfm_00 = size(conv2d_0_bias,2);
        
        % W/H of data output at 1st Convolutional Layer
        stride_00 = 1;
        padding_00 = 1;
        size_00 = ((length(ifm_00) -  size(conv2d_0_weights,1) + 2*padding_00) / stride_00) + 1;

        %Apply Convolutional Layer to Input
        %Create empty activation matrix
        conv2d_0 = zeros(size_00, size_00, noOfm_00); %(row,col,ch)
        conv2d_0_b = zeros(size_00, size_00, noOfm_00);
        conv2d_0_r = zeros(size_00, size_00, noOfm_00);

        % Max Activations trouhghout whole inference, input
        max_act_input(ii) = max(max(max(ifm_00)));
        min_act_input(ii) = min(min(min(ifm_00)));

        % Rounding Activations
        if rounding_act == "true"
            ifm_00_tmp = fi(ifm_00,1,ws_act,fl_act);
            ifm_00 = ifm_00_tmp.single;
            clear ifm_00_tmp;
        end

        %Convolve
        for i = 1:noOfm_00
            conv2d_0(:,:,i) = convolution(ifm_00, conv2d_0_weights(:,:,:,i), stride_00, padding_00);
        end

        %Add Bias
        for j = 1:noOfm_00
            conv2d_0_b(:,:,j) = conv2d_0(:,:,j) + conv2d_0_bias(j);
        end
        
        % Max Activations trouhghout whole inference, conv0
        max_act_conv0(ii) = max(max(max(conv2d_0_b)));
        min_act_conv0(ii) = min(min(min(conv2d_0_b)));

         % Rounding Activations
         if rounding_act == "true"
                 conv2d_0_b_tmp = fi(conv2d_0_b,1,ws_act,fl_act);
                 conv2d_0_b = conv2d_0_b_tmp.single;
                 clear conv2d_0_b_tmp;
         end
        
        %ReLU Activation
        conv2d_0_r = (conv2d_0_b .* (conv2d_0_b > 0));

        pSize = fix(size(conv2d_0_r, 1)/2); % Data Output After Pooling w/ Stride = 2 and kSize = 2x2
        pNoOfm = noOfm_00;                  % no of Output Feature Maps after pooling

        % 0ST MAX POOLING LAYER
        % Apply Max Pooling 2x2 with Stride = 2
        MaxPool_0 = zeros(pSize, pSize, pNoOfm);

        for i = 1:pNoOfm
            MaxPool_0(:,:,i) = pool2d(conv2d_0_r(:,:,i), 2, 2, 0, "max");
        end

        if ((write_out == '1') && (inf_mode == "single"))
            IFM_BRAM_WORDLENGTH = 32;
            activations_per_word = IFM_BRAM_WORDLENGTH/ws_act;
            act_cnt = 0;
            word = '';

            fid = [];
            fid(1) = fopen("coe_golden_out_BRAM.coe", 'w');
            fprintf(fid(1), 'memory_initialization_radix=2;\n');
            fprintf(fid(1), 'memory_initialization_vector= ');
            for ch = 1 : size(MaxPool_0,3)
                for col = 1 : size(MaxPool_0,2)
                    for row = 1 : size(MaxPool_0,1)
                        act_cnt = act_cnt + 1;
                        tmp_fi = fi(MaxPool_0(row, col, ch), 1, ws_act, fl_act);
                        word = append(word, tmp_fi.bin);
                        if (act_cnt == activations_per_word)
                            fprintf(fid(1), '%s\n', word);
                            word = '';
                            act_cnt = 0;
                        end
                    end
                end
            end
            fprintf(fid(1), ';');
            % Close .coe golden_out BRAM
            fclose(fid(1));
        end

        %Flatten Layer
        Size = size(MaxPool_0, 1) * size(MaxPool_0, 2) * size(MaxPool_0, 3);
        noNeurons = size(dense_bias, 2);
        noChannels = size(MaxPool_0, 3);
        flatten = [];

        fc = zeros(1, noNeurons);
        fc_bias = zeros(1, noNeurons);

        %Flatten
%        for i = 1:size(MaxPool_0, 1)
%            for j = 1:size(MaxPool_0, 2)
%                for k = 1:noChannels
%                    flatten = [flatten, MaxPool_0(i,j,k)]; %channel-wise, row-wise, column-wise
%                end
%            end
%        end
        
        %Flatten
        for k = 1:noChannels
            for j = 1:size(MaxPool_0, 2)
                for i = 1:size(MaxPool_0, 1)
                    flatten = [flatten, MaxPool_0(i,j,k)]; %column-wise, row-wise, channel-wise
                end
            end
        end
        
        if flag_permute_dense_weights == 1
            flag_permute_dense_weights = 0;
            tmp_dense_weights = zeros(noNeurons, size(MaxPool_0, 1) * size(MaxPool_0, 2) * noChannels);
            index = 0;
            for i = 1:noNeurons
                for j = 1:noChannels % channels
                    for k = 1:size(MaxPool_0, 1) % rows
                        for l = 1:size(MaxPool_0, 2) % columns
                            index = index + 1;
                            tmp = dense_weights(i,(l-1)*((size(MaxPool_0, 1)*noChannels)) + (k-1)*(noChannels) + j);
                            tmp_dense_weights(i, index) = tmp;
                        end
                    end
                end
                index = 0;
            end
            
            dense_weights = tmp_dense_weights;
            clear tmp_dense_weights;
        end
        

        %Fully Connected Layer
        for i = 1: noNeurons
            fc(i) = sum(flatten .* dense_weights(i,1:Size));
        end

        %Bias
        for i = 1:noNeurons
            fc_bias(i) = fc(i) + dense_bias(i);
        end

        % Max Activations trouhghout whole training, dense
        max_act_dense(ii) = max(fc_bias);
        min_act_dense(ii) = min(min(min(fc_bias)));

        % Rounding activations
        if rounding_act == "true"
            fc_bias_tmp = fi(fc_bias,1,ws_act,fl_act);
            fc_bias = fc_bias_tmp.single;
            clear fc_bias_tmp;
        end
            
        %Softmax
        out = exp(fc_bias)/sum(exp(fc_bias));
        [xx,yy] = max(out);
        out_inf = out;
        out_inf(yy) = 1;

        X = onehotdecode(transpose((out)),classes,1);

        if (inf_mode == "single")
            disp(int8(out_inf));
            disp(int8(Y_test(single_inf,:)));
            Y = onehotdecode(transpose(int8(Y_test(single_inf,:))),classes,1);
            fprintf('Predict:\t%s.\nTrue:\t\t%s.\n',X,Y);
            % Loss Function (categorical cross-entropy error)
            L = sum((Y_test(single_inf,:)).*log(out),'all')*(-1);
            fprintf('Loss Function (categorical cross-entropy error):\t%f.\n\n',L);
            it_time = toc - start_time;
            avg_it_time = it_time/ii;
        else
            if (int8(out_inf) == int8(Y_test(ii,:)))
                hits = hits + 1;
            else
                hits = hits;
            end
            acc = (hits/ii)*100;
            disp("Accuracy: " + acc + " %" + "(" + ii + "/" + iterations + ")");
            Y = onehotdecode(transpose(int8(Y_test(ii,:))),classes,1);
            fprintf('Predicted:\t%s.\nReal:\t\t%s.\n',X,Y);
            % Loss Function (categorical cross-entropy error)
            L = sum((Y_test(ii,:)).*log(out),'all')*(-1);
            fprintf('Loss Function (categorical cross-entropy error):\t%f.\n',L);
            it_time = toc - start_time;
            avg_it_time = it_time/ii;
            fprintf('Average Iteration Time:\t%f seconds.\n\n',avg_it_time);
        end
    end
    total_time = toc;
    fprintf('Total Elapsed Time:\t%f mins.\n',(total_time/60));
    fprintf('Approximate Time for whole Val. Dataset:\t%f hours.\n',(((avg_it_time*size(X_test,4))/60)/60));            

    fprintf("Max Act. Input:\t%f\n", max(max_act_input));
    fprintf("Min Act. Input:\t%f\n", min(min_act_input));
    fprintf("Max Act. Conv0:\t%f\n", max(max_act_conv0));
    fprintf("Min Act. Conv0:\t%f\n", min(min_act_conv0));
    fprintf("Max Act. Dense:\t%f\n", max(max_act_dense));
    fprintf("Min Act. Dense:\t%f\n", min(min_act_dense));
    fprintf("Max Weights. Conv0:\t%f\n", max(max(max(max(dense_weights)))));
    fprintf("Min Weights. Conv0:\t%f\n", min(min(min(min(dense_weights)))));
    fprintf("Max Weights. Dense:\t%f\n", max(max(max(max(dense_weights)))));
    fprintf("Min Weights. Dense:\t%f\n", min(min(min(min(dense_weights)))));

end

%% Testing
% Filters
%    A_test = int8(10*rand(8, 8, 1, 1)); %(k_col,k_row,ch,no_ofm)
% % % % B_test = int8(10*rand(8, 8, 3, 1)); %(col,row,ch,images)
% % % % noOfm = size(A_test,4);
% % % % stride = 1;
% % % % padding = 1;
% % % % size = ((length(B_test) -  size(A_test,1) + 2*padding) / stride) + 1;
% % % 
% % 
% MaxPool = zeros(4, 4, 1, 1);
% R = zeros(4, 4, 1, 1);
% C = zeros(4, 4, 1, 1);
% [MaxPool(:,:), R(:,:), C(:,:)] = pool2d_test(A_test, 2, 2, 0, "max");
% 
% ups_matrix = zeros(8,8, 1);
% %fil upsampling matrix with dx gradients
% for k = 1:1
%     for i = 1:4
%         for j = 1:4
%                 ups_matrix(R(i,j,k),C(i,j,k)) = MaxPool(i,j,k);
%         end
%     end
% end
%flatten = [];
% for i = 1:size(A_test, 1)
%     for j = 1:size(A_test, 2)
%         for k = 1:size(A_test, 3)
%             flatten = [flatten, A_test(i,j,k)]; %channel-wise, row-wise, column-wise
%         end
%     end
% end
% 
% % Unflatten dx. from [1x196] to [14x14] [row x col]
% A_test_unflatten = zeros(size(A_test, 1), size(A_test, 2), size(A_test, 3));
% index = 1;
% for k = 1:size(A_test, 3)
%     for j = 1:size(A_test, 2)
%         for i = 1:size(A_test, 1)
%             A_test_unflatten(i,j,k) = A_test(index);
%             index  = index + 1;
%         end
%     end
% end




% conv2d = zeros(size, size, noOfm); %(col,row,ch)
% 
% 
% for i = 1:noOfm
%     conv2d(:,:,i) = convolution(B_test, A_test(:,:,:,i), stride, padding, "floating");
% end
% 
% % row wise sliding
% for k_row = 1:size(A_test,1)
%     for k_col = 1:size(A_test,2)
%         disp(A_test(k_row,k_col,1,1));
%     end
% end

% array_example = ceil(rand(5,3,4,2)*100); % neurons, columns, rows, channels
% neurons = size(array_example,1);
% columns = size(array_example,2);
% rows = size(array_example,3);
% channels = size(array_example,4);
% 
% flatten = [];
% array_example_flatten = zeros (neurons, columns * rows * channels);
% T = zeros(channels,rows,columns);
% 
% %Array Example Flatten
% for l = 1:neurons
%     for i = 1:columns
%         for j = 1:rows
%             for k = 1:channels
%                 flatten = [flatten, array_example(l,i,j,k)]; %channel-wise, row-wise, column-wise
%             end
%         end
%     end
%     array_example_flatten(l,:) = flatten;
%     flatten = [];
% end
% 
% array_reshaped = zeros(neurons, columns, rows, channels);
% for i = 1:neurons
%     for j = 1:channels % channels
%         for k = 1:rows % rows
%             for l = 1:columns % columns
%                 tmp = array_example_flatten(i,(l-1)*((rows*channels)) + (k-1)*(channels)+j)
%                 if tmp == array_example(i,l,k,j)
%                     disp("ok");
%                 end
%                 array_reshaped(i,l,k,j) = tmp;
%             end
%         end
%     end
% end
% 
% array_example == array_reshaped;