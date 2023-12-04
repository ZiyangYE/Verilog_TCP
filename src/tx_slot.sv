module tx_slot(
    input clk,
    input clr,
    input start,

    output data_en,
    output [7:0] data_out,
    input data_av,
    output fin,

    output busy,

    input [31:0] ack,
    input [31:0] seq,
    input [15:0] window_size,
    input [7:0] flags,

    input wr_en,
    input [7:0] wr_data,
    output wr_av
);

`include "configs.svh"
`include "pre_calc_checksum.sv"

localparam logic [7:0] opt_ram [0:7] = {
    8'h02,8'h04, tx_max_len / 256, tx_max_len % 256, // MSS
    8'h03,8'h03,8'h00, // Window scale x1
    8'h01 // NOP
};

reg [15:0] identifier;

localparam [7:0] tx_head_param [0:37] = {
    dest_mac,sour_mac,ipv4_type,8'h45,8'h00,
    8'h00,8'h00, // total len
    8'h00,8'h00, // idf
    ipv4_flg,ipv4_ttl,ipv4_tcp,
    8'h00,8'h00, // ip checksum
    ip_sour,ip_dest,
    port_sour[15:8], port_sour[7:0], port_dest[15:8], port_dest[7:0]
};

logic [7:0] tx_head [0:37];

assign tx_head[0:15] = tx_head_param[0:15];
assign tx_head[20:23] = tx_head_param[20:23];
assign tx_head[26:37] = tx_head_param[26:37];





