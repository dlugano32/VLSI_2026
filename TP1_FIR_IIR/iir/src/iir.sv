//! @title Fixed-Point First-Order IIR DC Blocker
//! @file iir.sv
//! @author Damian Lugano
//! @date 30-5-2026
//!
//! @brief Generic signed fixed-point first-order IIR high-pass filter,
//! intended for DC offset removal.
//!
//! This module implements a first-order IIR DC blocker with transfer function:
//!
//!     H(z) = (1 - z^-1) / (1 - a z^-1)
//!
//! using the difference equation:
//!
//!     y[n] = x[n] - x[n-1] + a y[n-1]
//!
//! @details
//! - Intended for DC removal in sampled fixed-point signals.
//! - The input format is fixed to signed `S(8,7)`.
//! - The output format is configurable as `S(NB_O, NBF_O)`.
//! - The feedback coefficient `a` is configurable as `S(NB_A, NBF_A)`.
//! - The previous input sample `x[n-1]` is stored with input precision.
//! - The previous output sample `y[n-1]` is stored with output precision.
//! - The input difference is computed as:
//!   - `S(8,7) - S(8,7) -> S(9,7)`.
//! - The feedback product is computed as:
//!   - `S(NB_A,NBF_A) * S(NB_O,NBF_O) -> S(NB_A+NB_O, NBF_A+NBF_O)`.
//! - The input difference is resized to the feedback product format before
//!   accumulation.
//! - The accumulator grows by one bit to avoid immediate overflow in the sum.
//! - The final result is rounded and saturated to `S(NB_O, NBF_O)` using
//!   `roundNsat`.
//!
//!
//! @param NB_O   Output total bit width.
//! @param NBF_O  Output fractional bit width.
//! @param NB_A   Feedback coefficient total bit width.
//! @param NBF_A  Feedback coefficient fractional bit width.
//!
//! @input  i_data  Input sample in signed `S(8,7)` format.
//! @input  i_a     Feedback coefficient `a`.
//! @input  i_en    Clock enable.
//! @input  i_srst  Synchronous reset.
//! @input  i_clk   System clock.
//!
//! @output o_data  Filtered output sample.

`timescale 1ns/1ps

module iir #(
    parameter int NB_O  = 8,
    parameter int NBF_O = 7,
    parameter int NB_A  = 8,
    parameter int NBF_A = 7
) (
    output logic signed [NB_O - 1 : 0] o_data,
    input  logic signed [7        : 0] i_data,
    input  logic signed [NB_A - 1 : 0] i_a, //! a = 0.98 = 8'h7D
    input  logic i_en,
    input  logic i_srst,
    input  logic i_clk
);

    //! Input format
    localparam int NB_I   = 8;
    localparam int NBF_I  = 7;

    //! Internal format: S(16,14)
    localparam int NB_FB  = NB_O + NB_A;
    localparam int NBF_FB = NBF_O + NBF_A;

    //! Registers
    logic signed [NB_I  - 1 : 0] x1_reg;
    logic signed [NB_O  - 1 : 0] y1_reg;

    //! Combinational signals
    logic signed [NB_I        : 0] diff;
    logic signed [NB_FB   - 1 : 0] diff_ext;

    logic signed [NB_FB   - 1 : 0] feedback;

    logic signed [NB_FB       : 0] y_sum;
    logic signed [NB_O    - 1 : 0] y_next;

    //! y[n] = x[n] - x[n-1] + a y[n-1]

    always_ff @(posedge i_clk) begin : regs
        if (i_srst) begin
            x1_reg <= '0;
            y1_reg <= '0;
        end else if (i_en) begin
            x1_reg <= i_data;
            y1_reg <= y_next;
        end
    end

    //! diff = x[n] - x[n-1]
    //! S(8,7) - S(8,7) -> S(9,7)
    assign diff = $signed({i_data[NB_I - 1], i_data}) -
                  $signed({x1_reg[NB_I - 1], x1_reg});

    //! diff_ext = diff resized to S(16,14)
    assign diff_ext = $signed({diff, {(NBF_FB - NBF_I){1'b0}}});
    
    //! feedback = a * y[n-1]
    //! S(8,7) * S(8,7) -> S(16,14)
    assign feedback = i_a * y1_reg;

    //! y_sum = x[n] - x[n-1] + a y[n-1] = diff_ext + feedback
    //! y_sum = S(16,14) + S(16,14) -> S(17,14)
    assign y_sum = $signed({diff_ext[NB_FB - 1] , diff_ext}) + 
                   $signed({feedback[NB_FB - 1], feedback});
    
    //! S(17,14) -> S(8,7)
    roundNsat #(
        .NB_I   (NB_FB + 1),
        .NBF_I  (NBF_FB),
        .NB_O   (NB_O),
        .NBF_O  (NBF_O)
    ) u_roundNsat_sum (
        .i_data (y_sum),
        .o_data (y_next)
    );

    assign o_data = y_next;

endmodule