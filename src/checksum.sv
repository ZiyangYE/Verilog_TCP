module checksum_1B(
    input clk,
    input clr,

    input data_en,
    input [7:0] data_in,
    
    output [15:0] checksum,
    output phase
);

reg [7:0] last_in;
reg phase_reg;

reg [15:0] last_sum;
reg [16:0] pesudo_sum;

always@(*) begin
    if({1'b0, last_sum} + {1'b0, last_in, data_in} > 16'hffff) begin
        pesudo_sum <= {1'b0, last_sum} + {1'b0, last_in, data_in} + 17'd1;
    end else begin
        pesudo_sum <= {1'b0, last_sum} + {1'b0, last_in, data_in};
    end
end



always @(posedge clk) begin
    if (clr) begin
        phase_reg <= 0;
        last_sum <= 0;
    end else if (data_en) begin
        last_in <= data_in;
        if (phase_reg) begin
            last_sum <= pesudo_sum[15:0];
        end
        phase_reg <= ~phase_reg;
    end
end

assign checksum = ~last_sum;
assign phase = phase_reg;

endmodule