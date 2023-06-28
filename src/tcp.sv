module tcp
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
    parameter bit [31:0] frame_buf_size = 128,

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

    output logic [63:0] tx_net_data,
    output logic tx_net_valid,
    input tx_net_ready,
    output logic [2:0] tx_net_cnt,
    output logic tx_net_fin,

    input [63:0] rx_net_data,
    input rx_net_valid,
    input [2:0] rx_net_cnt,
    output logic rx_net_ready,
    input rx_net_fin
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)begin
        con_ready <= 0;
    end else begin
        
    end    
end


tcp_input_control #(
    .ip(ip), .remote_ip(remote_ip), .mac(mac), .remote_mac(remote_mac), .port(port), .remote_port(remote_port),
    .resend_interval(resend_interval), .recon_interval(recon_interval), .tx_buf_size(tx_buf_size), .frame_buf_size(frame_buf_size),
    .HB(HB), .HB_interval(HB_interval), .jumbo(jumbo), .download(download), .rx_buf_size(rx_buf_size)
) tcp_input_control (
    .clk(clk), .rst_n(rst_n), .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready), .tx_cnt(tx_cnt)
);


shortint tx_payload_size;
logic [11:0] tx_flag;
logic tx_trg;
logic tx_ack;

tx_control #(
    .ip(ip), .remote_ip(remote_ip), .mac(mac), .remote_mac(remote_mac), .port(port), .remote_port(remote_port),
    .resend_interval(resend_interval), .recon_interval(recon_interval), .tx_buf_size(tx_buf_size), .frame_buf_size(frame_buf_size),
    .HB(HB), .HB_interval(HB_interval), .jumbo(jumbo), .download(download), .rx_buf_size(rx_buf_size)
) tx_control (
    .clk(clk), .rst_n(rst_n), .tx_payload_size(tx_payload_size), .tx_flag(tx_flag), .tx_trg(tx_trg),
    .tx_ack(tx_ack), .con_ready(con_ready), .phy_ready(phy_ready)
);



tcp_packet_generator #(
    .ip(ip), .remote_ip(remote_ip), .mac(mac), .remote_mac(remote_mac), .port(port), .remote_port(remote_port),
    .resend_interval(resend_interval), .recon_interval(recon_interval), .tx_buf_size(tx_buf_size), .frame_buf_size(frame_buf_size),
    .HB(HB), .HB_interval(HB_interval), .jumbo(jumbo), .download(download), .rx_buf_size(rx_buf_size)
) tcp_packet_generator (
    .clk(clk), .rst_n(rst_n), .tx_trg(tx_trg), .tx_ack(tx_ack), .tx_payload_size(tx_payload_size), .tx_flag(tx_flag),
    .tx_net_data(tx_net_data), .tx_net_valid(tx_net_valid), .tx_net_ready(tx_net_ready), .tx_net_cnt(tx_net_cnt), .tx_net_fin(tx_net_fin)
);

endmodule

module tcp_input_control #(
    parameter bit [31:0] ip, parameter bit [31:0] remote_ip, parameter bit [47:0] mac, parameter bit [47:0] remote_mac,
    parameter bit [15:0] port, parameter bit [15:0] remote_port, parameter bit [31:0] resend_interval, parameter bit [31:0] recon_interval,
    parameter bit [31:0] tx_buf_size, parameter bit [31:0] frame_buf_size, parameter bit HB, parameter bit [31:0] HB_interval,
    parameter bit jumbo, parameter bit download, parameter bit [31:0] rx_buf_size
)(
    input clk,
    input rst_n,

    input [63:0] tx_data,
    input tx_valid,
    output logic tx_ready,
    input [2:0] tx_cnt
);

logic [63:0] tx_data_mem [tx_buf_size/8-1:0];
//16 bit begin address, 16 bit length, 32 bit sum
logic [63:0] tx_frame_mem [frame_buf_size-1:0];

logic [63:0] tx_data_mem_out;
logic [63:0] tx_data_mem_in;

logic [63:0] tx_frame_mem_out;
logic [63:0] tx_frame_mem_in;

int tx_data_mem_in_ptr;
int tx_frame_mem_in_ptr;

logic tx_data_mem_wr;
logic tx_frame_mem_wr;

logic tx_data_mem_not_full;
logic tx_frame_mem_not_full;

int tx_data_mem_write_ptr;
int tx_data_mem_final_ptr;
//remain space is (size + final_ptr - write_ptr)%size
int tx_data_mem_read_ptr;

