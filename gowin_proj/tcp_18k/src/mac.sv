`include "rmii.svh"

module mac(
    input clk,
    input rst_n,

    input [63:0] tx_net_data,
    input tx_net_valid,
    output logic tx_net_ready,
    input [2:0] tx_net_cnt,
    input tx_net_fin,

    output logic [63:0] rx_net_data,
    output logic rx_net_valid,
    input rx_net_ready,
    output logic [2:0] rx_net_cnt,
    output logic rx_net_fin,

    output logic phy_ready,

    rmii netrmii
);

logic txen;
logic [1:0] txd;

assign netrmii.txen = txen;
assign netrmii.txd = txd;

phy_config phy_config(
    .clk(clk), .rst_n(rst_n),
    .mdc(netrmii.mdc), .mdio(netrmii.mdio),
    .phy_ready(phy_ready)
);

byte tx_state;
byte tx_cnt;
logic [63:0] tx_data;
logic local_fin;

logic crc_tick;
logic [31:0] crc;
logic crc_reset;

//TODO cross clock domain
//use rmii.clk as clk now

always_comb begin
    crc_tick <= tx_net_ready && tx_net_valid;
end

shortint send_cnt;

always_ff@(posedge clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        tx_net_ready <= 1'b0;
        tx_state <= 0;
    end else begin
        crc_reset <= 1'b0;

        tx_cnt <= tx_cnt - 1;
        tx_net_ready <= 1'b0;

        txen <= 1'b0;
        txd <= tx_data[63:62];
        tx_data <= {tx_data[61:0], 2'bXX};

        case(tx_state)
        0:begin
            if(tx_net_valid)begin
                //txd <= 2'b01;
                //txen <= 1'b1;

                send_cnt <= 0;

                tx_data <= 64'h5555555555555557;
                tx_state <= 1;
                tx_cnt <= 8'd31;
                local_fin <= 1'b0;

                crc_reset <= 1'b1;
            end
        end
        1:begin
            txen <= 1'b1;
            
            if(tx_cnt == 0)begin
                tx_net_ready <= 1'b1;

                tx_data <= tx_net_data;
                tx_cnt <= (((tx_net_cnt + 1) << 2) - 1);
                send_cnt <= send_cnt + tx_net_cnt + 1;
                local_fin <= tx_net_fin;

                if(local_fin)begin
                    if(send_cnt < 60)begin
                        tx_state <= 2;
                        tx_data <= 64'h0000000000000000;
                        send_cnt <= send_cnt + 8;
                        if(send_cnt < 52)begin
                            tx_cnt <= 31;
                        end else begin
                            tx_cnt <= (60 - send_cnt - 1)<<2 - 1;
                        end
                    end else begin
                        tx_state <= 3;
                        tx_data <= {crc, 32'hXXXXXXXX};
                        tx_cnt <= 8'd15;
                    end
                end
            end
        end
        2:begin // attach 0 to the end
            txen <= 1'b1;

            if(tx_cnt == 0)begin
                if(send_cnt < 60)begin
                    tx_state <= 2;
                    tx_data <= 64'h0000000000000000;
                    send_cnt <= send_cnt + 8;
                    if(send_cnt < 52)begin
                        tx_cnt <= 31;
                    end else begin
                        tx_cnt <= (60 - send_cnt - 1)<<2 - 1;
                    end
                end else begin
                    tx_state <= 3;
                    tx_data <= {crc, 32'hXXXXXXXX};
                    tx_cnt <= 8'd15;
                end
            end
        end
        3:begin
            txen <= 1'b1;

            if(tx_cnt == 0)begin
                tx_state <= 0;
            end
        end

        endcase

    end
end

crc_gen crc_inst(
    .clk(clk),
    .data(tx_net_data),
    .cnt(tx_net_cnt),

    .tick(crc_tick),
    .reset(crc_reset),
    .crc(crc)
);

    
endmodule


module crc_gen(
    input clk,

    input [63:0] data,
    input [2:0] cnt,
    input tick,
    input reset,
    output logic [31:0] crc
);

function logic [31:0] crc32(logic [31:0] crc, logic [7:0] data);
    logic [7:0] data_i;
    logic [31:0] crc_next;
    data_i = {data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7]};
    crc_next[0] = crc[24] ^ crc[30] ^ data_i[0] ^ data_i[6];
    crc_next[1] = crc[24] ^ crc[25] ^ crc[30] ^ crc[31] ^ data_i[0] ^ data_i[1] ^ data_i[6] ^ data_i[7];
    crc_next[2] = crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31] ^ data_i[0] ^ data_i[1] ^ data_i[2] ^ data_i[6] ^ data_i[7];
    crc_next[3] = crc[25] ^ crc[26] ^ crc[27] ^ crc[31] ^ data_i[1] ^ data_i[2] ^ data_i[3] ^ data_i[7];
    crc_next[4] = crc[24] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ data_i[0] ^ data_i[2] ^ data_i[3] ^ data_i[4] ^ data_i[6];
    crc_next[5] = crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_i[0] ^ data_i[1] ^ data_i[3] ^ data_i[4] ^ data_i[5] ^ data_i[6] ^ data_i[7];
    crc_next[6] = crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_i[1] ^ data_i[2] ^ data_i[4] ^ data_i[5] ^ data_i[6] ^ data_i[7];
    crc_next[7] = crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[31] ^ data_i[0] ^ data_i[2] ^ data_i[3] ^ data_i[5] ^ data_i[7];
    crc_next[8] = crc[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ data_i[0] ^ data_i[1] ^ data_i[3] ^ data_i[4];
    crc_next[9] = crc[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ data_i[1] ^ data_i[2] ^ data_i[4] ^ data_i[5];
    crc_next[10] = crc[2] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ data_i[0] ^ data_i[2] ^ data_i[3] ^ data_i[5];
    crc_next[11] = crc[3] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ data_i[0] ^ data_i[1] ^ data_i[3] ^ data_i[4];
    crc_next[12] = crc[4] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ data_i[0] ^ data_i[1] ^ data_i[2] ^ data_i[4] ^ data_i[5] ^ data_i[6];
    crc_next[13] = crc[5] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_i[1] ^ data_i[2] ^ data_i[3] ^ data_i[5] ^ data_i[6] ^ data_i[7];
    crc_next[14] = crc[6] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ crc[31] ^ data_i[2] ^ data_i[3] ^ data_i[4] ^ data_i[6] ^ data_i[7];
    crc_next[15] =  crc[7] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[31] ^ data_i[3] ^ data_i[4] ^ data_i[5] ^ data_i[7];
    crc_next[16] = crc[8] ^ crc[24] ^ crc[28] ^ crc[29] ^ data_i[0] ^ data_i[4] ^ data_i[5];
    crc_next[17] = crc[9] ^ crc[25] ^ crc[29] ^ crc[30] ^ data_i[1] ^ data_i[5] ^ data_i[6];
    crc_next[18] = crc[10] ^ crc[26] ^ crc[30] ^ crc[31] ^ data_i[2] ^ data_i[6] ^ data_i[7];
    crc_next[19] = crc[11] ^ crc[27] ^ crc[31] ^ data_i[3] ^ data_i[7];
    crc_next[20] = crc[12] ^ crc[28] ^ data_i[4];
    crc_next[21] = crc[13] ^ crc[29] ^ data_i[5];
    crc_next[22] = crc[14] ^ crc[24] ^ data_i[0];
    crc_next[23] = crc[15] ^ crc[24] ^ crc[25] ^ crc[30] ^ data_i[0] ^ data_i[1] ^ data_i[6];
    crc_next[24] = crc[16] ^ crc[25] ^ crc[26] ^ crc[31] ^ data_i[1] ^ data_i[2] ^ data_i[7];
    crc_next[25] = crc[17] ^ crc[26] ^ crc[27] ^ data_i[2] ^ data_i[3];
    crc_next[26] = crc[18] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[30] ^ data_i[0] ^ data_i[3] ^ data_i[4] ^ data_i[6];
    crc_next[27] = crc[19] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31] ^ data_i[1] ^ data_i[4] ^ data_i[5] ^ data_i[7];
    crc_next[28] = crc[20] ^ crc[26] ^ crc[29] ^ crc[30] ^ data_i[2] ^ data_i[5] ^ data_i[6];
    crc_next[29] = crc[21] ^ crc[27] ^ crc[30] ^ crc[31] ^ data_i[3] ^ data_i[6] ^ data_i[7];
    crc_next[30] = crc[22] ^ crc[28] ^ crc[31] ^ data_i[4] ^ data_i[7];
    crc_next[31] = crc[23] ^ crc[29] ^ data_i[5];
    
    return crc_next;
endfunction

logic[31:0] crc_next_p0;
logic[31:0] crc_next_p1;
logic[31:0] crc_next_p2;
logic[31:0] crc_next_p3;
logic[31:0] crc_next_p4;
logic[31:0] crc_next_p5;
logic[31:0] crc_next_p6;
logic[31:0] crc_next_p7;

assign crc_next_p0 = crc32(crc, data[7*8 +: 8]);
assign crc_next_p1 = crc32(crc_next_p0, data[6*8 +: 8]);
assign crc_next_p2 = crc32(crc_next_p1, data[5*8 +: 8]);
assign crc_next_p3 = crc32(crc_next_p2, data[4*8 +: 8]);
assign crc_next_p4 = crc32(crc_next_p3, data[3*8 +: 8]);
assign crc_next_p5 = crc32(crc_next_p4, data[2*8 +: 8]);
assign crc_next_p6 = crc32(crc_next_p5, data[1*8 +: 8]);
assign crc_next_p7 = crc32(crc_next_p6, data[0*8 +: 8]);

always@(posedge clk)begin
    if(reset)begin
        crc <= 32'hFFFFFFFF;
    end else begin
        if(tick)begin
            case(cnt)
            0:crc <= crc_next_p0;
            1:crc <= crc_next_p1;
            2:crc <= crc_next_p2;
            3:crc <= crc_next_p3;
            4:crc <= crc_next_p4;
            5:crc <= crc_next_p5;
            6:crc <= crc_next_p6;
            7:crc <= crc_next_p7;
            default:
            crc <= 32'hXXXXXXXX;
            endcase
        end
    end
end

endmodule

module phy_config(
    input clk,
    input rst_n,

    output mdc,
    inout mdio,

    output logic phy_ready
);

byte slow_clk_div = 99;
byte slow_clk_cnt;

logic slow_clk;

always_ff@(posedge clk or negedge rst_n)begin
    if(rst_n == 0)begin
        slow_clk_cnt <= 0;
        slow_clk <= 0;
    end else begin
        slow_clk_cnt <= slow_clk_cnt + 1;
        if(slow_clk_cnt == slow_clk_div)begin
            slow_clk_cnt <= 0;
            slow_clk <= ~slow_clk;
        end
    end
end

assign mdc = slow_clk;

logic phy_rst_n;
logic SMI_trg;
logic SMI_ack;
logic SMI_ready;
logic SMI_rw;
logic [4:0] SMI_adr;
logic [15:0] SMI_data;
logic [15:0] SMI_wdata;

byte SMI_status;


always_ff@(slow_clk or negedge rst_n)begin
    if(rst_n == 1'b0)begin
        phy_ready <= 1'b0;
        phy_rst_n <= 1'b0;
        SMI_trg <= 1'b0;
        SMI_adr <= 5'd1;
        SMI_rw <= 1'b1;
        SMI_status <= 0;
    end else begin
        phy_rst_n <= 1'b1;
        if(phy_ready == 1'b0)begin
            SMI_trg <= 1'b1;
            if(SMI_ack && SMI_ready)begin
                case(SMI_status)
                    0:begin
                        SMI_adr <= 5'd31;
                        SMI_wdata <= 16'h7;
                        SMI_rw <= 1'b0;

                        SMI_status <= 1;
                    end
                    1:begin
                        SMI_adr <= 5'd16;
                        SMI_wdata <= 16'hFFE;

                        SMI_status <= 2;
                    end
                    2:begin
                        SMI_rw <= 1'b1;

                        SMI_status <= 3;
                    end
                    3:begin
                        SMI_adr <= 5'd31;
                        SMI_wdata <= 16'h0;
                        SMI_rw <= 1'b0;

                        SMI_status <= 4;
                    end
                    4:begin
                        SMI_adr <= 5'd1;
                        SMI_rw <= 1'b1;

                        SMI_status <= 5;
                    end
                    5:begin
                        if(SMI_data[2])begin
                            phy_ready <= 1'b1;
                            SMI_trg <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end
end

smi_control ct(
    .clk(slow_clk), .rst_n(phy_rst_n), .rw(SMI_rw), .trg(SMI_trg), .ready(SMI_ready), .ack(SMI_ack),
    .phy_adr(5'd1), .reg_adr(SMI_adr),
    .data(SMI_wdata),
    .smi_data(SMI_data),
    .mdio(netrmii.mdio)
);

endmodule

module smi_control(
    input clk,
    input rst_n,
    input rw, //1 = read, 0 = write
    input trg,
    input [4:0] phy_adr, 
    input [4:0] reg_adr,
    input [15:0] data,
    output logic ready,
    output logic ack,
    output logic [15:0] smi_data,
    inout logic mdio
);

    byte ct;
    reg rmdio;

    reg [31:0] tx_data;
    reg [15:0] rx_data;

    assign mdio = rmdio?1'bZ:1'b0;

    always_comb begin
        smi_data <= rx_data;
    end

    always_ff@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            ct <= 0;
            ready <= 1'b0;
            ack <= 1'b0;

            rmdio <= 1'b1;
        end else begin
            ct <= ct + 8'd1;
            if(ct == 0 && trg == 1'b0)ct<=0;
            if(ct == 0 && trg == 1'b1)begin
                ready <= 1'b0;
                ack <= 1'b0;
            end

            if(ct == 64)begin
                ready <= 1'b1;
            end

            if(trg == 1'b1 && ready == 1'b1)begin
                ready <= 1'b0;
            end

            rmdio <= 1'b1;

            if(ct == 4 && trg == 1'b1)begin
                tx_data <= {2'b01, rw?2'b10:2'b01, phy_adr, reg_adr, rw?2'b11:2'b10, rw?16'hFFFF:data};
            end

            if(ct>31)begin
                rmdio <= tx_data[31];
                tx_data <= {tx_data[30:0], 1'b1};
            end

            if(ct == 48 && mdio == 1'b0)begin
                ack <= 1'b1;
            end
            
            if(ct>48)begin
                rx_data <= {rx_data[14:0], mdio};
            end
        end
    end
endmodule