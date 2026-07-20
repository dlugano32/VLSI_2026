//! @title Frequency Measurement
//! @brief One-shot frequency meter based on a programmable reference-clock window.
//!
//! The module measures the frequency of i_clk_in by counting its rising edges
//! during a programmable window of i_window_len cycles of i_clk_ref.
//!
//! The measurement starts automatically after reset. When the window closes,
//! the final input-clock count is transferred to the i_clk_ref domain through
//! a bus handshake. The result is stored in o_count and o_done is asserted for
//! one i_clk_ref cycle when the result becomes valid.
//!
//! Measurement window duration:
//!
//!     T_window = i_window_len / f_ref
//!
//! Expected input-clock count:
//!
//!     N_count = i_window_len * f_in / f_ref
//!
//! Frequency resolution represented by one counter increment:
//!
//!     delta_f = f_ref / i_window_len
//!
//! Relative resolution in parts per million:
//!
//!     resolution_ppm = 1_000_000 / N_count
//!
//! For a target resolution of P ppm at an input frequency f_in:
//!
//!     i_window_len >= (1_000_000 / P) * (f_ref / f_in)
//!
//! The window input width must be large enough to represent the selected
//! measurement-window length:
//!
//!     WIN_W >= ceil(log2(i_window_len + 1))
//!
//! The input counter width must be large enough to represent the maximum
//! expected count:
//!
//!     CNT_W >= ceil(log2(N_count_max + 1))
//!
//! Example for the required 1 ppm resolution:
//!
//!     f_ref        = 200 MHz
//!     f_in         = 750 MHz
//!     P            = 1 ppm
//!     i_window_len = 266_667
//!
//!     T_window = 266_667 / 200 MHz
//!              = approximately 1.333 ms
//!
//!     N_count = 266_667 * 750 MHz / 200 MHz
//!             = approximately 1_000_001
//!
//! WIN_W = 19 is sufficient to represent 266_667, while CNT_W = 20
//! is sufficient to represent a count close to 1_000_000.
//!
//! @param WIN_W Width of the programmable reference-window input.
//! @param CNT_W Width of the input-clock edge counter and output count.
//!
//! @note The module performs one measurement after reset. The final result
//! remains stored in o_count until the next reset.

`timescale 1ns/1ps

module freq_meas #(
    parameter int WIN_W = 19,
    parameter int CNT_W = 20
) (
    output logic [CNT_W - 1 : 0] o_count,
    output logic                 o_done,

    input  logic [WIN_W - 1 : 0] i_window_len,
    input  logic                 i_rst_n,
    input  logic                 i_clk_ref,
    input  logic                 i_clk_in
);

    //! Local reset signals
    logic rst_ref_n;
    logic rst_in_n;

    //! Reference-clock domain signals
    logic [WIN_W - 1 : 0] window_cnt_r;
    logic [WIN_W - 1 : 0] window_cnt_next;

    logic window_open_ref_r;
    logic window_open_ref_next;

    //! Input-clock domain signals
    logic window_open_in;
    logic window_close_in;

    logic transfer_req_r;
    logic transfer_ack;

    logic [CNT_W - 1 : 0] input_cnt_r;
    logic [CNT_W - 1 : 0] input_cnt_next;

    //! Synchronize reset deassertion into the reference-clock domain
    rst_n_sync #(
        .PIPE(2)
    ) u_rst_sync_ref (
        .i_clk   (i_clk_ref),
        .i_rst_n (i_rst_n),
        .o_rst_n (rst_ref_n)
    );

    //! Synchronize reset deassertion into the input-clock domain
    rst_n_sync #(
        .PIPE(2)
    ) u_rst_sync_in (
        .i_clk   (i_clk_in),
        .i_rst_n (i_rst_n),
        .o_rst_n (rst_in_n)
    );

    //! Reference-clock domain registers
    always_ff @(posedge i_clk_ref) begin
        if (!rst_ref_n) begin
            window_cnt_r      <= '0;
            window_open_ref_r <= 1'b1;
        end else begin
            window_cnt_r      <= window_cnt_next;
            window_open_ref_r <= window_open_ref_next;
        end
    end

    //! Reference window counter
    assign window_cnt_next = window_open_ref_r ? window_cnt_r + 1'b1 : window_cnt_r;

    //! Keep the measurement window open for i_window_len reference cycles
    assign window_open_ref_next = window_cnt_r < (i_window_len - 1'b1);

    //! Synchronize the measurement window into the input-clock domain
    sync_level #(
        .PIPE(2)
    ) u_sync_window (
        .i_clk   (i_clk_in),
        .i_rst_n (rst_in_n),
        .i_data  (window_open_ref_r),
        .o_data  (window_open_in)
    );

    //! Input-clock domain counter register
    always_ff @(posedge i_clk_in) begin
        if (!rst_in_n) begin
            input_cnt_r <= '0;
        end else begin
            input_cnt_r <= input_cnt_next;
        end
    end

    //! Count input-clock edges while the synchronized window is open
    assign input_cnt_next = window_open_in ? input_cnt_r + 1'b1 : input_cnt_r;

    //! Event detector for the synchronized window close event
    fall_detector u_fall_detector (
        .i_clk    (i_clk_in),
        .i_rst_n  (rst_in_n),
        .i_signal (window_open_in),
        .o_flag   (window_close_in)
    );

    always_ff @(posedge i_clk_in) begin
        if (!rst_in_n) begin
            transfer_req_r <= 1'b0;
        end else if (window_close_in) begin
            transfer_req_r <= 1'b1;
        end else if (transfer_ack) begin
            transfer_req_r <= 1'b0;
        end
    end

    sync_bus_handshake #(
        .DATA_W(CNT_W)
    ) u_sync_count (
        .i_src_clk   (i_clk_in),
        .i_src_rst_n (rst_in_n),
        .i_src_data  (input_cnt_r),
        .i_src_valid (transfer_req_r),
        .o_src_ready (transfer_ack),

        .i_dst_clk   (i_clk_ref),
        .i_dst_rst_n (rst_ref_n),
        .o_dst_data  (o_count),
        .o_dst_valid (o_done)
    );

endmodule