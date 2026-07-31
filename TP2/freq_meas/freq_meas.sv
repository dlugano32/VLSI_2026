//! @title Frequency Measurement
//! @brief Programmable frequency meter with independent reference and input clocks.
//!
//! Measurement sequence:
//!
//!     1. Assert i_start for one i_clk_ref cycle.
//!     2. The module stores i_window_len and opens the measurement window.
//!     3. Rising edges of i_clk_in are counted while the synchronized window remains open.
//!     4. When the window closes, the count is frozen.
//!     5. o_done is asserted and remains high until a new measurement starts.
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
//! The window-length width must satisfy:
//!
//!     WIN_W >= ceil(log2(i_window_len + 1))
//!
//! The input counter width must satisfy:
//!
//!     CNT_W >= ceil(log2(N_count_max + 1))
//!
//! Example for a target resolution of approximately 1 ppm:
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
//! @param WIN_W Width of the programmable reference-clock window.
//! @param CNT_W Width of the input-clock edge counter and output count.
//!
//! @note i_start must be a one-cycle pulse synchronous to i_clk_ref.
//! @note i_window_len must be greater than zero.
//! @note A new i_start must not be asserted while a measurement is active.
//! @note o_count is only valid while o_done is asserted.
//! @note The first synchronized input-clock edge is used to clear the counter
//!       and is therefore not included in the reported count.

`timescale 1ns/1ps

module freq_meas #(
    parameter int WIN_W = 19,
    parameter int CNT_W = 20
) (
    output logic [CNT_W - 1 : 0] o_count,       //! Stable and valid while o_done is high
    output logic                 o_done,        //! Will be up when count finishes until a new measurement request

    input  logic [WIN_W - 1 : 0] i_window_len,
    input  logic                 i_start,       //! One-cycle pulse synchronous to i_clk_ref
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

    logic [WIN_W - 1 : 0] window_len_r;
    logic                 done_ref;

    //! Input-clock domain signals
    logic window_open_in;
    logic window_start_in;
    logic window_close_in;

    logic [CNT_W - 1 : 0] input_cnt_r;
    logic                 done_in_r;

    //! Asynchronous assertion and synchronous release in the reference domain
    rst_n_sync #(
        .PIPE(2)
    ) u_rst_sync_ref (
        .i_clk   (i_clk_ref),
        .i_rst_n (i_rst_n),
        .o_rst_n (rst_ref_n)
    );

    //! Asynchronous assertion and synchronous release in the input domain
    rst_n_sync #(
        .PIPE(2)
    ) u_rst_sync_in (
        .i_clk   (i_clk_in),
        .i_rst_n (i_rst_n),
        .o_rst_n (rst_in_n)
    );

    //! =========================================================================
    //! Reference-clock domain
    //! =========================================================================

    //! Store the programmed window length for the complete measurement
    always_ff @(posedge i_clk_ref) begin
        if (!rst_ref_n) begin
            window_len_r <= '0;
        end else if (i_start) begin
            window_len_r <= i_window_len;
        end
    end

    //! Start a new reference window and count its elapsed cycles
    always_ff @(posedge i_clk_ref) begin
        if (!rst_ref_n) begin
            window_cnt_r      <= '0;
            window_open_ref_r <= 1'b0;
        end else if (i_start) begin
            //! A new start invalidates the previous result and opens a new window
            window_cnt_r      <= '0;
            window_open_ref_r <= 1'b1;
        end else begin
            window_cnt_r      <= window_cnt_next;
            window_open_ref_r <= window_open_ref_next;
        end
    end

    //! Keep the window open until the programmed number of cycles has elapsed
    assign window_open_ref_next = (window_cnt_r < (window_len_r - 1'b1))
                                 ? window_open_ref_r
                                 : 1'b0;

    //! Freeze the reference counter after the measurement window closes
    assign window_cnt_next = window_open_ref_r
                             ? window_cnt_r + 1'b1
                             : window_cnt_r;

    //! Transfer the persistent window level into the input-clock domain
    sync_level #(
        .PIPE(2)
    ) u_sync_window (
        .i_clk   (i_clk_in),
        .i_rst_n (rst_in_n),
        .i_data  (window_open_ref_r),
        .o_data  (window_open_in)
    );

    //! =========================================================================
    //! Input-clock domain
    //! =========================================================================

    //! Generate a one-cycle pulse when the synchronized window opens
    rise_detector u_rise_detector (
        .i_clk    (i_clk_in),
        .i_rst_n  (rst_in_n),
        .i_signal (window_open_in),
        .o_flag   (window_start_in)
    );

    //! Generate a one-cycle pulse when the synchronized window closes
    fall_detector u_fall_detector (
        .i_clk    (i_clk_in),
        .i_rst_n  (rst_in_n),
        .i_signal (window_open_in),
        .o_flag   (window_close_in)
    );

    //! Count input-clock edges and freeze the result when the window closes
    always_ff @(posedge i_clk_in) begin
        if (!rst_in_n) begin
            input_cnt_r <= '0;
        end else if (window_start_in) begin
            //! Clear the previous result at the beginning of a new measurement
            input_cnt_r <= '0;
        end else if (window_open_in) begin
            input_cnt_r <= input_cnt_r + 1'b1;
        end
    end

    //! Keep done asserted while the frozen input count remains available
    always_ff @(posedge i_clk_in) begin
        if (!rst_in_n) begin
            done_in_r <= 1'b0;
        end else if (window_start_in) begin
            //! The previous result is no longer valid
            done_in_r <= 1'b0;
        end else if (window_close_in) begin
            //! The counter is now frozen and safe to read
            done_in_r <= 1'b1;
        end
    end

    //! Transfer the persistent result-valid level back to the reference domain
    sync_level #(
        .PIPE(2)
    ) u_sync_done (
        .i_clk   (i_clk_ref),
        .i_rst_n (rst_ref_n),
        .i_data  (done_in_r),
        .o_data  (done_ref)
    );

    //! Force done low immediately when a new reference window is opened
    assign o_done = done_ref && !window_open_ref_r;

    //! Bundled-data CDC: the counter remains frozen whenever o_done is high
    assign o_count = input_cnt_r;

endmodule
