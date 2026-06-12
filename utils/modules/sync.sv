//! @title Fast-to-Slow Clock Domain Request Synchronizer
//! @file sync.sv
//! @author Damian Lugano
//! @date 12-6-2026
//!
//! @brief Clock-domain crossing synchronizer for request pulses from a fast
//! clock domain to a slower clock domain.
//!
//! This module transfers request events from clock domain `i_clk_a` to clock
//! domain `i_clk_b` using a toggle-based synchronization scheme.
//!
//! @details
//! - The source clock domain is `i_clk_a`.
//! - The destination clock domain is `i_clk_b`.
//! - A pulse on `i_req` toggles an internal register in the source domain.
//! - The toggle signal is passed through a synchronization pipeline clocked by
//!   `i_clk_b`.
//! - A request pulse is generated in the destination domain by detecting a
//!   transition between the last two synchronization stages.
//! - The synchronization pipeline depth is configurable through `PIPE`.
//! - Increasing `PIPE` adds destination-clock flip-flop stages, which reduces
//!   the probability that metastability propagates to the output logic.
//!
//! @note
//! Since this module transfers events using a toggle, two or more request
//! pulses occurring too close together in the source domain may be missed by
//! the destination domain if the slower clock does not sample each toggle
//! transition.
//!
//! @param PIPE  Number of synchronization pipeline stages in the destination
//!              clock domain. Must be at least 2.
//!
//! @input  i_clk_a  Source clock.
//! @input  i_clk_b  Destination clock.
//! @input  i_rst_a  Synchronous reset for the source clock domain.
//! @input  i_rst_b  Synchronous reset for the destination clock domain.
//! @input  i_req    Request pulse in the source clock domain.
//!
//! @output o_req    Request pulse synchronized to the destination clock domain.

`timescale 1ns/1ps

module sync #(
    parameter int PIPE = 4
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
    always_ff @(posedge i_clk_a) begin : src_toggle
        if (i_rst_a) begin
            toggle <= 1'b0;
        end else if (i_req) begin
            toggle <= ~toggle;
        end
    end

    //! Toggle synchronization into destination clock domain
    always_ff @(posedge i_clk_b) begin : dst_pipe
        if (i_rst_b) begin
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