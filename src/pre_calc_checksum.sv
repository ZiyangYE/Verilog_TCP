function shortint unsigned pre_calc_checksum_ipv4(input byte unsigned header_bytes[13:0]);
    bit [23:0] sum; //
    bit [15:0] word;
    sum = 0;
    
    // Combine every two bytes into one word and sum all the words
    for (int i = 0; i < 14; i += 2) begin
        word = {header_bytes[i+1], header_bytes[i]}; // combine two bytes to form one word
        sum = sum + {8'b0, word}; // prevent overflow
    end
    if(sum[23:16] != 0) begin
        sum = sum[15:0] + sum[23:16]; // add the carry out
    end
    if(sum[23:16] != 0) begin
        sum = sum[15:0] + sum[23:16]; // add the carry out
    end
    
    // One's complement of the sum
    return sum[15:0];
endfunction

function shortint unsigned pre_calc_checksum_tcp_0(input byte unsigned header_bytes[21:0]);
    bit [23:0] sum; //
    bit [15:0] word;
    sum = 0;
    
    // Combine every two bytes into one word and sum all the words
    for (int i = 0; i < 22; i += 2) begin
        word = {header_bytes[i+1], header_bytes[i]}; // combine two bytes to form one word
        sum = sum + {8'b0, word}; // prevent overflow
    end
    if(sum[23:16] != 0) begin
        sum = sum[15:0] + sum[23:16]; // add the carry out
    end
    if(sum[23:16] != 0) begin
        sum = sum[15:0] + sum[23:16]; // add the carry out
    end
    
    // One's complement of the sum
    return ~sum[15:0];
endfunction

function shortint unsigned pre_calc_checksum_tcp_1(input byte unsigned header_bytes[13:0]);
    bit [23:0] sum; //
    bit [15:0] word;
    sum = 0;
    
    // Combine every two bytes into one word and sum all the words
    for (int i = 0; i < 14; i += 2) begin
        word = {header_bytes[i+1], header_bytes[i]}; // combine two bytes to form one word
        sum = sum + {8'b0, word}; // prevent overflow
    end
    if(sum[23:16] != 0) begin
        sum = sum[15:0] + sum[23:16]; // add the carry out
    end
    if(sum[23:16] != 0) begin
        sum = sum[15:0] + sum[23:16]; // add the carry out
    end
    
    // One's complement of the sum
    return ~sum[15:0];
endfunction