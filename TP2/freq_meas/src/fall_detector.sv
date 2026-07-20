`timescale 1ns/1ps

module fall_detector #  (
    input logic i_clk,
    input logic i_rst_n,
    input logic i_signal,
    output logic o_flag
);
    logic reg_signal;

    always_ff @( posedge i_clk) begin
        if (~i_rst_n)
            reg_signal <= 1'b0;
        else
            reg_signal <= i_signal;
    end

    assign o_flag = reg_signal & ~i_signal;
endmodule