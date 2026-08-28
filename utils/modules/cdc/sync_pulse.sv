`timescale 1ns/1ps

//! Synchronizes a sufficiently wide source-domain rising pulse into a destination
//! clock domain and regenerates it as a one-destination-clock pulse.

module sync_pulse #(
    parameter int PIPE = 3
) (
    output logic o_pulse,
    input  logic i_pulse,
    input  logic i_rst_n,
    input  logic i_clk
);

    //! First PIPE registers form the metastability synchronizer.
    logic [PIPE-1 : 0] pipe_r;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            pipe_r   <= '0;
        end else begin
            pipe_r[0] <= i_pulse;

            for (int i = 1; i < PIPE; i++) begin
                pipe_r[i] <= pipe_r[i-1];
            end

        end
    end

    assign o_pulse = pipe_r[PIPE-2] & ~pipe_r[PIPE-1];

endmodule
