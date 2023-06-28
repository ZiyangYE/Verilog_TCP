`timescale 1ns/1ns 

interface rmii(
    input clk50m, rx_crs,
    output mdc, txen,
    inout mdio,
    output [1:0] txd,
    input [1:0] rxd
);
endinterface //rmii

module tcp_tb;

logic clk;
logic rst_n;
logic phy_ready;
logic con_ready;
logic [63:0] tx_data;
logic tx_valid;
logic tx_ready;
logic [2:0] tx_cnt;
logic [63:0] rx_data;
logic rx_valid;
logic rx_ready;
logic [2:0] rx_cnt;
logic [63:0] tx_net_data;
logic tx_net_valid;
logic tx_net_ready;
logic [2:0] tx_net_cnt;
logic tx_net_fin;
logic [63:0] rx_net_data;
logic rx_net_valid;
logic [2:0] rx_net_cnt;
logic rx_net_ready;
logic rx_net_fin;


initial begin
    rst_n = 1'b0;
    clk = 1'b0;

    #5 rst_n = 1'b1;
    #5;
    forever #2 clk = ~clk;
end

initial begin
    tx_valid = 1'b0;
    tx_data = 64'h0000000000000000;
    tx_cnt = 3'd0;

    #4;
    force mac_inst.phy_config.phy_ready = 1'b1;

    #80;
    force tcp_inst.con_ready = 1'b1;

    
    #12;
    tx_valid = 1'b1;
    tx_data = 64'h1122334455667788;
    tx_cnt = 3'd7;
    #20;
    tx_data = 64'h6677880000000000;
    tx_cnt = 3'd2;
    #4;
    tx_data = 64'h6677880000000000;
    tx_cnt = 3'd7;
    #4;
    tx_valid = 1'b0;
    
end

initial begin

    force tcp_inst.tcp_packet_generator.sequence_number = 32'd0;
    force tcp_inst.tcp_packet_generator.acknowledgement_number = 32'd0;
    force tcp_inst.tcp_packet_generator.ipv4_identification = 16'd0;

    release tcp_inst.tcp_packet_generator.sequence_number;
    release tcp_inst.tcp_packet_generator.acknowledgement_number;
    release tcp_inst.tcp_packet_generator.ipv4_identification;
end

tcp #(
    //.ip(32'hC0A802F0),
    //.remote_ip(32'hC0A802F1),
    .mac(48'h0600AABBCCDD),
    .remote_mac(48'h0600AABBCCDE),
    //.port(16'h3039),
    //.remote_port(16'h5B40),
    //.resend_interval(32'h3B9ACA00),
    //.recon_interval(32'h5F5E100),
    .tx_buf_size(32'd1024),
    .frame_buf_size(32'd16)
    //.HB(1),
    //.HB_interval(32'h5F5E100),
    //.jumbo(0),
    //.download(0),
    //.rx_buf_size(32'h4000)
) tcp_inst (
    .clk(clk),
    .rst_n(rst_n),
    .phy_ready(phy_ready),
    .con_ready(con_ready),
    .tx_data(tx_data),
    .tx_valid(tx_valid),
    .tx_ready(tx_ready),
    .tx_cnt(tx_cnt),
    .rx_data(rx_data),
    .rx_valid(rx_valid),
    .rx_ready(rx_ready),
    .rx_cnt(rx_cnt),
    .tx_net_data(tx_net_data),
    .tx_net_valid(tx_net_valid),
    .tx_net_ready(tx_net_ready),
    .tx_net_cnt(tx_net_cnt),
    .tx_net_fin(tx_net_fin),
    .rx_net_data(rx_net_data),
    .rx_net_valid(rx_net_valid),
    .rx_net_cnt(rx_net_cnt),
    .rx_net_ready(rx_net_ready),
    .rx_net_fin(rx_net_fin)
);


logic clk50m;
logic rx_crs;
logic mdc;
logic txen;
logic mdio;
logic [1:0] txd;
logic [1:0] rxd;

rmii rmii_local (
    .clk50m(clk50m), 
    .rx_crs(rx_crs),
    .mdc(mdc), 
    .txen(txen), 
    .txd(txd), 
    .rxd(rxd)
);


mac mac_inst(
    .clk(clk),
    .rst_n(rst_n),
    .tx_net_data(tx_net_data),
    .tx_net_valid(tx_net_valid),
    .tx_net_ready(tx_net_ready),
    .tx_net_cnt(tx_net_cnt),
    .tx_net_fin(tx_net_fin),
    .rx_net_data(rx_net_data),
    .rx_net_valid(rx_net_valid),
    .rx_net_ready(rx_net_ready),
    .rx_net_cnt(rx_net_cnt),
    .rx_net_fin(rx_net_fin),
    .phy_ready(phy_ready),
    .netrmii(rmii_local)
);


endmodule