
//1 = read, 0 = write
module SMI_ct(
    input clk, rst, rw, trg,
    [4:0] phy_adr, reg_adr,
    [15:0] data,
    output logic ready, ack,
    logic [15:0] smi_data,
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

    always_ff@(posedge clk or negedge rst)begin
        if(rst == 1'b0)begin
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


module tx_ct(
    input clk, rst,
    input [7:0] data,
    input tx_en,
    output logic tx_av,
    output logic tx_bz,

    output logic [1:0] p_txd,
    output logic p_txen
);

logic[7:0] buffer[2047:0];
shortint begin_ptr;
shortint end_ptr;
logic[7:0] buffer_out;

byte send_status;

byte tick;
shortint send_cnt;

logic int_en;



always_comb begin
    //64 byte free
    int_en <= tx_en;
    
    tx_bz <= send_status != 0;
end

always_ff@(posedge clk or negedge rst)begin
    if(rst == 1'b0)begin
        begin_ptr <= 0;
        end_ptr <= 0;
        send_status <= 0;
    end else begin
        p_txen <= 1'b0;
        tick<=tick + 8'd1;
        if(tick == 3)begin
            tick <= 0;
        end
        if(int_en)begin
            buffer[begin_ptr] <= data;
            begin_ptr <= begin_ptr + 16'd1;
            if(begin_ptr == 2047)begin_ptr<=0;
        end
        case(send_status)
            0:begin //idle wait for tx_en
                if(begin_ptr != end_ptr)begin
                    send_status <= 1;
                    send_cnt <= 0;
                end
            end
            1:begin //send preamble and SFD
                send_cnt <= send_cnt + 8'd1;
                p_txd <= 2'b01;
                p_txen <= 1'b1;
                if(send_cnt == 31)begin
                    p_txd <= 2'b11;
                    send_status <=2;
                    send_cnt <= 0;
                    tick <= 0;
                end
            end
            2:begin //send payload

                buffer_out <= {2'bXX,buffer_out[7:2]};
                p_txd <= buffer_out[1:0];
                p_txen <= 1'b1;
                if(tick == 2)begin
                    end_ptr <= end_ptr + 16'd1;
                    if(end_ptr == 2047)end_ptr<=0;
                end

                if(tick == 3 && send_cnt < 96)send_cnt <= send_cnt + 8'd1;
                
                if(tick == 3 && (end_ptr - begin_ptr)%2048 == 0)begin

                    send_status <= 3;
                end
            end
            3:begin //send padding
                p_txd <= 2'bXX;
                p_txen <= 1'b0;
                send_status <= 0;
            end
        endcase
        if(tick == 3)begin
            buffer_out <= buffer[end_ptr];
        end
    end

end



endmodule
