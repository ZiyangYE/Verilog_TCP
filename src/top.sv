`include "rmii.svh"

module top(
    input clk,
    input rst,

    rmii netrmii,
    output phyrst,

    output[5:0] led,

    input btn
);

logic trg;
logic[5:0] rled;
logic[23:0] ckdiv;


always_ff@(posedge clk or negedge rst)begin
    if(rst == 1'b0)begin
        rled <= 5'b00001;
        ckdiv <= 24'd0;
    end else begin
        ckdiv <= ckdiv + 24'd1;
        if(ckdiv == 24'd0)
            rled <= {rled[4:0],rled[5]};
    end
end

logic clk1m;
logic clk6m;
PLL_6M PLL6m(
    .clkout(clk6m),
    .clkoutd(clk1m),
    .clkin(clk)
);

logic clk50m;
logic ready;

logic l1;

nett nett_inst(
    .clk1m(clk1m),
    .rst(rst),

    .clk50m(clk50m),
    .ready(ready),

    .netrmii(netrmii),

    .phyrst(phyrst),

    .trg(trg),

    .l1(l1)
);


logic [31:0] cnt;
logic last_sta;
always@(posedge clk50m or negedge ready)begin
    if(ready == 1'b0)begin
        trg <= 1'b0;
        cnt <= 0;
    end else begin
        trg <= 1'b0;
        cnt <= cnt + 33'd1;
        if(cnt == 32'h7ffffff)begin
            cnt <= 0;
            trg <= 1'b1;
        end
    end
    
end


/*
logic [23:0] cnt;
logic last_sta;
always@(posedge clk50m)begin
    trg <= 1'b0;
    cnt <= cnt + 24'd1;
    if(cnt == 24'd0)begin
        last_sta <= btn;
        if(last_sta == 1'b0 && btn == 1'b1)
            trg <= 1'b1;
    end
end
*/

assign led = 6'h3F;// rled ^ l1;

endmodule

