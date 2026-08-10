`timescale 1ns/1ps

module sync_bus #(
    parameter int PIPE = 2,
    parameter int WIDTH = 8
) (
    output logic [WIDTH - 1 : 0] o_data,
    input  logic [WIDTH - 1 : 0] i_data,
    input  logic i_rst_n,
    input  logic i_clk
);

    logic [WIDTH - 1 : 0] pipe_r [PIPE - 1 : 0];

    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            for(int i= 0; i<PIPE; i++) begin
                pipe_r[i] <= '0;
            end
        end else begin
            pipe_r[0] <= i_data;

            for(int i = 1; i<PIPE; i++) begin
                pipe_r[i] <= pipe_r[i-1];
            end
        end
    end

    assign o_data = pipe_r[PIPE - 1];

endmodule