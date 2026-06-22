`timescale 1ns/1ps

module sync_bus #(
    parameter int NB_DATA = 3,
    parameter int PIPE    = 3
) (
    input  logic                  i_clk,
    input  logic                  i_rst,
    input  logic [NB_DATA-1 : 0]  i_data,
    output logic [NB_DATA-1 : 0]  o_data
);

    logic [NB_DATA-1 : 0] pipe [PIPE-1 : 0];

    always_ff @(posedge i_clk) begin
        if (i_rst) begin
            for (int i = 0; i < PIPE; i++) begin
                pipe[i] <= '0;
            end
        end else begin
            pipe[0] <= i_data;

            for (int i = 1; i < PIPE; i++) begin
                pipe[i] <= pipe[i-1];
            end
        end
    end

    assign o_data = pipe[PIPE-1];

endmodule