int tx_frame_mem_write_ptr;
int tx_frame_mem_final_ptr;
int tx_frame_mem_read_ptr;

int tx_data_mem_remain;
int tx_frame_mem_remain;

logic [31:0] tx_input_summer;

logic local_tx_valid;

always_comb begin
    tx_data_mem_remain = (tx_buf_size/8 + tx_data_mem_final_ptr - tx_data_mem_write_ptr - 1)%(tx_buf_size/8);
    tx_frame_mem_remain = (frame_buf_size + tx_frame_mem_final_ptr - tx_frame_mem_write_ptr - 1)%frame_buf_size;

    tx_data_mem_not_full = tx_data_mem_remain > 8 || ((tx_data_mem_remain > (jumbo?1200:200))&& (!tx_valid || tx_cnt != 7));
    tx_frame_mem_not_full = tx_frame_mem_remain > 2;

    tx_ready = tx_data_mem_not_full && tx_frame_mem_not_full;
    local_tx_valid = tx_valid && tx_ready;
end

shortint tx_length_cnt;
shortint begin_write_ptr;

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        tx_data_mem_wr <= 0;
        tx_frame_mem_wr <= 0;

        tx_data_mem_write_ptr <= 0;
        tx_frame_mem_write_ptr <= 0;
        tx_input_summer <= 0;
        tx_length_cnt <= 0;
        begin_write_ptr <= 0;
    end else begin
        tx_data_mem_wr <= 0;
        tx_frame_mem_wr <= 0;

        if(local_tx_valid)begin
            if(tx_length_cnt == 0)begin_write_ptr <= tx_data_mem_write_ptr;

            tx_data_mem_wr <= 1;
            tx_data_mem_in <= tx_data;
            tx_data_mem_in_ptr <= tx_data_mem_write_ptr;
            tx_data_mem_write_ptr <= tx_data_mem_write_ptr + 1;

            tx_input_summer <= tx_input_summer + tx_data[63:48] + tx_data[47:32] + tx_data[31:16] + tx_data[15:0];
            tx_length_cnt <= tx_length_cnt + 8;

            //finish a frame
            if(tx_cnt != 7 || (!jumbo && tx_length_cnt >= 1448 - 8) || (jumbo && tx_length_cnt >= 8960 - 8))begin
                tx_frame_mem_in <= {begin_write_ptr, tx_length_cnt + tx_cnt + 1, 
                    tx_input_summer + tx_data[63:48] + tx_data[47:32] + tx_data[31:16] + tx_data[15:0]};
                tx_frame_mem_in_ptr <= tx_frame_mem_write_ptr;
                tx_frame_mem_wr <= 1;
                tx_frame_mem_write_ptr <= tx_frame_mem_write_ptr + 1;

                tx_input_summer <= 0;
                tx_length_cnt <= 0;
            end
        end else begin
            if(tx_length_cnt != 0)begin
                tx_frame_mem_in <= {begin_write_ptr, tx_length_cnt, tx_input_summer};
                tx_frame_mem_in_ptr <= tx_frame_mem_write_ptr;
                tx_frame_mem_wr <= 1;
                tx_frame_mem_write_ptr <= tx_frame_mem_write_ptr + 1;

                tx_input_summer <= 0;
                tx_length_cnt <= 0;
            end
        end
    end
end

always_ff@(posedge clk)begin
    if(tx_data_mem_wr)tx_data_mem[tx_data_mem_in_ptr] <= tx_data_mem_in;
    if(tx_frame_mem_wr)tx_frame_mem[tx_frame_mem_in_ptr] <= tx_frame_mem_in;

    tx_data_mem_out <= tx_data_mem[tx_data_mem_read_ptr];
    tx_frame_mem_out <= tx_frame_mem[tx_frame_mem_read_ptr];
end

endmodule


module tx_control #(
    parameter bit [31:0] ip, parameter bit [31:0] remote_ip, parameter bit [47:0] mac, parameter bit [47:0] remote_mac,
    parameter bit [15:0] port, parameter bit [15:0] remote_port, parameter bit [31:0] resend_interval, parameter bit [31:0] recon_interval,
    parameter bit [31:0] tx_buf_size, parameter bit [31:0] frame_buf_size, parameter bit HB, parameter bit [31:0] HB_interval,
    parameter bit jumbo, parameter bit download, parameter bit [31:0] rx_buf_size
)(
    input clk,
    input rst_n,

    output shortint tx_payload_size,
    output logic [11:0] tx_flag,
    output logic tx_trg,
    input tx_ack,
    input con_ready,
    input phy_ready
);

