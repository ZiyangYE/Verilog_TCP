`timescale 1ns/1ns 

/*
module udp
#(
    parameter bit [31:0] ip = {8'd192, 8'd168, 8'd2, 8'd240},
    parameter bit [31:0] remote_ip = {8'd192, 8'd168, 8'd2, 8'd241},

    parameter bit [47:0] mac = {8'h06, 8'h00, 8'hAA, 8'hBB, 8'hCC, 8'hDD},
    parameter bit [47:0] remote_mac = {8'h06, 8'h00, 8'hAA, 8'hBB, 8'hCC, 8'hDE},

    parameter bit [15:0] port = 12345,
    parameter bit [15:0] remote_port = 23456,

    parameter bit [31:0] resend_interval = 1000000,
    parameter bit [31:0] recon_interval = 100000000,

    parameter bit [31:0] tx_buf_size = 16384,

    parameter bit HB = 1,
    parameter bit [31:0] HB_interval = 100000000,

    parameter bit jumbo = 0,

    parameter bit download = 0,

    parameter bit [31:0] rx_buf_size = 1024
)(
    input clk,
    input rst_n,

    input phy_ready,
    output logic con_ready,

    input [63:0] tx_data,
    input tx_valid,
    output logic tx_ready,
    input [2:0] tx_cnt,

    output [63:0] rx_data,
    output logic rx_valid,
    input rx_ready,
    output [2:0] rx_cnt,

    output [63:0] tx_net_data,
    output logic tx_net_valid,
    input tx_net_ready,
    output [2:0] tx_net_cnt,
    output tx_net_fin,

    input [63:0] rx_net_data,
    input rx_net_valid,
    input [2:0] rx_net_cnt,
    output logic rx_net_ready,
    input rx_net_fin
);
*/

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
    forever #10 clk = ~clk;
end

initial begin
    #20;
    phy_ready = 1'b1;
end

initial begin
    tx_net_ready = 1'b1;

    tcp_inst.sequence_number = 32'd0;
    tcp_inst.acknowledgement_number = 32'd0;
    tcp_inst.ipv4_identification = 16'd0;
end

tcp #(
    //.ip(32'hC0A802F0),
    //.remote_ip(32'hC0A802F1),
    .mac(48'h0600AABBCCDD),
    .remote_mac(48'h0600AABBCCDE)
    //.port(16'h3039),
    //.remote_port(16'h5B40),
    //.resend_interval(32'h3B9ACA00),
    //.recon_interval(32'h5F5E100),
    //.tx_buf_size(32'h4000),
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



endmodule