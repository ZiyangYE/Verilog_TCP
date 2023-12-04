module arp_sender(
    input clk,
    input clr,
    input start,

    output data_en,
    output [7:0] data_out,
    input data_av,

    output fin
);

`include "CRC_func.sv"
`include "configs.svh"


localparam logic[7:0] arp_param [0:41]= {
    8'hff,8'hff,8'hff,8'hff,8'hff,8'hff, //dest mac
    sour_mac,arp_type,arp_hrd,ipv4_type,arp_size,arp_op,sour_mac,ip_sour,
    8'h00,8'h00,8'h00,8'h00,8'h00,8'h00, //dest mac
    ip_sour
};

localparam logic[7:0] zeros [0:17] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};

localparam logic[31:0] arp_crc = pre_calc_crc({arp_param, zeros});
localparam logic[7:0] arp_rom [0:63] = {arp_param,zeros, 
    arp_crc[7:0], arp_crc[15:8], arp_crc[23:16], arp_crc[31:24]};

reg [7:0] arp_rom_pointer;
reg send_en;

reg data_en_reg;
reg [7:0] data_out_reg;
reg fin_reg;

always@(posedge clk)begin
    data_en_reg <= 1'b0;
    fin_reg <= 1'b0;
    if(clr)begin
        arp_rom_pointer <= 8'h00;
        send_en <= 1'b0;
    end else begin
        if(start)begin
            arp_rom_pointer <= 8'h00;
            send_en <= 1'b1;
        end else if(send_en)begin
            if(data_av)begin
                data_en_reg <= 1'b1;
                data_out_reg <= arp_rom[arp_rom_pointer];
                arp_rom_pointer <= arp_rom_pointer + 1'b1;
                if(arp_rom_pointer == 63)begin
                    send_en <= 1'b0;
                    fin_reg <= 1'b1;
                end
            end else begin
                data_en_reg <= 1'b0;
            end
        end
    end
end


assign data_en = data_en_reg;
assign data_out = data_out_reg;
assign fin = fin_reg;

endmodule