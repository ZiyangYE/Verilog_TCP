module ethernet_crc (
    input logic clk,
    input logic reset,
    input logic [63:0] data_in,      // 64-bit input data
    input logic [2:0] byte_num,      // Number of valid bytes in data_in (1 to 8)
    input logic data_in_valid,       // Indicates if data_in is valid
    output logic [31:0] crc_out      // 32-bit CRC output
);

    localparam POLY = 32'h04C11DB7; // Polynomial
    logic [31:0] crc_reg [0:63];    // Array of registers for intermediate CRC values

    // Initialize CRC value
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            crc_reg[0] <= 32'hFFFFFFFF;
        end else if (data_in_valid) begin
            crc_reg[0] <= crc_reg[63];
        end
    end

    // Generate block for CRC calculations
    genvar i;
    generate
        for (i = 0; i < 64; i++) begin : crc_calculate
            always_ff @(posedge clk) begin
                if (data_in_valid) begin
                    // Only process the bits within the valid byte range
                    logic bit_in;
                    if (i < byte_num * 8) begin
                        bit_in = data_in[i] ^ crc_reg[i][31];
                    end else begin
                        bit_in = crc_reg[i][31];
                    end

                    crc_reg[i + 1] = {crc_reg[i][30:0], 1'b0};
                    if (bit_in) begin
                        crc_reg[i + 1] = crc_reg[i + 1] ^ POLY;
                    end
                end
            end
        end
    endgenerate

    assign crc_out = ~crc_reg[63]; // Invert the CRC at the end

endmodule
