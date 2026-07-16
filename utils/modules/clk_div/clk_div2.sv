`timescale 1ps/1ps

module clk_div2 (
    input logic  i_rst,
    input logic  i_clk,
    output logic o_clk
);

    always_ff @(posedge i_clk) begin
        if(i_rst) begin
            o_clk <= '0;
        end else begin
            o_clk <= ~o_clk;
        end
    end
endmodule