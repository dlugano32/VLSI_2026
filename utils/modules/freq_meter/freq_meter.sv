//! @title Frequency Meter
//! @brief One-shot frequency meter based on a reference-clock window.
//!
//! The module measures the frequency of i_clk_in by counting its rising
//! edges during a window of W_MAX cycles of i_clk_ref.
//!
//! The measurement starts automatically after reset. When the window ends,
//! o_cnt holds the measured number of input-clock cycles and o_done remains
//! asserted until the module is reset again.
//!
//! Measurement window duration:
//!
//!     T_window = W_MAX / f_ref
//!
//! Expected input count:
//!
//!     N_count = W_MAX * f_in / f_ref
//!
//! Frequency resolution represented by one counter increment:
//!
//!     delta_f = f_ref / W_MAX
//!
//! For a target relative resolution of P ppm at a frequency f_in:
//!
//!     W_MAX >= (1_000_000 / P) * (f_ref / f_in)
//!
//! The input counter width must be large enough to represent the maximum
//! expected count:
//!
//!     CNT_W >= ceil(log2(N_count_max + 1))
//!
//! Example:
//!
//!     f_ref = 10 MHz
//!     f_in  = 100 MHz
//!     P     = 1 ppm
//!
//!     W_MAX = 100_000
//!     T_window = 10 ms
//!     N_count = 1_000_000
//!
//! A 20-bit unsigned counter can represent values from 0 to 1_048_575,
//! therefore CNT_W = 20 is sufficient for this example.
//!
//! @param W_MAX Number of reference-clock cycles in the measurement window.
//! @param CNT_W Width of the input-clock cycle counter.
//!
//! @note The actual measurement accuracy is also limited by the accuracy of
//! the reference clock and by clock-domain crossing uncertainty.
//!
//! @note This module performs one measurement after reset. A new measurement
//! requires resetting both clock domains.

`timescale 1ns/1ps

module freq_meter #(
    parameter int W_MAX = 100_000,
    parameter int CNT_W = 20
) (
    output logic [CNT_W - 1 : 0] o_cnt,
    output logic                 o_done,

    input  logic i_rst_in,
    input  logic i_rst_ref,

    input  logic i_clk_ref,
    input  logic i_clk_in
);

    localparam int REF_CNT_W = $clog2(W_MAX+1);

    //! Reference-clock domain signals
    logic [REF_CNT_W - 1 : 0] cnt_ref_r;
    logic                     running_ref_r;
    logic                     done_ref_r;

    logic [REF_CNT_W - 1 : 0] cnt_ref_next;
    logic                     running_ref_next;
    logic                     done_ref_next;

    //! Synchronized control signals
    logic en_in;

    //! Input-clock domain counter
    logic [CNT_W - 1 : 0] cnt_in_r;
    logic [CNT_W - 1 : 0] cnt_in_next;

    //! Generate a one-shot measurement window in the reference-clock domain
    always_ff @(posedge i_clk_ref) begin
        if(i_rst_ref) begin
            cnt_ref_r     <= '0;
            running_ref_r <= '1;
            done_ref_r    <= '0;
        end else begin
            cnt_ref_r     <= cnt_ref_next;
            running_ref_r <= running_ref_next;
            done_ref_r    <= done_ref_next;
        end
    end

    assign cnt_ref_next = (running_ref_r) ? (cnt_ref_r + 1) : cnt_ref_r;
    assign running_ref_next = (cnt_ref_r < (W_MAX-1));
    assign done_ref_next = (cnt_ref_r == W_MAX);

    //! Synchronize the measurement window into the input-clock domain
    sync #(
        .PIPE(2)
    ) u_sync_window (
        .i_clk  (i_clk_in),
        .i_rst  (i_rst_in),
        .i_data (running_ref_r),
        .o_data (en_in)
    );

    //! Synchronize the persistent done level into the input-clock domain
    sync #(
        .PIPE(2)
    ) u_sync_done (
        .i_clk  (i_clk_in),
        .i_rst  (i_rst_in),
        .i_data (done_ref_r),
        .o_data (o_done)
    );

    //! Count input-clock cycles while the synchronized window is active
    always_ff @(posedge i_clk_in) begin
        if (i_rst_in) begin
            cnt_in_r <= '0;
        end else begin
            cnt_in_r <= cnt_in_next;
        end
    end

    assign cnt_in_next = (en_in) ? (cnt_in_r + 1) : cnt_in_r;

    //! Expose the measured count
    assign o_cnt = cnt_in_r;

endmodule