localparam logic [7:0] sour_mac [5:0] = {8'h06,8'h00,8'hAA,8'hBB,8'h0C,8'hDD};
//byte unsigned dest_mac [5:0] = {8'h80,8'hfa,8'h5b,8'h6e,8'h66,8'he3};
//0000   a8 a1 59 0d d8 a4
localparam logic [7:0] dest_mac [5:0] = {8'hA8,8'hA1,8'h59,8'h0D,8'hD8,8'hA4};

localparam logic [7:0] ipv4_type [1:0] = {8'h08,8'h00};
localparam logic [7:0] head_p0 [1:0] = {8'h45, 8'h00};
localparam logic [15:0] total_len = 16'h0030;
localparam logic [15:0] ipv4_idf = 16'h0000;
localparam logic [7:0] ipv4_flg [1:0] = {8'h40, 8'h00};
localparam logic [7:0] ipv4_ttl = {8'h40};
localparam logic [7:0] ipv4_tcp = {8'h06};

localparam logic [7:0] ip_sour [3:0] = {8'd192,8'd168,8'd3,8'd2};
localparam logic [7:0] ip_dest [3:0] = {8'd192,8'd168,8'd3,8'd1};

localparam logic [15:0] port_sour = 16'd1234;
localparam logic [15:0] port_dest = 16'd5678;

localparam logic [7:0] arp_type [1:0] = {8'h08,8'h06};
localparam logic [7:0] arp_hrd [1:0] = {8'h00,8'h01};
localparam logic [7:0] arp_size [1:0] = {8'h06,8'h04};
localparam logic [7:0] arp_op [1:0] = {8'h00,8'h01};


localparam rx_max_len = 1460;
localparam tx_max_len = 1460;
