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

/* Input data control


*/

logic [63:0] tx_data_fifo [tx_buf_size/8-1:0];
logic [47:0] tx_frame_fifo [frame_buf_size-1:0]


logic [63:0] tx_data_fifo_out;
logic [63:0] tx_data_fifo_in;
int tx_data_fifo_in_ptr;

logic tx_data_fifo_wr;
logic tx_data_fifo_rd;

logic tx_data_fifo_valid;
logic tx_data_fifo_ready;

int tx_fifo_write_ptr;
int tx_fifo_final_ptr;
//remain space is (tx_fifo_size + tx_fifo_final_ptr - tx_fifo_write_ptr)%tx_fifo_size
int tx_fifo_read_ptr;

//写入逻辑开始
//写入的数据暂存在这个reg里，并且写入fifo，在凑满8个之后，fifo才进位
logic [63:0] tx_fifo_input_interface;
byte tx_fifo_input_interface_cnt;

logic local_tx_valid = tx_valid && tx_ready;

logic [63:0] tx_fifo_input_shift;
logic [63:0] tx_fifo_interface_shift;

always_comb begin
    case(tx_fifo_input_interface_cnt)
    1:begin
        tx_fifo_input_shift = {tx_fifo_input_interface[63:56], tx_data[63:8]};
        tx_fifo_interface_shift = {tx_data[7:0], 56'hXXXXXXXXXXXXXX};
    end
    2:begin
        tx_fifo_input_shift = {tx_fifo_input_interface[63:48], tx_data[63:16]};
        tx_fifo_interface_shift = {tx_data[15:0], 48'hXXXXXXXXXXXX};
    end
    3:begin
        tx_fifo_input_shift = {tx_fifo_input_interface[63:40], tx_data[63:24]};
        tx_fifo_interface_shift = {tx_data[23:0], 40'hXXXXXXXXXX};
    end
    4:begin
        tx_fifo_input_shift = {tx_fifo_input_interface[63:32], tx_data[63:32]};
        tx_fifo_interface_shift = {tx_data[31:0], 32'hXXXXXXXX};
    end
    5:begin
        tx_fifo_input_shift = {tx_fifo_input_interface[63:24], tx_data[63:40]};
        tx_fifo_interface_shift = {tx_data[39:0], 24'hXXXXXX};
    end
    6:begin
        tx_fifo_input_shift = {tx_fifo_input_interface[63:16], tx_data[63:48]};
        tx_fifo_interface_shift = {tx_data[47:0], 16'hXXXX};
    end
    7:begin
        tx_fifo_input_shift = {tx_fifo_input_interface[63:8], tx_data[63:56]};
        tx_fifo_interface_shift = {tx_data[55:0], 8'hXX};
    end
    default:begin
        tx_fifo_input_shift = tx_data;
        tx_fifo_interface_shift = tx_data;
    end

    endcase
end

always_ff@(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        tx_fifo_input_interface_cnt <= 0;
        tx_fifo_write_ptr <= 0;
    end else begin
        tx_data_fifo_wr <= 1;
        tx_data_fifo_in <= tx_fifo_input_shift;
        tx_data_fifo_in_ptr <= tx_fifo_write_ptr >> 3;
        if(local_tx_valid)begin
            tx_fifo_write_ptr <= (tx_fifo_write_ptr + tx_cnt + 1)%tx_buf_size;

            tx_fifo_input_interface_cnt <= (tx_fifo_input_interface_cnt + tx_cnt + 1 - 8)%8;

            if(tx_fifo_input_interface_cnt + tx_cnt + 1 > 8)begin
                tx_fifo_input_interface <= tx_fifo_interface_shift;
            end else begin
                tx_fifo_input_interface <= tx_fifo_input_shift;
            end
        end
    end
end

always_ff@(posedge clk)begin
    if(tx_data_fifo_wr)begin
        tx_data_fifo[tx_data_fifo_in_ptr] <= tx_data_fifo_in;
    end
end

always_comb begin
    tx_data_fifo_out <= tx_data_fifo[tx_fifo_read_ptr];
end

/* TX Control


If phy_ready but connection_state is not 1, then send RST and SYN packet

*/
shortint tx_payload_size;
logic [11:0] tx_flag;
logic tx_trg;
logic tx_ack;

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
logic [19:0] pre_tcp_head_checksum_step0 = 16'h4500 + 16'h4000 + 16'h8006 + ip[31:16] + ip[15:0] + remote_ip[31:16] + remote_ip[15:0] + 16'h0028;
logic [19:0] pre_tcp_head_checksum_step1 = pre_tcp_head_checksum_step0[15:0] + pre_tcp_head_checksum_step0[19:16];
logic [15:0] pre_tcp_head_checksum_step2 = pre_tcp_head_checksum_step1[15:0] + pre_tcp_head_checksum_step1[19:16];

logic [19:0] tcp_head_checksum_step0 = pre_tcp_head_checksum_step2 + ipv4_identification + tx_packet_local_tx_payload_size;
logic [19:0] tcp_head_checksum_step1 = tcp_head_checksum_step0[15:0] + tcp_head_checksum_step0[19:16];
logic [15:0] tcp_head_checksum_step2 = tcp_head_checksum_step1[15:0] + tcp_head_checksum_step1[19:16];

logic [15:0] tcp_head_checksum = ~tcp_head_checksum_step2;

//For tcp head, the 

always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n == 0)begin
        tx_ack <= 0;
        tx_net_valid <= 0;
        tx_net_fin <= 0;

        tx_packet_sta <= 0;
    end else begin
        tx_ack <= 1'b0;
        if(tx_net_ready)tx_net_valid <= 1'b0;

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
                tx_net_data <= {tcp_head_checksum, ip[31:0], remote_ip[31:16]};
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

                //TBD checksum
                //TBD XX 2BYTE
                tx_net_data <= {16'h0200, 16'h0000, 16'h0000, 16'h0000};

                if(tx_packet_local_tx_payload_size != 0)begin
                    tx_packet_sta <= 7;
                end else begin
                    tx_packet_sta <= 0;
                end
            end
            endcase
        end
        
    end
end


endmodule