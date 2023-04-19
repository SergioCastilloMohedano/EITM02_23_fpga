% this function includes indexes for upsampling in backprop (only when max pooling)
function [A_w,R,C] = pool2d(A, kernel_size, stride, padding, pool_mode)
    % Padding
    A = padarray(A, [padding padding], 0, 'both');

    % Window view of A
    output_shape_1 = fix((size(A,1) - kernel_size + 2*padding)/stride) + 1;
    output_shape_2 = fix((size(A,2) - kernel_size + 2*padding)/stride) + 1;
    
    A_w = zeros(output_shape_1, output_shape_2);
    R = zeros(output_shape_1, output_shape_2);
    C = zeros(output_shape_1, output_shape_2);
    
    % If A Matrix is odd, crop last row and/or column
    if  (rem(size(A,1),2) ~= 0)
        A = A(1:size(A,1)-1,:);
    end
    if  (rem(size(A,2),2) ~= 0)
        A = A(:,1:size(A,2)-1);
    end    
    
    row_w = size(A_w,1);
    col_w = size(A_w,2);
    str_row = 0;
    str_col = 0;

    if (pool_mode ~= "max") && (pool_mode ~= "avg")
        disp("ERROR: 'pool_mode' parameter not specified correctly.");
    else
        for row = 1:row_w
            for col = 1:col_w
                A_local = A(row+str_row:row+kernel_size+str_row-1, col+str_col:col+kernel_size+str_col-1);
                if pool_mode == "max"
                    [R_local,C_local] = find(A_local==max(A_local, [], 'all')); % local index of the max value of the 2x2 snippet of the matrix
                    % If there are several values on the snippet with the same max value, just take the first index found
                    if(size(R_local,1) > 1)
                        R_local = R_local(1);
                        C_local = C_local(1);
                    end
                    R_tmp = R_local+row+str_row-1; % global row index of the max value of the snippet on the A matrix 
                    C_tmp = C_local+col+str_col-1; % global row col of the max value of the snippet on the A matrix
                    R(row, col) = R_tmp;
                    C(row, col) = C_tmp;
                    A_w(row, col) = A(R_tmp,C_tmp);
                elseif pool_mode == "avg"
                    A_w(row, col) = mean(A(row+str_row:row+kernel_size+str_row-1, col+str_col:col+kernel_size+str_col-1), 'all');
                end
                if ((col+kernel_size+str_col-1) >= min(size(A)))
                    str_col = 0;
                else
                    str_col = str_col + stride - 1;
                end
            end
            if ((row+kernel_size+str_row-1) >= min(size(A)))
                str_row = 0;
            else
                str_row = str_row + stride - 1;
            end
        end
    end
end