/* TX Control


If phy_ready but connection_state is not 1, then send RST and SYN packet

*/

int recon_cnt;
byte con_sta;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        tx_trg <= 0;
        recon_cnt <= 0;
    end else begin
        if(tx_ack)tx_trg <= 1'b0;
        if(recon_cnt != 0)recon_cnt <= recon_cnt - 1;
        if(con_ready)recon_cnt <= recon_interval;


        if(!tx_trg || tx_ack)begin
            if(phy_ready && !con_ready)begin
                case(con_sta)
                0:begin
                    if(recon_cnt == 0)begin
                        tx_trg <= 1;
                        tx_payload_size <= 0;
                        //RST
                        tx_flag <= 12'h004;
                        recon_cnt <= recon_interval;
                        con_sta <= 1;
                    end
                end
                1:begin
                    tx_trg <= 1;
                    tx_payload_size <= 0;
                    //SYN
                    tx_flag <= 12'h002;
                    con_sta <= 0;
                end
                endcase
                
            end
        end

    end            
end

endmodule




module tcp_packet_generator #(
    parameter bit [31:0] ip, parameter bit [31:0] remote_ip, parameter bit [47:0] mac, parameter bit [47:0] remote_mac,
    parameter bit [15:0] port, parameter bit [15:0] remote_port, parameter bit [31:0] resend_interval, parameter bit [31:0] recon_interval,
    parameter bit [31:0] tx_buf_size, parameter bit [31:0] frame_buf_size, parameter bit HB, parameter bit [31:0] HB_interval,
    parameter bit jumbo, parameter bit download, parameter bit [31:0] rx_buf_size
)(
    input clk,
    input rst_n,

    input tx_trg,
    output logic tx_ack,

    input shortint tx_payload_size,
    input logic [11:0] tx_flag,

    output logic [63:0] tx_net_data,
    output logic tx_net_valid,
    input tx_net_ready,
    output logic [2:0] tx_net_cnt,
    output logic tx_net_fin


);

/* TX packet generator

generate TCP header and transmit the data
8 byte data each time, this code is suitable for 10Gbps ethernet


tx_packet_sta
0:  wait for tx_trg | mac part 0
1:  mac part 1, ipv4, header length, type of service
2:  total length, identification, fragment, ttl, protocol
3:  checksum, source ip, dst ip 0
4:  dst ip 1, src port, dst port, seq 0
5:  seq 1, ack, header length, flag
6:  window, checksum, urgent pointer, XX(2BYTE)
*/

logic [31:0] sequence_number;
logic [31:0] acknowledgement_number;

shortint tx_packet_sta;
logic [15:0] ipv4_identification;

shortint tx_packet_local_tx_payload_size;
logic [11:0] tx_packet_local_tx_flag;


// Checksum module for tcp head
// the undetermined value is only id and length

//it's determined
logic [19:0] pre_tcp_head_checksum_step0 = 16'h4500 + 16'h4000 + 16'h4006 + ip[31:16] + ip[15:0] + remote_ip[31:16] + remote_ip[15:0] + 16'h0028;
logic [19:0] pre_tcp_head_checksum_step1 = pre_tcp_head_checksum_step0[15:0] + pre_tcp_head_checksum_step0[19:16];
logic [15:0] pre_tcp_head_checksum_step2 = pre_tcp_head_checksum_step1[15:0] + pre_tcp_head_checksum_step1[19:16];

logic [19:0] tcp_head_checksum_step0;
logic [19:0] tcp_head_checksum_step1;
logic [15:0] tcp_head_checksum_step2;

logic [15:0] tcp_head_checksum;

logic [15:0] local_tcp_head_checksum;

always_comb begin
    tcp_head_checksum_step0 = pre_tcp_head_checksum_step2 + ipv4_identification + tx_packet_local_tx_payload_size;
    tcp_head_checksum_step1 = tcp_head_checksum_step0[15:0] + tcp_head_checksum_step0[19:16];
    tcp_head_checksum_step2 = tcp_head_checksum_step1[15:0] + tcp_head_checksum_step1[19:16];

    tcp_head_checksum = ~tcp_head_checksum_step2;
end

