//Note: This module is used to verify the output data format is correct or not.
//This is not used for any other purpose.

module mac_decoder(
    input clk,
    input rst_n,

    input rx_en,
    input [1:0] rmii_rx
);



byte rx_state;

byte cnt;
logic[7:0] rx_data_s;

logic crs = rx_en;
logic[1:0] rxd = rmii_rx;
logic phy_rdy = rst_n;
logic clk50m = clk;

byte rx_cnt;
byte tick;

logic fifo_in;
logic[7:0] fifo_d;
always_comb begin
    fifo_in <= tick == 0 && rx_state == 3;
    fifo_d <= rx_data_s;
end
logic fifo_drop;

always @(posedge clk50m or negedge phy_rdy) begin
    if(phy_rdy==1'b0)begin
        cnt <=0;
    end else begin
        if(crs)begin
            tick <= tick + 8'd1;
            if(tick == 3)tick <= 0;
        end
        rx_cnt <= 0;
        fifo_drop <= 1'b0;

        case(rx_state)
            0:begin
                rx_state <= 1;
            end
            1:begin //检测前导码和相位
                if(rx_data_s[7:0] == 8'h55)begin
                    rx_state <= 2;
                end
            end
            2:begin
                tick <= 1;
                if(rx_data_s == 8'h55)begin
                    rx_cnt <= rx_cnt + 8'd1;
                end else begin
                    if(rx_data_s == 8'hD5 && rx_cnt > 26)begin
                        rx_state <= 3;
                        tick <= 1;
                    end else begin
                        rx_state <= 0;
                    end
                end
            end
            3:begin
                if(crs == 1'b0)
                    fifo_drop <= 1'b1;
            end
        endcase

        if(crs == 1'b0)begin
            rx_state<=0;
            rx_data_s <= 8'b00XXXXXX;
        end
        if(crs)begin
            rx_data_s <= {rxd,rx_data_s[7:2]};
        end
    end
end

logic [7:0] rx_data_gd;
logic rx_data_rdy;
logic rx_data_fin;

shortint rx_data_byte_cnt;
byte ethernet_resolve_status;



logic [47:0] rx_info_buf;

logic [47:0] rx_src_mac;
logic [15:0] rx_type;


shortint head_len;

logic [17:0] checksum;

logic [31:0] src_ip;
logic [31:0] dst_ip;
logic [15:0] src_port;
logic [15:0] dst_port;

logic [15:0] idf;
logic [15:0] udp_len;

shortint rx_head_fifo_head_int;
shortint rx_head_fifo_head;
shortint rx_head_fifo_tail = 0;
logic [31:0] rx_head_fifo[127:0];

logic [31:0] rx_head_data_i_port;
logic rx_head_data_i_en;
logic [7:0] rx_head_data_i_adr;
//4 packs each frame
//0: src_ip
//1: dst_ip
//2: src_port+dst_port
//3: idf+udp_len

task rx_head_fifo_push(input [31:0] data);
    rx_head_data_i_port <= data;
    rx_head_data_i_en <= 1'b1;
    rx_head_data_i_adr <= rx_head_fifo_head_int[7:0];

    rx_head_fifo_head_int <= rx_head_fifo_head_int + 16'd1;
    if(rx_head_fifo_head_int == 127)
        rx_head_fifo_head_int <= 0;
endtask

shortint rx_data_fifo_head_int;
shortint rx_data_fifo_head;
shortint rx_data_fifo_tail = 0;
logic [7:0] rx_data_fifo[8191:0];

logic [7:0] rx_data_fifo_i_port;
logic rx_data_fifo_i_en;
logic [12:0] rx_data_fifo_i_adr;

task rx_data_fifo_push(input [7:0] data);
    rx_data_fifo_i_port <= data;
    rx_data_fifo_i_en <= 1'b1;
    rx_data_fifo_i_adr <= rx_data_fifo_head_int[12:0];

    rx_data_fifo_head_int <= rx_data_fifo_head_int + 16'd1;
    if(rx_data_fifo_head_int == 8191)
        rx_data_fifo_head_int <= 0;
endtask

logic rx_fin;



always_ff@(posedge clk50m or negedge phy_rdy)begin
    if(phy_rdy==1'b0)begin
        ethernet_resolve_status <= 0;
        rx_head_fifo_head <= 0;
        rx_head_fifo_head_int <= 0;
        
        rx_data_fifo_head <= 0;
        rx_data_fifo_head_int <= 0;

        arp_list <= 2'b00;
    end else begin
        if(rx_head_data_i_en)
            rx_head_fifo[rx_head_data_i_adr] <= rx_head_data_i_port;
        rx_head_data_i_en <= 1'b0;
        if(rx_data_fifo_i_en)
            rx_data_fifo[rx_data_fifo_i_adr] <= rx_data_fifo_i_port;
        rx_data_fifo_i_en <= 1'b0;
        

        rx_fin <= rx_data_fin;

        if(rx_data_byte_cnt[0]==1'b0)begin
            checksum <= {2'b0,checksum[15:0]}+{2'b0,rx_info_buf[15:0]}+{15'd0,checksum[17:16]};
        end
        if(rx_data_byte_cnt==14)
            checksum <= 0;

        rx_data_byte_cnt <= rx_data_byte_cnt + 8'd1;
        rx_info_buf <= {rx_info_buf[39:0],rx_data_gd};
        case(ethernet_resolve_status)
            0:begin      
                if(rx_data_byte_cnt == 6)begin
                    if((rx_info_buf == mac_adr) || (rx_info_buf == 48'hFFFFFFFFFFFF))
                        ethernet_resolve_status <= 1;
                    else
                        ethernet_resolve_status <= 100;
                end  
            end
            1:begin
                //回复rx_fifo
                rx_head_fifo_head_int <= rx_head_fifo_head;
                rx_data_fifo_head_int <= rx_data_fifo_head;


                if(rx_data_byte_cnt == 12)begin
                    rx_src_mac <= rx_info_buf;
                end
                if(rx_data_byte_cnt == 14)begin
                    ethernet_resolve_status <= 100;
                    if(rx_info_buf[15:0] == 16'h0800)//IP包处理(只收UDP,不处理分片)
                        ethernet_resolve_status <= 20;
                    if(rx_info_buf[15:0] == 16'h0806)//ARP包处理
                        ethernet_resolve_status <= 30;
                end
            end
            20:begin
                //如果fifo满了，就直接拒绝接收
                //head 剩余空间小于4 或者 data 剩余空间小于1600
                if((rx_data_fifo_tail + 127 - rx_data_fifo_head_int) % 128 < 4)
                    ethernet_resolve_status <= 100;
                if((rx_data_fifo_tail + 8191 - rx_data_fifo_head_int) % 8192 < 1600)
                    ethernet_resolve_status <= 100;

                if(rx_data_byte_cnt == 20)begin
                    if(rx_info_buf[47:44]!=4'd4)begin
                        ethernet_resolve_status <= 100;
                    end
                    head_len <= rx_info_buf[43:40]*4;
                    idf <= rx_info_buf[15:0];
                end
                if(rx_data_byte_cnt == 26)begin
                    if(rx_info_buf[23:16] != 8'h11)
                        ethernet_resolve_status <= 100;
                    
                    //checksum <= rx_info_buf[15:0];
                end

                if(rx_data_byte_cnt == 30)begin
                    src_ip <= rx_info_buf[31:0];
                end

                if(rx_data_byte_cnt == head_len + 14)begin
                    ethernet_resolve_status <= 21;

                    if(rx_data_byte_cnt != 34)
                        checksum <= src_ip[15:0]+src_ip[31:16]+dst_ip[15:0]+dst_ip[31:16]+16'h0011;
                    else
                        checksum <= src_ip[15:0]+src_ip[31:16]+rx_info_buf[15:0]+rx_info_buf[31:16]+16'h0011;
                end

                
                if(rx_data_byte_cnt == 34)begin
                    if(rx_info_buf[31:0] != ip_adr && rx_info_buf[31:0] != 32'hFFFFFFFF)
                        ethernet_resolve_status <= 100;
                    
                    dst_ip <= rx_info_buf[31:0];
                    
                    if((checksum[17:0]+{2'd0,rx_info_buf[15:0]} != 18'h0FFFF) && (checksum[17:0]+{2'd0,rx_info_buf[15:0]} != 18'h1FFFE) && (checksum[17:0]+{2'd0,rx_info_buf[15:0]} != 18'h2FFFD))
                    //if((checksum[16:0]+{1'b0,rx_info_buf[15:0]} != 17'h00000) && (checksum[16:0]+{1'b0,rx_info_buf[15:0]} != 17'h1FFFF))
                        ethernet_resolve_status <= 100;
                end
            end
            21:begin
                if(rx_data_byte_cnt == head_len + 18)begin
                    rx_head_fifo_push(src_ip);
                end
                if(rx_data_byte_cnt == head_len + 19)begin
                    rx_head_fifo_push(dst_ip);
                end
                if(rx_data_byte_cnt == head_len + 21)begin
                    rx_head_fifo_push({src_port,dst_port});
                end
                if(rx_data_byte_cnt == head_len + 22)begin
                    rx_head_fifo_push({idf,udp_len - 8});
                end

                if(rx_data_byte_cnt == head_len + 20)begin
                    src_port <= rx_info_buf[47:32];
                    dst_port <= rx_info_buf[31:16];
                    udp_len <= rx_info_buf[15:0];
                end

                if(rx_data_byte_cnt > head_len + 22 && udp_len != 8)begin
                    rx_data_fifo_push(rx_info_buf[7:0]);
                end

                if(rx_data_byte_cnt == head_len + 14 + udp_len)begin
                    if(rx_data_byte_cnt[0]==1'b1)begin
                        if((checksum[17:0]+{2'd0,rx_info_buf[7:0],8'd0}+udp_len != 18'h0FFFF)&&(checksum[17:0]+{2'd0,rx_info_buf[7:0],8'd0}+udp_len != 18'h1FFFE)&&(checksum[17:0]+{2'd0,rx_info_buf[7:0],8'd0}+udp_len != 18'h2FFFD))
                            ethernet_resolve_status <= 100;
                        else begin
                            ethernet_resolve_status <= 29;
                            //移动头部指针
                            rx_head_fifo_head <= rx_head_fifo_head_int;
                            if(udp_len != 8)
                                rx_data_fifo_head <= rx_data_fifo_head_int == 8191?16'd0:rx_data_fifo_head_int+16'd1;
                        end
                    end else begin
                        if((checksum[17:0]+{2'd0,rx_info_buf[15:0]}+udp_len != 18'h0FFFF)&&(checksum[17:0]+{2'd0,rx_info_buf[15:0]}+udp_len != 18'h1FFFE)&&(checksum[17:0]+{2'd0,rx_info_buf[15:0]}+udp_len != 18'h2FFFD))
                            ethernet_resolve_status <= 100;
                        else begin
                            ethernet_resolve_status <= 29;
                            //移动头部指针
                            rx_head_fifo_head <= rx_head_fifo_head_int;
                            if(udp_len != 8)
                                rx_data_fifo_head <= rx_data_fifo_head_int == 8191?16'd0:rx_data_fifo_head_int+16'd1;
                        end
                    end
                end

            end
            29:begin

            end
            
        endcase

        if(rx_data_rdy == 1'b0)
            rx_data_byte_cnt <= 0;

        if(rx_fin)
            ethernet_resolve_status <= 0;
    end
end



CRC_check crc(
    .clk(clk50m),
    .rst(phy_rdy),
    .data(fifo_d),
    .av(fifo_in),
    .stp(fifo_drop),

    .data_gd(rx_data_gd),
    .rdy(rx_data_rdy),
    .fin(rx_data_fin)
);




endmodule


module CRC_check(
    input clk,
    input rst,

    input [7:0] data,
    input av,
    input stp,

    output logic [7:0] data_gd,
    output logic rdy,
    output logic fin
);

logic[7:0] buffer[2047:0];

logic[31:0] crc;
logic[31:0] crc_next;

logic [7:0] data_i;

assign data_i = {data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7]};

assign crc_next[0] = crc[24] ^ crc[30] ^ data_i[0] ^ data_i[6];
assign crc_next[1] = crc[24] ^ crc[25] ^ crc[30] ^ crc[31] ^ data_i[0] ^ data_i[1] ^ data_i[6] ^ data_i[7];
assign crc_next[2] = crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31] ^ data_i[0] ^ data_i[1] ^ data_i[2] ^ data_i[6] ^ data_i[7];
assign crc_next[3] = crc[25] ^ crc[26] ^ crc[27] ^ crc[31] ^ data_i[1] ^ data_i[2] ^ data_i[3] ^ data_i[7];
assign crc_next[4] = crc[24] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ data_i[0] ^ data_i[2] ^ data_i[3] ^ data_i[4] ^ data_i[6];
assign crc_next[5] = crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_i[0] ^ data_i[1] ^ data_i[3] ^ data_i[4] ^ data_i[5] ^ data_i[6] ^ data_i[7];
assign crc_next[6] = crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_i[1] ^ data_i[2] ^ data_i[4] ^ data_i[5] ^ data_i[6] ^ data_i[7];
assign crc_next[7] = crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[31] ^ data_i[0] ^ data_i[2] ^ data_i[3] ^ data_i[5] ^ data_i[7];
assign crc_next[8] = crc[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ data_i[0] ^ data_i[1] ^ data_i[3] ^ data_i[4];
assign crc_next[9] = crc[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ data_i[1] ^ data_i[2] ^ data_i[4] ^ data_i[5];
assign crc_next[10] = crc[2] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ data_i[0] ^ data_i[2] ^ data_i[3] ^ data_i[5];
assign crc_next[11] = crc[3] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ data_i[0] ^ data_i[1] ^ data_i[3] ^ data_i[4];
assign crc_next[12] = crc[4] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ data_i[0] ^ data_i[1] ^ data_i[2] ^ data_i[4] ^ data_i[5] ^ data_i[6];
assign crc_next[13] = crc[5] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_i[1] ^ data_i[2] ^ data_i[3] ^ data_i[5] ^ data_i[6] ^ data_i[7];
assign crc_next[14] = crc[6] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ crc[31] ^ data_i[2] ^ data_i[3] ^ data_i[4] ^ data_i[6] ^ data_i[7];
assign crc_next[15] =  crc[7] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[31] ^ data_i[3] ^ data_i[4] ^ data_i[5] ^ data_i[7];
assign crc_next[16] = crc[8] ^ crc[24] ^ crc[28] ^ crc[29] ^ data_i[0] ^ data_i[4] ^ data_i[5];
assign crc_next[17] = crc[9] ^ crc[25] ^ crc[29] ^ crc[30] ^ data_i[1] ^ data_i[5] ^ data_i[6];
assign crc_next[18] = crc[10] ^ crc[26] ^ crc[30] ^ crc[31] ^ data_i[2] ^ data_i[6] ^ data_i[7];
assign crc_next[19] = crc[11] ^ crc[27] ^ crc[31] ^ data_i[3] ^ data_i[7];
assign crc_next[20] = crc[12] ^ crc[28] ^ data_i[4];
assign crc_next[21] = crc[13] ^ crc[29] ^ data_i[5];
assign crc_next[22] = crc[14] ^ crc[24] ^ data_i[0];
assign crc_next[23] = crc[15] ^ crc[24] ^ crc[25] ^ crc[30] ^ data_i[0] ^ data_i[1] ^ data_i[6];
assign crc_next[24] = crc[16] ^ crc[25] ^ crc[26] ^ crc[31] ^ data_i[1] ^ data_i[2] ^ data_i[7];
assign crc_next[25] = crc[17] ^ crc[26] ^ crc[27] ^ data_i[2] ^ data_i[3];
assign crc_next[26] = crc[18] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[30] ^ data_i[0] ^ data_i[3] ^ data_i[4] ^ data_i[6];
assign crc_next[27] = crc[19] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31] ^ data_i[1] ^ data_i[4] ^ data_i[5] ^ data_i[7];
assign crc_next[28] = crc[20] ^ crc[26] ^ crc[29] ^ crc[30] ^ data_i[2] ^ data_i[5] ^ data_i[6];
assign crc_next[29] = crc[21] ^ crc[27] ^ crc[30] ^ crc[31] ^ data_i[3] ^ data_i[6] ^ data_i[7];
assign crc_next[30] = crc[22] ^ crc[28] ^ crc[31] ^ data_i[4] ^ data_i[7];
assign crc_next[31] = crc[23] ^ crc[29] ^ data_i[5];


shortint begin_ptr;
shortint end_ptr;

logic sendout;

logic [7:0] bdata_gd;
logic brdy;
logic bfin;

always_ff@(posedge clk or negedge rst)begin
    if(rst == 1'b0)begin
        begin_ptr <= 0;
        end_ptr <= 0;
        rdy <= 1'b0;
        fin <= 1'b0;

        brdy <= 1'b0;
        bfin <= 1'b0;

        sendout <= 1'b0;

        crc <= 32'hFFFFFFFF;
    end else begin
        data_gd <= bdata_gd;
        rdy <= brdy;
        fin <= bfin;

        bdata_gd <= buffer[begin_ptr];
        brdy <= 1'b0;
        bfin <= 1'b0;



        if(sendout)begin
            brdy <= 1'b1;
            if(begin_ptr == end_ptr)begin
                sendout <= 1'b0;
                bfin <= 1'b1;
            end else begin
                begin_ptr <= begin_ptr + 16'd1;
                if(begin_ptr == 2047)begin_ptr<=0;
            end
        end


        if(stp)begin
            if(crc == 32'hC704DD7B)begin
                //start output the data
                sendout <= 1'b1;
                end_ptr <= (end_ptr + 16'd2043)%16'd2048;
            end else begin
                //drop the data
                begin_ptr <= end_ptr;
            end
            crc <= 32'hFFFFFFFF;
        end else begin
            if(av)begin
                buffer[end_ptr] <= data;
                end_ptr <= end_ptr + 16'd1;
                if(end_ptr == 2047)end_ptr<=0;

                crc <= crc_next;
            end
        end
    end
end


endmodule