reg [15:0] ip_pre_checksum = pre_calc_checksum_ipv4({
    8'h45,8'h00,
    ipv4_flg,ipv4_ttl,ipv4_tcp,
    ip_dest,ip_sour
});
reg [17:0] ip_pesudo_checksum_s0;
reg [16:0] ip_pesudo_checksum_s1;
reg [15:0] ip_pesudo_checksum_s2;
always@(*)begin
    ip_pesudo_checksum_s0 <= {2'b0,ip_pre_checksum} + (tx_head[16]<<8) + tx_head[17] + (tx_head[18]<<8) + tx_head[19];
    ip_pesudo_checksum_s1 <= {1'b0,ip_pesudo_checksum_s0[15:0]} + ip_pesudo_checksum_s0[17:16];
    ip_pesudo_checksum_s2 <= {ip_pesudo_checksum_s1[15:0]} + ip_pesudo_checksum_s1[16];
end

//tcp len, tcp seq, tcp ack, head_len_flags, wind
reg [15:0] tcp_pre_checksum_0 = ~pre_calc_checksum_tcp_0({
    ip_sour,ip_dest,8'h00,ipv4_tcp, 
    port_sour[15:8],port_sour[7:0],port_dest[15:8],port_dest[7:0],opt_ram
});
reg [15:0] tcp_pre_checksum_1 = ~pre_calc_checksum_tcp_1({
    ip_sour,ip_dest,8'h00,ipv4_tcp, 
    port_sour[15:8],port_sour[7:0],port_dest[15:8],port_dest[7:0]
});


reg busy_reg;

reg [31:0] ack_buf;
reg [31:0] seq_buf;
reg [15:0] window_size_buf;
reg [7:0] flags_buf;

reg start_buf;
reg clr_buf;

reg [31:0] ack_reg;
reg [31:0] seq_reg;
reg [15:0] window_size_reg;
reg [7:0] flags_reg;

reg [7:0] data_out_reg;
reg data_en_reg;

reg [7:0] wr_data_buf;
reg wr_en_buf;
reg wr_av_reg;

reg [7:0] wr_data_ram [0:tx_max_len-1];
reg [13:0] wr_ptr;

reg [5:0] s0_ptr;
reg [4:0] s1_ptr;
reg [13:0] s2_ptr;

reg [4:0] state;

reg fin_reg;

reg next;
reg [7:0] data_next;
reg next_av;

reg [15:0] ip_total_len;

wire data_checksum_phase;
reg [7:0] data_checksum_mask;
reg data_checksum_tick;

reg [19:0] pesudo_tcp_checksum_s0;
reg [16:0] pesudo_tcp_checksum_s1;
reg [15:0] tcp_checksum;
wire [15:0] data_checksum;

reg [31:0] crc_checksum;

reg [6:0] total_sent_len;


always@(posedge clk)begin
    next_av <= 1'b0;
    data_checksum_mask <= 8'hff;
    data_checksum_tick <= 1'b0;

    ack_buf <= ack;
    seq_buf <= seq;
    window_size_buf <= window_size;
    flags_buf <= flags;
    start_buf <= start;
    clr_buf <= clr;


    // wr logic
    wr_en_buf <= wr_en;
    wr_data_buf <= wr_data;

    if(busy_reg)begin
        wr_en_buf <= 0;
        start_buf <= 0;
    end

    if(wr_en_buf)begin
        wr_data_ram[wr_ptr] <= wr_data_buf;
        wr_ptr <= wr_ptr + 1;
    end

    // wr_av logic
    wr_av_reg <= wr_ptr < tx_max_len;
    if(wr_en_buf && wr_ptr == tx_max_len-1)begin
        wr_av_reg <= 0;
    end

    if(state[1])begin
        if(next)begin
            next_av <= 1;
            data_next <= tx_head[s0_ptr];
            s0_ptr <= s0_ptr + 1;

            total_sent_len <= total_sent_len + 1;

            if(s0_ptr == 37)begin
                state <= 5'b00100;
            end
        end
    end
    if(state[2])begin
        if(next)begin
            next_av <= 1;
            total_sent_len <= total_sent_len + 1;
            if(s1_ptr == 0)begin
                data_next <= seq_reg[31:24];
            end
            if(s1_ptr == 1)begin
                data_next <= seq_reg[23:16];
            end
            if(s1_ptr == 2)begin
                data_next <= seq_reg[15:8];
            end
            if(s1_ptr == 3)begin
                data_next <= seq_reg[7:0];
            end
            if(s1_ptr == 4)begin
                data_next <= ack_reg[31:24];
            end
            if(s1_ptr == 5)begin
                data_next <= ack_reg[23:16];
            end
            if(s1_ptr == 6)begin
                data_next <= ack_reg[15:8];
            end
            if(s1_ptr == 7)begin
                data_next <= ack_reg[7:0];
            end
            if(s1_ptr == 8)begin
                data_next <= flags_reg[1]?8'h70:8'h50;
            end
            if(s1_ptr == 9)begin
                data_next <= flags_reg;
            end
            if(s1_ptr == 10)begin
                data_next <= window_size_reg[15:8];
            end
            if(s1_ptr == 11)begin
                data_next <= window_size_reg[7:0];
            end
            if(s1_ptr == 12)begin
                data_next <= tcp_checksum[15:8];
            end
            if(s1_ptr == 13)begin
                data_next <= tcp_checksum[7:0];
            end
            if(s1_ptr == 14)begin
                data_next <= 8'h00;
            end
            if(s1_ptr == 15)begin
                data_next <= 8'h00;
            end
            if(s1_ptr > 15)begin
                data_next <= opt_ram[s1_ptr-16];
            end

            if((flags_buf[1]==1'b0 && s1_ptr == 15) || s1_ptr == 23)begin
                state <= 5'b01000;

                //if(wr_ptr == 0)begin
                //    state <= 5'b10000;
                //end
            end

            s1_ptr <= s1_ptr + 1;
        end
    end
    if(state[3])begin
        if(next)begin
            next_av <= 1;
            data_next <= wr_data_ram[s2_ptr];
            s2_ptr <= s2_ptr + 1;

            if(total_sent_len < 60)begin
                total_sent_len <= total_sent_len + 1;
            end

            if(s2_ptr >= wr_ptr && total_sent_len >= 60)begin
                state <= 5'b10000;
                next_av <= 0;

                busy_reg <= 0;
            end

            if(s2_ptr >= wr_ptr && total_sent_len < 60)begin
                data_next <= 8'h00;
            end
        end
    end

    // start logic
    if(start || start_buf)begin
        busy_reg <= 1;
    end
    if(start_buf)begin
        total_sent_len <= 0;
        s0_ptr <= 0;
        s1_ptr <= 0;
        s2_ptr <= 0;

        ack_reg <= ack_buf;
        seq_reg <= seq_buf;
        window_size_reg <= window_size_buf;
        flags_reg <= flags_buf;

        tx_head[18] <= identifier[15:8];
        tx_head[19] <= identifier[7:0];

        identifier <= identifier + 1;

        state <= 5'b00010;
    end
    if(state[1] && s0_ptr == 1)begin
        //calc total len
        ip_total_len <= wr_ptr + 20 + 20 + (flags_buf[1]?8:0);

        //calc tcp checksum
        if(data_checksum_phase)begin
            data_checksum_mask <= 8'h00;
            data_checksum_tick <= 1'b1;
        end
    end
    if(state[1] && s0_ptr == 2)begin
        //write total len
        tx_head[16] <= ip_total_len[15:8];
        tx_head[17] <= ip_total_len[7:0];

        //calc tcp checksum
        //tcp len, tcp seq, tcp ack, head_len_flags, wind
        pesudo_tcp_checksum_s0 <= {4'b0,~data_checksum} + {4'b0,flags_buf[1]?tcp_pre_checksum_0:tcp_pre_checksum_1} + (flags_buf[1]?28:20) + wr_ptr + seq_reg[31:16] + seq_reg[15:0] + ack_reg[31:16] + ack_reg[15:0] + window_size_buf + flags_buf + (flags_buf[1]?16'h7000:16'h5000);
    end
    if(state[1] && s0_ptr == 3)begin
        //calc tcp checksum
        pesudo_tcp_checksum_s1 <= {1'b0,pesudo_tcp_checksum_s0[15:0]} + pesudo_tcp_checksum_s0[19:16];
    end
    if(state[1] && s0_ptr == 4)begin
        //calc ip checksum
        tx_head[24] <= ~ip_pesudo_checksum_s2[15:8];
        tx_head[25] <= ~ip_pesudo_checksum_s2[7:0];

        //calc tcp checksum
        tcp_checksum <= ~({pesudo_tcp_checksum_s1[15:0]} + pesudo_tcp_checksum_s1[16]);
    end

    if(clr_buf)begin
        state <= 5'b00001;
        busy_reg <= 0;
        wr_ptr <= 0;
    end
end

reg en_waits [0:3];
reg [7:0] data_waits [0:3];
reg [4:0] crc_wait;
// data sender logic
always@(posedge clk)begin
    fin_reg <= 1'b0;
    next <= 1'b0;
    data_en_reg <= 1'b0;
    data_out_reg <= 8'h00;
    if(data_av)begin
        next <= 1;
    end
    if(next && next_av)begin
        data_en_reg <= 1;
        data_out_reg <= data_next;
    end

    data_waits[0] <= data_out_reg;
    data_waits[1] <= data_waits[0];
    data_waits[2] <= data_waits[1];
    data_waits[3] <= data_waits[2];

    en_waits[0] <= data_en_reg;
    en_waits[1] <= en_waits[0];
    en_waits[2] <= en_waits[1];
    en_waits[3] <= en_waits[2];

    if(state[3])begin
        crc_wait <= 8;
    end

    if(state[4])begin
        if(crc_wait > 0)begin
            crc_wait <= crc_wait - 1;

            if(crc_wait == 4)begin
                en_waits[0] <= 1'b1;
                en_waits[1] <= 1'b1;
                en_waits[2] <= 1'b1;
                en_waits[3] <= 1'b1;

                data_waits[0] <= crc_checksum[31:24];
                data_waits[1] <= crc_checksum[23:16];
                data_waits[2] <= crc_checksum[15:8];
                data_waits[3] <= crc_checksum[7:0];
            end

            if(crc_wait == 1)begin
                fin_reg <= 1'b1;
            end
        end
    end

    if(clr_buf)begin
        crc_wait <= 1'b0;

        en_waits[0] <= 1'b0;
        en_waits[1] <= 1'b0;
        en_waits[2] <= 1'b0;
        en_waits[3] <= 1'b0;
    end
end

checksum_1B tcp_chksum_module(
    .clk(clk),
    .clr(clr_buf),
    .data_en(wr_en_buf | data_checksum_tick),
    .data_in(wr_data_buf & data_checksum_mask),
    .checksum(data_checksum),
    .phase(data_checksum_phase)
);

CRC_1B crc_module(
    .clk(clk),
    .clr(start_buf),
    .data_en(data_en_reg),
    .data_in(data_out_reg),
    .crc_out(crc_checksum)
);

initial begin
    identifier <= 16'h0000;
end

assign data_out = data_waits[3];
assign data_en = en_waits[3]; 
assign busy = busy_reg;
assign wr_av = wr_av_reg;
assign fin = fin_reg;


endmodule