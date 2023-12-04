`include "CRC_func.sv"

module CRC_1B(
    input clk,
    input clr,

    input [7:0] data_in,
    input data_en,
    
    output [31:0] crc_out,
    output crc_rdy
);

reg clr_buf;
reg [7:0] data_in_buf;
reg data_en_buf;

reg [31:0] crc_out_r;
reg crc_rdy_r;

reg [31:0] crc_t_1;


always @(posedge clk) begin
    clr_buf <= clr;
    data_in_buf <= data_in;
    data_en_buf <= data_en;

    if(crc_rdy_r == 1'b0)begin
        crc_out_r <= ~crc_t_1;
    end

    if(data_en_buf) begin
        crc_t_1 <= compute_crc_1(crc_t_1, data_in_buf);
        crc_rdy_r <= 1'b0;
    end else begin
        crc_rdy_r <= 1'b1;
    end

    if(clr_buf) begin
        crc_t_1 <= {32{1'b1}};
    end
end // always

assign crc_out = crc_out_r;
assign crc_rdy = crc_rdy_r;

endmodule // crc


module CRC_16B(
    input clk,
    input clr,

    input [127:0] data_in,
    input [3:0] data_len, // 0 -> 16; else 1 - 15
    input data_en,
    
    output [31:0] crc_out,
    output crc_rdy
);

reg clr_buf;
reg [127:0] data_in_buf;
reg [3:0] data_len_buf;
reg data_en_buf;

reg [119:0] data_shift_buf;

reg [31:0] crc_out_r;
reg crc_rdy_r;

reg [31:0] crc_t_16;
reg [31:0] crc_t_1;

reg [3:0] cnt; 
reg pha_second;


always @(posedge clk) begin
    clr_buf <= clr;
    data_in_buf <= data_in;
    data_len_buf <= data_len;
    data_en_buf <= data_en;

    if(crc_rdy_r == 1'b0)begin
        crc_out_r <= ~crc_t_1;
    end

    if(data_en_buf) begin
        data_shift_buf <= data_in[127:8];
        cnt <= data_len_buf;
        crc_t_16 <= compute_crc_16(crc_t_16, data_in_buf);
        crc_t_1 <= crc_t_16;
        crc_rdy_r <= 1'b0;
        pha_second <= 1'b0;
    end else begin
        pha_second <= 1'b1;
        data_shift_buf <= {data_shift_buf[111:0], 8'hXX};
        if(cnt != 0)begin
            cnt <= cnt - 4'd1;
            crc_t_1 <= compute_crc_1(crc_t_1, data_shift_buf[119:112]);
        end else begin
            crc_rdy_r <= pha_second;
            crc_t_1 <= crc_t_16;
        end
    end
    if(clr_buf) begin
        crc_t_16 <= {32{1'b1}};
    end
end // always

assign crc_out = crc_out_r;
assign crc_rdy = crc_rdy_r;

endmodule // crc

