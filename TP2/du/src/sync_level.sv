`timescale 1ns/1ps

module sync_level #(
    parameter int PIPE = 2
) (
    output logic o_data,

    input  logic i_data,
    input  logic i_rst_n,
    input  logic i_clk
);

    //! Synchronization pipeline
    logic [PIPE - 1 : 0] pipe_r;

    //! Synchronize the input level into the destination clock domain
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            pipe_r <= '0;
        end else begin
            pipe_r[0] <= i_data;

            for (int i = 1; i < PIPE; i++) begin
                pipe_r[i] <= pipe_r[i - 1];
            end
        end
    end

    //! Expose the last synchronization stage
    assign o_data = pipe_r[PIPE - 1];
endmodule