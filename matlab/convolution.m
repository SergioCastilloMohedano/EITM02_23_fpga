
function [results] = convolution(mat, fil, stride, padding)
    global mac_count
    if (padding > 0)
        mat_pad = padarray(mat, [padding padding 0], 0, 'both');
        p = padding;
    else
        mat_pad = mat;
        p = 0;
    end
    
    dim_result = int8(((size(mat,1) - size(fil,1)+(2*p))/stride)+1);

    filetered = zeros(size(fil,1),size(fil,2)); % slide matrix of size (k_row,k_col) of filter
    results_ch = zeros(dim_result, dim_result,size(fil,3)); % conv of each channel stored here
    results = zeros(dim_result); %convs of each channel added up together here

    for ch = 1:size(fil,3)
        for row = 1:dim_result
            for col = 1:dim_result
                spot = mat_pad(row:row+size(fil,1)-1, col:col+size(fil,2)-1, ch);
                for k_row = 1:size(fil,2)
                    for k_col = 1:size(fil,1)
                        filetered(k_row,k_col) = spot(k_row,k_col) * fil(k_row, k_col, ch);
                        mac_count = mac_count + 1;
                    end
                end

                result = sum(filetered, 'all');
                results_ch(row, col, ch) = result;
            end
        end
    end
    for i = 1:size(results_ch,3)
        results = results + results_ch(:,:,i);
    end
end
