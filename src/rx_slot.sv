//TODO, not aligned checksum

module rx_slot #(
    parameter DATA_WIDTH = 8
) (
    input clk,
    input clr,
    input resyn,

    input data_en,
    input [DATA_WIDTH-1:0] data_in,
    input data_fin,

    output busy,
    output active,
    output error,

    output [31:0] ack,
    output [31:0] seq,
    output [23:0] window_size,
    output [7:0] flags,
    output [13:0] mss,


    input rd_en,
    output [DATA_WIDTH-1:0] rd_data,
    output rd_av
);

`include "configs.svh"

byte unsigned ref_rx_rom [0:37] = {
    sour_mac,dest_mac,ipv4_type,8'h40,8'h00, // 2 ignored bytes
    8'h00,8'h00,// total length
    8'h00,8'h00, // identifier ignored
    8'h00,8'h00, // flags ignored
    8'h00, // ttl ignored
    ipv4_tcp, // protocol
    8'h00,8'h00, // checksum ignored
    ip_dest,ip_sour, // ip addresses
    port_dest[15:8], port_dest[7:0], port_sour[15:8], port_sour[7:0]
};

byte unsigned ref_rx_mask [0:37] = {
    8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,// mac addresses
    8'hff,8'hff, // ipv4 type
    8'hf0,8'h00, // type and header length and flags
    8'h00,8'h00, // total length
    8'h00,8'h00, // identifier
    8'h00,8'h00, // flags
    8'h00, // ttl
    8'hff, // protocol
    8'h00,8'h00, // checksum
    8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,8'hff, // ip addresses
    8'hff,8'hff,8'hff,8'hff // ports
};

reg finallize_reg;

reg error_reg;
reg active_reg;
reg busy_reg;

reg chk_rst_0;



reg [DATA_WIDTH-1:0] data_in_buf;
reg data_en_buf;
reg fin_buf;

reg prev_en;

reg clr_buf;
reg resyn_buf;


reg [13:0] write_cnt;
reg [13:0] read_cnt;

reg [5:0] s0_ptr;
reg [4:0] s1_ptr;
reg [13:0] up_limit;

reg [4:0] state;

reg [15:0] tcp_chksum;

reg ip_chksum_en;
reg [7:0] ip_chksum_buf;

reg tcp_chksum_en;
reg [7:0] tcp_chksum_buf;

reg [15:0] tcp_checksum_pesudo;

wire [15:0] ip_chksum_calc;
wire [15:0] tcp_chksum_calc;

reg [5:0] ip_header_end;
reg [5:0] tcp_header_end;
reg [15:0] ip_total_len;
reg [5:0] opt_len;

reg crc_data_en;
reg [DATA_WIDTH-1:0] crc_data_in;
wire [31:0] crc_checksum;
wire crc_rdy;

reg [31:0] crc_checksum_eth;

reg [DATA_WIDTH-1:0] rd_data_ram [0:rx_max_len-1];
reg [7:0] tcp_config_ram [0:31];


reg [23:0] actual_window_size;
reg [15:0] tcp_window_size;
reg [7:0] tcp_flags;
reg [31:0] tcp_seq_num;
reg [31:0] tcp_ack_num;

reg [13:0] tcp_mss;
reg [3:0] tcp_scale;

reg [7:0] rd_data_buf;
reg rd_av_buf;


//configs
reg tcp_config_wait;
reg tcp_config_fin;

reg [15:0] pre_tcp_mss;
reg [3:0] pre_tcp_scale;

reg [1:0] fin_cks;

reg [31:0] crc_history [0:3];

always@(posedge clk)begin
    ip_chksum_en <= 1'b0;
    tcp_chksum_en <= 1'b0;
    crc_data_en <= 1'b0;

    data_en_buf <= data_en;
    data_in_buf <= data_in;
    clr_buf <= clr;
    resyn_buf <= resyn;
    fin_buf <= data_fin;

    prev_en <= data_en_buf;

    chk_rst_0 <= ((data_in_buf ^ ref_rx_rom[s0_ptr]) & ref_rx_mask[s0_ptr]) != 8'd0;

    rd_data_buf <= rd_data_ram[read_cnt];
    rd_av_buf <= read_cnt < write_cnt;

    if(data_en_buf && !finallize_reg)begin
        busy_reg <= 1'b1;
    end
    
    up_limit <= ip_total_len + 14'd14 - ip_header_end - tcp_header_end;

    tcp_checksum_pesudo <= ip_total_len + 16'd14 - ip_header_end + 16'h0006;

    if(tcp_scale < 8)begin
        actual_window_size <= tcp_window_size << tcp_scale;
    end
    else begin
        if(tcp_window_size < 256)begin
            actual_window_size <= tcp_window_size << tcp_scale;
        end
        else begin
            actual_window_size <= tcp_window_size << 8;
        end
    end

    if(data_en_buf)begin
        crc_history[0] <= crc_history[1];
        crc_history[1] <= crc_history[2];
        crc_history[2] <= crc_history[3];
        crc_history[3] <= crc_checksum;

        crc_checksum_eth <= {data_in_buf, crc_checksum_eth[31:8]};

        crc_data_en <= 1'b1;
        crc_data_in <= data_in_buf;

        if(s0_ptr >= 14 && s0_ptr < ip_header_end)begin
            ip_chksum_en <= 1'b1;
            ip_chksum_buf <= data_in_buf;
        end

        if(s0_ptr == 19)begin
            tcp_chksum_en <= 1'b1;
            tcp_chksum_buf <= tcp_checksum_pesudo[15:8];
        end
        if(s0_ptr == 20)begin
            tcp_chksum_en <= 1'b1;
            tcp_chksum_buf <= tcp_checksum_pesudo[7:0];
        end
        if(s0_ptr >= 26 && s0_ptr < 34)begin
            tcp_chksum_en <= 1'b1;
            tcp_chksum_buf <= data_in_buf;
        end
        if(s0_ptr >= ip_header_end)begin
            tcp_chksum_en <= 1'b1;
            tcp_chksum_buf <= data_in_buf;
        end
        if(state[1] || state[2])begin
            tcp_chksum_en <= 1'b1;
            tcp_chksum_buf <= data_in_buf;
        end
    

        s0_ptr <= s0_ptr + 6'd1;
        s1_ptr <= s1_ptr + 5'd1;
        write_cnt <= write_cnt + 14'd1;

        if(s0_ptr == ip_header_end + 3)begin
            state <= 5'b00010;
        end
        if(s1_ptr == tcp_header_end - 4)begin
            tcp_config_wait <= 1'b1;
            state <= 5'b00100;
            if(up_limit == 0)begin
                state <= 5'b10000;
            end
        end

        opt_len <= (tcp_header_end - 6'd20);

        if(s0_ptr == 14)
            ip_header_end <= (data_in_buf[3:0] << 2) + 6'd14;
        if(s0_ptr == 16)
            ip_total_len[15:8] <= data_in_buf;
        if(s0_ptr == 17)
            ip_total_len[7:0] <= data_in_buf;
        if(s1_ptr == 0)
            tcp_seq_num[31:24] <= data_in_buf;
        if(s1_ptr == 1)
            tcp_seq_num[23:16] <= data_in_buf;
        if(s1_ptr == 2)
            tcp_seq_num[15:8] <= data_in_buf;
        if(s1_ptr == 3)
            tcp_seq_num[7:0] <= data_in_buf;
        if(s1_ptr == 4)
            tcp_ack_num[31:24] <= data_in_buf;
        if(s1_ptr == 5)
            tcp_ack_num[23:16] <= data_in_buf;
        if(s1_ptr == 6)
            tcp_ack_num[15:8] <= data_in_buf;
        if(s1_ptr == 7)
            tcp_ack_num[7:0] <= data_in_buf;
        if(s1_ptr == 8)
            tcp_header_end <= (data_in_buf[7:4] << 2);
        if(s1_ptr == 9)
            tcp_flags <= data_in_buf;
        if(s1_ptr == 10)
            tcp_window_size[15:8] <= data_in_buf;
        if(s1_ptr == 11)
            tcp_window_size[7:0] <= data_in_buf;
        if(s1_ptr == 12)
            tcp_chksum[15:8] <= data_in_buf;
        if(s1_ptr == 13)
            tcp_chksum[7:0] <= data_in_buf;
        if(s1_ptr > 15 && s1_ptr < 36)
            tcp_config_ram[s1_ptr-16] <= data_in_buf;
        
        if(write_cnt < up_limit)begin
            rd_data_ram[write_cnt] <= data_in_buf;
        end
    end

    if(rd_en)begin
        read_cnt <= read_cnt + 14'd1;
    end


    if(state[0] == 1'b0)begin
        s0_ptr <= 0;
    end
    if(state[1] == 1'b0 && state[4] == 1'b0)begin
        s1_ptr <= 0;
    end
    if(state[2] == 1'b0)begin
        write_cnt <= 0;
    end

    if(prev_en && state[0] == 1'b1 && chk_rst_0)begin
        error_reg <= 1'b1;
        state <= 5'b01000;
    end

    if(fin_buf)begin
        finallize_reg <= 1'b1;
    end

    if(finallize_reg && !state[3])begin
        //check tcp checksum
        //check ip checksum
        //check crc checksum
        if(ip_chksum_calc != 16'h0000)begin
            error_reg <= 1'b1;
            state <= 5'b01000;
        end

        if(tcp_config_fin)begin
            tcp_mss <= pre_tcp_mss[13:0];
            tcp_scale <= pre_tcp_scale;
            fin_cks[0] <= 1'b1;
        end

        if(crc_rdy)begin
            fin_cks[1] <= 1'b1;

            if(tcp_chksum_calc != 16'h0000)begin
                error_reg <= 1'b1;
                state <= 5'b01000;
            end

            if(crc_history[0] != crc_checksum_eth)begin
                error_reg <= 1'b1;
                state <= 5'b01000;
            end
        end

        if(fin_cks == 2'b11)begin
            state <= 5'b01000;
            active_reg <= 1'b1;
            busy_reg <= 1'b0;
        end
    end

    if(clr_buf)begin

        state <= 5'b00001;
        s0_ptr <= 0;
        read_cnt <= 0;
        busy_reg <= 1'b0;
        error_reg <= 1'b0;
        active_reg <= 1'b0;
        finallize_reg <= 1'b0;

        tcp_config_wait <= 1'b0;

        ip_header_end <= 6'h3F;
        tcp_header_end <= 6'h3F;
        fin_cks <= 2'b00;
    end

    if(resyn_buf)begin
        tcp_scale <= 0;
        tcp_mss <= 1460;
    end
end


//process tcp config
reg [4:0] tcp_config_ptr;
reg [2:0] tcp_config_sta;
reg [4:0] cfg_len;
reg [4:0] cfg_ptr;
reg next_mss;
reg next_scale;
/*
0 no config
1 unknown cmd
2 mss
3 window scale
*/

always@(posedge clk)begin
    if(tcp_config_wait)begin
        if(tcp_config_ptr == opt_len)begin
            tcp_config_fin <= 1'b1;
        end else begin
            tcp_config_ptr <= tcp_config_ptr + 5'd1;
            case(tcp_config_sta)
                3'b001:begin
                    if(tcp_config_ram[tcp_config_ptr]>1)begin
                        tcp_config_sta <= 3'b010;
                    end

                    if(tcp_config_ram[tcp_config_ptr]==2)begin
                        next_mss <= 1'b1;
                    end
                    if(tcp_config_ram[tcp_config_ptr]==3)begin
                        next_scale <= 1'b1;
                    end
                end
                3'b010:begin
                    cfg_len <= tcp_config_ram[tcp_config_ptr][4:0];
                    cfg_ptr <= 0;
                    tcp_config_sta <= 3'b100;
                end
                3'b100:begin
                    if(next_mss)begin
                        if(cfg_ptr == 0)begin
                            pre_tcp_mss[15:8] <= tcp_config_ram[tcp_config_ptr];
                        end else begin
                            pre_tcp_mss[7:0] <= tcp_config_ram[tcp_config_ptr];
                        end
                    end
                    if(next_scale)begin
                        pre_tcp_scale <= tcp_config_ram[tcp_config_ptr][3:0];
                    end
                    if(cfg_ptr == cfg_len - 3)begin
                        tcp_config_sta <= 3'b001;
                        next_mss <= 1'b0;
                        next_scale <= 1'b0;
                    end
                    cfg_ptr <= cfg_ptr + 5'd1;
                end
            endcase
        end
    end else begin
        next_scale <= 1'b0;
        next_mss <= 1'b0;
        tcp_config_ptr <= 1'b0;
        tcp_config_fin <= 1'b0;
        tcp_config_sta <= 3'b001;
    end
end


checksum_1B ip_chksum_module(
    .clk(clk),
    .clr(clr_buf),
    .data_en(ip_chksum_en),
    .data_in(ip_chksum_buf),
    .checksum(ip_chksum_calc)
);

checksum_1B tcp_chksum_module(
    .clk(clk),
    .clr(clr_buf),
    .data_en(tcp_chksum_en),
    .data_in(tcp_chksum_buf),
    .checksum(tcp_chksum_calc)
);

CRC_1B crc_module(
    .clk(clk),
    .clr(clr_buf),
    .data_en(crc_data_en),
    .data_in(crc_data_in),
    .crc_out(crc_checksum),
    .crc_rdy(crc_rdy)
);


assign busy = busy_reg;
assign active = active_reg;
assign error = error_reg;

assign ack = tcp_ack_num;
assign seq = tcp_seq_num;
assign window_size = actual_window_size;
assign flags = tcp_flags;
assign mss = tcp_mss;

assign rd_data = rd_data_buf;
assign rd_av = rd_av_buf;

endmodule
