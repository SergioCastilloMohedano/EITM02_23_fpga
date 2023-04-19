%% Network and HW Parameters
% HW Parameters of the Accelerator
X = 8; % # of PE columns in the HW Accelerator
Y = 3;  % # of PE rows in the HW Accelerator

% Network Parameters
layers = 2; %conv. and dense layers
p = [4];  % # of filter channel rows that can be allocated within a PE.
is_pooling = [1]; % 1 if there is pooling after, 0 if there is not.

strct = struct('name' , "", 'weights', [], 'biases', [], 'r', {}, 'C', {}, 'M', {}, 'RS', {}, 'HW', {}, 'EF', {}, 'M_div_pt', {}, 'C_div_r', {}); % define empty structure for conv. layers
N = repmat(strct,1,layers - 1); % create array of structures for Conv. layers
strct = struct('name' , "", 'weights', [], 'biases', [], 'C', {}, 'M', {}, 'v', {}); % define empty structure for dense layers
K = repmat(strct,1,layers - 1); % create array of structures for dense layers

% Load MNIST dataset
X_test = load("X_test_resized_MNIST_FPGA.mat");

% Build Structures of Layers
for i = 1:layers
    if i < layers % conv layers
        % Layer Name
        N(i).name = strcat("conv2d_",num2str(i-1));
        % Load Biases
        tmp_var = strcat("conv2d_",num2str(i-1),"_bias_mnist_fpga.mat");
        tmp_strct = load(tmp_var);
        N(i).biases = tmp_strct.(tmp_strct.label);
        % Load Weights
        tmp_var = strcat("conv2d_",num2str(i-1),"_weights_mnist_fpga.mat");
        tmp_strct = load(tmp_var);
        N(i).weights = tmp_strct.(tmp_strct.label);
        % Network Parameters
        if i == 1
            N(i).HW = size(X_test.X_test_resized_MNIST_FPGA,2);
        else
            if is_pooling(i-1) == 1
                N(i).HW = N(i-1).HW/2;
            else
                N(i).HW = N(i-1).HW;
            end
        end
        N(i).EF = N(i).HW;
        N(i).r = X/N(i).EF; %X/E
        N(i).M = size(N(i).weights,1);
        N(i).RS = size(N(i).weights,2);
        N(i).C = size(N(i).weights,4);
        N(i).M_div_pt = N(i).M/p(i);
        N(i).C_div_r = N(i).C/N(i).r;
    else %last layer is dense layer (I use K(1) cos there is only one dense layer at the end, but shall be changed.
        % Layer Name
        K(1).name = strcat("dense");
        % Load Biases
        tmp_strct = load("dense_bias_mnist_fpga.mat");
        K(1).biases = tmp_strct.(tmp_strct.label);
        % Load Weights
        tmp_strct = load("dense_weights_mnist_fpga.mat");
        K(1).weights = tmp_strct.(tmp_strct.label);
        % Network Parameters
        K(1).M = size(K(1).weights,1);
        K(1).C = size(K(1).weights,2);
        K(1).v = 32; % temporal mapping of weights/biases within each PE for each pass.
    end
end

% Quantization Parameters
ws_bias = 16;
fl_bias = 13;
ws_weight = 10;
fl_weight = 4;
ws_act = 16;
fl_act = 10;

% ******** Memories ********
% **** IFM BRAM ****
IFM_BRAM_WORDLENGTH = 32;
% All activations fit in memory.
% No need of keeping track of addresses in BRAM since
% activations are stored continuosly H-wise, W-wise and C-wise.
% **** WB BRAM ****
ws_cfg = 8;
params_per_layer = 12; % not including no of layers
WB_BRAM_WORDLENGTH = 32;
EOM_WB_BRAM = (max([N.C])*max([N.M])*max([N.RS])*max([N.RS])/floor((WB_BRAM_WORDLENGTH/ws_weight))+(max([N.M]))/(WB_BRAM_WORDLENGTH/ws_bias)+(layers - 1)*((params_per_layer)/(WB_BRAM_WORDLENGTH/ws_cfg)) + 1);
ADDR_CFG = (max([N.C])*max([N.M])*max([N.RS])*max([N.RS])/floor((WB_BRAM_WORDLENGTH/ws_weight))+(max([N.M]))/(WB_BRAM_WORDLENGTH/ws_bias)); % First Address of the reserved space for config. parameters.
% **** OFMAP SRAM ****
%  Not initialized.

% Address counters
wb_addr_cnt = 0;
act_addr_cnt = 0;

word = '';
% **************************


%% Configuration Parameters to be loaded on WB SRAM
param_array = zeros(layers - 1, params_per_layer);
for i = 1:layers - 1  % only conv. layers
    % M
    param_array(i,1) = N(i).M;
    % C
    param_array(i,2) = N(i).C;
    % HW
    param_array(i,3) = N(i).HW;
    % HW_p
    padding = (-1+N(i).RS)/2;
    param_array(i,4) = N(i).HW + 2*padding;
    % RS
    param_array(i,5) = N(i).RS;
    % EF
    param_array(i,6) = N(i).EF;
    % r
    param_array(i,7) = N(i).r; %X/E
    % p
    param_array(i,8) = p(i);
    % M_div_pt
    param_array(i,9) = N(i).M/p(i);
    % EF_log_2
    param_array(i,10) = log2(N(i).EF);
    % r_log_2
    param_array(i,11) = log2(N(i).r);
    % is_pooling
    param_array(i,12) = is_pooling(i);
end
    
%% .coe files
fid = [];
% Create .coe files for WB BRAM
fid(1) = fopen("coe_WB_BRAM.coe", 'w');
% Create .coe file for IFM BRAM
fid(2) = fopen('coe_IFM_BRAM.coe', 'w');
% Create .coe file for External BRAM (will allocate weights + biases + cfg. params + activations).
fid(3) = fopen('coe_external_BRAM.coe', 'w');
fprintf(fid(3), 'memory_initialization_radix=2;\n');
fprintf(fid(3), 'memory_initialization_vector= ');

% Create files for allocating weights and biases of FC layer (in floating by the moment)
fid(4) = fopen("weights_FC_layer_MNIST_FPGA.txt", 'w');
fid(5) = fopen("biases_FC_layer_MNIST_FPGA.txt", 'w');



%% Write Weights
weights_per_word = floor(WB_BRAM_WORDLENGTH/ws_weight);
weight_cnt = 0;
zeroes_weights = erase(num2str(zeros(1,(WB_BRAM_WORDLENGTH - ws_weight*weights_per_word)))," ");
fprintf(fid(1), 'memory_initialization_radix=2;\n');
fprintf(fid(1), 'memory_initialization_vector= ');
for i = 1:(layers - 1) % -1 because last layer (FC) is not implemented
    tmp_weights_conv_fi = fi(zeros(N(i).RS, p(i) , N(i).RS, N(i).r, N(i).M_div_pt, N(i).C_div_r), 1, ws_weight, fl_weight);
    for c = 1 : N(i).r : N(i).C - N(i).r + 1
        for m = 1 : p(i) : N(i).M - p(i) + 1
            for rc = c : 1 : c + N(i).r - 1
                for rp = 1 : 1 : N(i).RS
                    for pm = m : 1 : m + p(i) - 1
                        for s = 1 : 1 : N(i).RS
                            weight_cnt = weight_cnt + 1;
                            tmp_weights_conv_fi(s, pm - m + 1, rp, rc - c + 1, ceil(m/p(i)), ceil(c/N(i).r)) = fi(N(i).weights(pm, rp, s, rc), 1, ws_weight, fl_weight);
                            tmp_fi = tmp_weights_conv_fi(s, pm - m + 1, rp, rc - c + 1, ceil(m/p(i)), ceil(c/N(i).r));
                            word = append(word, tmp_fi.bin);
                            if (weight_cnt == weights_per_word)
                                word = append(zeroes_weights, word);
                                fprintf(fid(1), '%s\n', word); % write bin value + new line on file
                                fprintf(fid(3), '%s\n', word); % External BRAM
                                weight_cnt = 0;
                                word = '';
                                wb_addr_cnt = wb_addr_cnt + 1;
                            end
                        end
                    end
                end
            end
        end
    end
end

%% Fill space in between weights and biases with zeroes (if necessary)
biases_per_word = WB_BRAM_WORDLENGTH/ws_bias;
if ((ADDR_CFG - sum([N.M])/biases_per_word) > wb_addr_cnt)
    fprintf(fid(1), '%s\n', erase(num2str(zeros(1,32))," "));
    fprintf(fid(3), '%s\n', erase(num2str(zeros(1,32))," ")); % External BRAM
end

%% Write Biases
bias_cnt = 0;
for i = (layers - 1) : -1 : 1  % Skip FC layer (layer = 7)
    for mm =  N(i).M : -1 : 1
        bias_cnt = bias_cnt + 1;
        tmp_biases_fi(mm) = fi(N(i).biases(mm), 1, ws_bias, fl_bias);
        tmp_fi = tmp_biases_fi(mm);
        word = append(tmp_fi.bin, word);
        if (bias_cnt == biases_per_word)
            fprintf(fid(1), '%s\n', word);
            fprintf(fid(3), '%s\n', word); % External BRAM
            bias_cnt = 0;
            word = '';
            wb_addr_cnt = wb_addr_cnt + 1;
        end
    end
end

%% Write Config Parameters
cfg_per_word = WB_BRAM_WORDLENGTH/ws_cfg;
cfg_cnt = 0;

% --- Write # of layers on first position
word = append(word, fi((layers-1),0,ws_cfg,0).bin);
cfg_cnt = cfg_cnt + 1;
% ---
for i = 1 : 1 : (layers - 1)  % Skip FC layer (layer = 7)
    for j = 1 : 1 : params_per_layer
        cfg_cnt = cfg_cnt + 1;
        tmp_cfg_fi = fi(param_array(i,j),0,ws_cfg,0);
        word = append(word, tmp_cfg_fi.bin);
        if (cfg_cnt == cfg_per_word) || (i*j == (layers-1)*params_per_layer)
            if (i*j == (layers-1)*params_per_layer) % last address filled with zeroes
                word = strcat(word, fi(0,0,WB_BRAM_WORDLENGTH - size(tmp_cfg_fi.bin,2)).bin);
            end
            fprintf(fid(1), '%s\n', word);
            fprintf(fid(3), '%s\n', word); % External BRAM
            cfg_cnt = 0;
            word = '';
            wb_addr_cnt = wb_addr_cnt + 1;
        end
    end
end
fprintf(fid(1), ';');

% Close .coe WB BRAM
fclose(fid(1));

clear tmp_strct;
clear tmp_var;
clear tmp_weights_conv_fi;
clear tmp_weights_dense_fi;
clear tmp_biases_fi;
clear tmp_fi;

%% Write ifm
% Set image to fetch into .cde file
image = 2; % choose image to input
ifm = X_test.X_test_resized_MNIST_FPGA(image, :, :, :); % [W, H, C] -> [H, W, C]
clear X_test;

activations_per_word = IFM_BRAM_WORDLENGTH/ws_act;
act_cnt = 0;
fprintf(fid(2), 'memory_initialization_radix=2;\n');
fprintf(fid(2), 'memory_initialization_vector= ');
for ch = 1 : N(1).C
    for col = 1 : N(1).HW
        for row = 1 : N(1).HW
            act_cnt = act_cnt + 1;
            tmp_fi = fi(ifm(1, row, col, ch), 1, ws_act, fl_act);
            word = append(word, tmp_fi.bin);
            if (act_cnt == activations_per_word)
                fprintf(fid(2), '%s\n', word);
                fprintf(fid(3), '%s\n', word); % External BRAM
                word = '';
                act_cnt = 0;
                act_addr_cnt = act_addr_cnt + 1;
            end
        end
    end
end
fprintf(fid(2), ';');

% Close .coe IFM BRAM
fclose(fid(2));

% Close .coe External BRAM
fprintf(fid(3), ';');
fclose(fid(3));

clear tmp_fi;
clear word;

%% Write FC parameters
% I should rearrange data so that multiplication with the output of the max
% pooling is easy. Output of max.pool is column-wise, row-wise and channel
% wise.

% Weights in the dense layer are by detaulf, for each neuron, channel-wise,
% row-wise and column-wise.
noNeurons = K.M;
if (is_pooling(layers-1) == 1)
    EF_L = N(layers-1).EF/2;
else
    EF_L = N(layers-1).EF;
end
noChannels =  N(layers-1).M;

% weights
index = 0;
for i = 1:noNeurons
    for j = 1:noChannels % channels
        for k = 1:EF_L % rows
            for l = 1:EF_L % columns
                index = index + 1;
                tmp = fi(K.weights(i,(l-1)*(EF_L*noChannels) + (k-1)*(noChannels) + j),1,ws_weight,fl_weight).bin;
                fprintf(fid(4), '%s\n', tmp);
            end
        end
    end
    index = 0;
end

% biases
for i = 1:noNeurons
        tmp = fi(K.biases(i),1,ws_bias,fl_bias).bin;
        fprintf(fid(5), '%s\n', tmp);
end

fclose(fid(4));
fclose(fid(5));


%% testing
% 
% conv2d_2_weights = N(3).weights;
% 
% C = size(N(3).weights,4);
% M = size(N(3).weights,1);
% RS = size(N(3).weights,2);
% r = N(3).r;
% mdivp = M/p;
% C_div_r = C/r;
% 
% currentPass = 0;
% % j = 0;
% conv2d_2_weights_formatted_fi = fi(zeros(RS, p , RS, r, mdivp, C_div_r),1,16,13);
% 
% fid = fopen('Conv2d_Weights_coe.txt', 'w'); % create file to write in
% for c = 1 : r : C - r + 1
%     for m = 1 : p : M - p + 1
% %        currentPass = currentPass + 1;
% %        disp("Current Pass: " + currentPass);
%         for rc = c : 1 : c + r - 1
%             for rp = 1 : 1 : RS
%                 for pm = m : 1 : m + p - 1
%                     for s = 1 : 1 : RS
% %                        j = j + 1;
% %                        disp("j: " + j + "   c: " + c + "   m: " + m + "   rc: " + rc + "   r': " + rp + "   pm: " + pm + "   s: " + s);
%                         conv2d_2_weights_formatted_fi(s, pm - m + 1, rp, rc - c + 1, ceil(m/p), ceil(c/r)) = fi(conv2d_2_weights(pm, s, rp, rc), 1, ws_wb, fl_wb);
%                         tmp_fi = conv2d_2_weights_formatted_fi(s, pm - m + 1, rp, rc - c + 1, ceil(m/p), ceil(c/r));
%                         fprintf(fid, '%s\n', tmp_fi.bin); % write bin value + new line on file
%                     end
%                 end
%             end
% %            disp("--------------------------------------------------------------------");
%         end
%     end
% end
% fclose(fid); % close file