module ethernet_crc_64 (
    input clk,
    input reset,
    input [63:0] data_in, // 64-bit input data
    input data_in_valid,  // Indicates if data_in is valid
    output logic [31:0] crc_out // 32-bit CRC output
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

    // Generate block to create a chain of CRC calculations
    genvar i;
    generate
        for (i = 0; i < 64; i++) begin : crc_calculate
            always_ff @(posedge clk) begin
                if (data_in_valid) begin
                    logic bit_in = data_in[i] ^ crc_reg[i][31];
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
