//----------------------------------------------------------------------
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//----------------------------------------------------------------------
//----------------------------------------------------------------------
// Author          : LAKKA
// Mail            : Ja_P_S@outlook.com
// File            : udp.sv
//----------------------------------------------------------------------
// Creation Date   : 06.05.2023
//----------------------------------------------------------------------
//

`include "rmii.svh"
`include "checksum_func.sv"

module nett(
    input clk1m,
    input rst,

    output logic clk50m,
    output logic ready,

    rmii netrmii,

    output logic phyrst,

    input trg,
    output l1
);


//logic [31:0] ip_adr = {8'd192,8'd168,8'd15,8'd16};

logic rphyrst;


assign netrmii.mdc = clk1m;
logic phy_rdy;
logic SMI_trg;
logic SMI_ack;
logic SMI_ready;
logic SMI_rw;
logic [4:0] SMI_adr;
logic [15:0] SMI_data;
logic [15:0] SMI_wdata;

byte SMI_status;

assign ready = phy_rdy;


always_ff@(posedge clk1m or negedge rst)begin
    if(rst == 1'b0)begin
        phy_rdy <= 1'b0;
        rphyrst <= 1'b0;
        SMI_trg <= 1'b0;
        SMI_adr <= 5'd1;
        SMI_rw <= 1'b1;
        SMI_status <= 0;
    end else begin
        rphyrst <= 1'b1;
        if(phy_rdy == 1'b0)begin
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
                            phy_rdy <= 1'b1;
                            SMI_trg <= 1'b0;
                        end
                    end
                endcase
            end
        end
    end
end

SMI_ct ct(
    .clk(clk1m), .rst(rphyrst), .rw(SMI_rw), .trg(SMI_trg), .ready(SMI_ready), .ack(SMI_ack),
    .phy_adr(5'd1), .reg_adr(SMI_adr),
    .data(SMI_wdata),
    .smi_data(SMI_data),
    .mdio(netrmii.mdio)
);

assign phyrst = rphyrst;

assign clk50m = netrmii.clk50m;

//rx fifo
logic arp_rpy_fin;

byte rx_state;

byte cnt;
logic[7:0] rx_data_s;


logic crs;
assign crs = netrmii.rx_crs;
logic[1:0] rxd;
assign rxd = netrmii.rxd;

byte rx_cnt;
byte tick;

logic fifo_in;
logic[7:0] fifo_d;

always_ff@(posedge clk50m) begin
    fifo_in <= tick == 0 && rx_state == 3;
    fifo_d <= rx_data_s;
end

logic fifo_drop;
assign l1 = fifo_in ^ fifo_drop ^ fifo_d[0] ^ fifo_d[1] ^ fifo_d[2] ^ fifo_d[3] ^ fifo_d[4] ^ fifo_d[5] ^ fifo_d[6] ^ fifo_d[7];
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



logic tx_bz;
logic tx_av;
logic [7:0] test_data;
logic test_tx_en;

tx_ct ctct(
    .clk(clk50m), .rst(phy_rdy),
    .data(test_data),
    .tx_en(test_tx_en),
    .tx_bz(tx_bz),
    .tx_av(tx_av),
    .p_txd(netrmii.txd),
    .p_txen(netrmii.txen)
);


reg s1_clr;
reg s1_resyn;
wire s1_busy;
wire s1_active;
wire s1_error;

wire [31:0] s1_ack;
wire [31:0] s1_seq;
wire [23:0] s1_win;
wire [7:0] s1_flags;
wire [13:0] s1_mss;

wire s1_rd_av;

rx_slot s1(
    .clk(clk50m),
    .clr(s1_clr),
    .resyn(s1_resyn),

    .data_in(fifo_d),
    .data_en(fifo_in),
    .data_fin(fifo_drop),

    .busy(s1_busy),
    .active(s1_active),
    .error(s1_error),

    .ack(s1_ack),
    .seq(s1_seq),
    .window_size(s1_win),
    .flags(s1_flags),
    .mss(s1_mss),
    .rd_av(s1_rd_av)

);


logic [7:0] status;
logic [7:0] rom_pointer;
logic [15:0] cntt;

reg tx_clr;
reg tx_start;

reg arp_start;
wire arp_fin;

wire arp_data_en;
wire [7:0] arp_data_out;

wire txs_fin;

wire txs_data_en;
wire [7:0] txs_data_out;

reg tx_data_en;

reg [3:0] cct;

reg [7:0] tx_data_out;

reg [7:0] tx_flags;

reg [31:0] tx_seq;
reg [31:0] tx_ack;

reg [31:0] cnttt;

reg [7:0] tx_data;
reg tx_en;

assign test_data = tx_data_out;
assign test_tx_en = tx_data_en;

always@(posedge clk50m or negedge phy_rdy)begin
    if(phy_rdy == 1'b0)begin
        status <= 8'h00;

        //test_tx_en <= 1'b0;
    end else begin
        s1_clr <= 1'b0;
        s1_resyn <= 1'b0;

        tx_clr <= 1'b0;
        tx_start <= 1'b0;

        arp_start <= 1'b0;

        tx_data_en <= 1'b0;
        tx_en <= 1'b0;


        case(status)
            0:begin
                if(trg)begin
                    s1_clr <= 1'b1;
                    s1_resyn <= 1'b1;
                    tx_clr <= 1'b1;
                    status <= 1;
                end
            end
            1:begin
                arp_start <= 1'b1;
                status <= 2;
            end
            2:begin
                tx_data_en <= arp_data_en;
                tx_data_out <= arp_data_out;

                if(arp_fin)begin
                    cct <= 32;
                    status <= 3;
                end
            end
            3:begin
                if(tx_bz == 1'b0)begin
                    cct <= cct - 1;
                    if(cct == 1)begin
                        status <= 4;

                        tx_start <= 1'b1;
                        tx_flags <= 8'h04;

                        status <= 4;
                    end
                end
            end
            4:begin
                tx_data_en <= txs_data_en;
                tx_data_out <= txs_data_out;

                if(txs_fin)begin
                    status <= 5;
                end
                

            end
            5:begin
                if(tx_bz == 1'b0)begin
                    status <= 6;
                    cct <= 32;
                end
            end
            6:begin
                cct <= cct - 1;
                if(cct == 0)begin
                    //send syn
                    tx_start <= 1'b1;

                    tx_seq <= tx_seq + 1;
                    tx_flags <= 8'h02;

                    status <= 7;
                end
            end
            7:begin
                tx_data_en <= txs_data_en;
                tx_data_out <= txs_data_out;

                if(txs_fin)begin
                    status <= 8;
                end
            end
            8:begin
                if(tx_bz == 1'b0)begin
                    status <= 9;
                    cct <= 15;
                end
            end
            9:begin
                cct <= cct - 1;
                if(cct == 0)begin
                    status <= 10;
                    cnttt <= 24'd20000000;
                end
            end
            10:begin
                //wait for ack
                if(s1_active)begin
                    //send ack

                    //tx_ack <= s1_seq + 1;
                    if(s1_flags[1])begin
                        tx_ack <= s1_seq + 1;
                        tx_seq <= tx_seq + 1;
                        tx_flags <= 8'h10;

                        tx_start <= 1'b1;

                        status <= 11;
                    end else begin
                        tx_ack <= s1_seq;
                        status <= 12;
                    end
                        
                    
                end else begin
                    cnttt <= cnttt - 1;
                    if(cnttt == 0)begin
                        status <= 0;
                        cct <= 15;
                    end
                end
            end
            11:begin
                tx_data_en <= txs_data_en;
                tx_data_out <= txs_data_out;

                if(txs_fin)begin
                    status <= 12;
                end
            end
            12:begin
                if(tx_bz == 1'b0)begin
                    status <= 13;
                    cct <= 15;
                end
            end
            13:begin
                cct <= cct - 1;
                if(cct == 0)begin
                    status <= 14;
                end
            end
            14:begin
                tx_en <= 1'b1;
                tx_data <= 8'h00;
                status <= 15;
            end
            15:begin
                tx_seq <= tx_seq;
                tx_flags <= 8'h10;
                tx_start <= 1'b1;

                status <= 16;
            end
            16:begin
                tx_data_en <= txs_data_en;
                tx_data_out <= txs_data_out;

                if(txs_fin)begin
                    status <= 17;
                end
            end
            17:begin
                if(tx_bz == 1'b0)begin
                    status <= 18;
                    cct <= 15;
                end
            end
            18:begin
                cct <= cct - 1;
                if(cct == 0)begin
                    status <= 19;
                end
            end
            19:begin
                tx_clr <= 1'b1;
                status <= 0;
            end

        endcase
    end
end


tx_slot txs(
    .clk(clk50m),
    .clr(tx_clr),
    .start(tx_start),
    .data_out(txs_data_out),
    .data_en(txs_data_en),
    .data_av(1'b1),

    .fin(txs_fin),

    .ack(tx_ack),
    .seq(tx_seq),
    .window_size(16'hffff),
    .flags(tx_flags),
    .wr_en(tx_en),
    .wr_data(tx_data)
);

arp_sender arps(
    .clk(clk50m),
    .clr(~phy_rdy),
    .start(arp_start),

    .data_en(arp_data_en),
    .data_out(arp_data_out),
    .data_av(1'b1),
    .fin(arp_fin)
);

endmodule

