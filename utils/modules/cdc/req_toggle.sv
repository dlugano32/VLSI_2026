//! @title Fast-to-Slow Clock Domain Request Synchronizer
//! @file sync.sv
//! @author Damian Lugano
//! @date 12-6-2026
//!
//! @brief Clock-domain crossing synchronizer for request pulses from a fast clock domain to a slower clock domain.

`timescale 1ns/1ps

module req_toggle #(
    parameter int PIPE = 3
) (
    input  logic i_clk_a,
    input  logic i_clk_b,
    input  logic i_rst_a,
    input  logic i_rst_b,
    input  logic i_req,
    output logic o_req
);

    //! Source-domain toggle
    logic toggle;

    //! Destination-domain synchronization pipeline
    logic pipe [PIPE - 1 : 0];

    //! Toggle generation in source clock domain
    always_ff @(posedge i_clk_a or negedge i_rst_a) begin : src_toggle
        if (!i_rst_a) begin
            toggle <= 1'b0;
        end else if (i_req) begin
            toggle <= ~toggle;
        end
    end

    //! Toggle synchronization into destination clock domain
    always_ff @(posedge i_clk_b or negedge i_rst_b) begin : dst_pipe
        if (!i_rst_b) begin
            for (int i = 0; i < PIPE; i++) begin
                pipe[i] <= 1'b0;
            end
        end else begin
            pipe[0] <= toggle;

            for (int i = 1; i < PIPE; i++) begin
                pipe[i] <= pipe[i - 1];
            end
        end
    end

    //! Edge detection in destination clock domain
    assign o_req = pipe[PIPE - 1] ^ pipe[PIPE - 2];

endmodule