//For tcp head, the calculation is different from ip head
// the undetermined value is 
// sequence number, acknowledgement number, flags, window, data, part of length, header len
logic [19:0] pre_tcp_checksum_step0 = port + remote_port + ip[31:16] + ip[15:0] + remote_ip[31:16] + remote_ip[15:0] + 16'h0006 + 16'h0014 + 16'h5000;
logic [19:0] pre_tcp_checksum_step1 = pre_tcp_checksum_step0[15:0] + pre_tcp_checksum_step0[19:16];
logic [15:0] pre_tcp_checksum_step2 = pre_tcp_checksum_step1[15:0] + pre_tcp_checksum_step1[19:16];

logic [19:0] tcp_checksum_step0;
logic [19:0] tcp_checksum_step1;
logic [15:0] tcp_checksum_step2;

logic [15:0] tcp_checksum;

logic [15:0] local_tcp_checksum;

always_comb begin
    //TBD window size
    //TBD data checksum
    tcp_checksum_step0 = pre_tcp_checksum_step2 + sequence_number[31:16] + sequence_number[15:0] + acknowledgement_number[31:16] + acknowledgement_number[15:0] + tx_packet_local_tx_flag + tx_packet_local_tx_payload_size + 16'h0200 + 16'h0000;
    tcp_checksum_step1 = tcp_checksum_step0[15:0] + tcp_checksum_step0[19:16];
    tcp_checksum_step2 = tcp_checksum_step1[15:0] + tcp_checksum_step1[19:16];

    tcp_checksum = ~tcp_checksum_step2;
end


always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n == 0)begin
        tx_ack <= 0;
        tx_net_valid <= 0;
        tx_net_fin <= 0;

        tx_packet_sta <= 0;
    end else begin
        tx_ack <= 1'b0;
        if(tx_net_ready)begin
            tx_net_valid <= 1'b0;
            tx_net_fin <= 1'b0;
        end

        if(!tx_net_valid || tx_net_ready)begin
            case(tx_packet_sta)
            0:begin
                if(tx_trg)begin 
                    tx_packet_local_tx_payload_size <= tx_payload_size;
                    tx_packet_local_tx_flag <= tx_flag;

                    tx_net_valid <= 1;
                    tx_net_cnt <= 7;
                    tx_net_data <= {mac, remote_mac[47:32]};
                    tx_packet_sta <= 1;
                    tx_ack <= 1;
                end
            end
            1:begin
                tx_net_valid <= 1;
                tx_net_data <= {remote_mac[31:0], 8'h08, 8'h00, 8'h45, 8'h00};
                tx_packet_sta <= 2;
            end
            2:begin
                //multiple clock path, 2 x clk
                local_tcp_head_checksum <= tcp_head_checksum;
                local_tcp_checksum <= tcp_checksum;

                tx_net_valid <= 1;
                /*
                    when no payload, total length is 40
                    when payload, total length is 40 + payload size
                */
                tx_net_data <= {16'h0028 + tx_packet_local_tx_payload_size, ipv4_identification, 16'h4000, 8'h40, 8'h06};
                ipv4_identification <= ipv4_identification + 1;
                tx_packet_sta <= 3;
            end
            3:begin
                tx_net_valid <= 1;
                tx_net_data <= {local_tcp_head_checksum, ip[31:0], remote_ip[31:16]};
                tx_packet_sta <= 4;
            end
            4:begin
                tx_net_valid <= 1;
                tx_net_data <= {remote_ip[15:0], port, remote_port, sequence_number[31:16]};
                tx_packet_sta <= 5;
            end
            5:begin
                tx_net_valid <= 1;
                tx_net_data <= {sequence_number[15:0], acknowledgement_number, 4'd5, tx_packet_local_tx_flag};

                sequence_number <= sequence_number + tx_packet_local_tx_payload_size + tx_packet_local_tx_flag[0]?1:0 + tx_packet_local_tx_flag[1]?1:0;

                tx_packet_sta <= 6;
            end
            6:begin
                tx_net_valid <= 1;
                tx_net_cnt <= 5;
                //window, checksum, urgent pointer, XX(2BYTE)
                //TBD
                //window
                /*
                    window is fixed to 512 Bytes yet, but when rx is implemented, it will be changed
                    when rx is disabled, the received message will be discarded
                */

                //TBD XX 2BYTE
                tx_net_data <= {16'h0200, local_tcp_checksum, 16'h0000, 16'h0000};

                if(tx_packet_local_tx_payload_size != 0)begin
                    tx_packet_sta <= 7;
                end else begin
                    tx_packet_sta <= 0;
                    tx_net_fin <= 1;
                end
            end
            endcase
        end
        
    end
end

endmodule