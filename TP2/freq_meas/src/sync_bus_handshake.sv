//! @title Synchronized Bus Handshake
//! @brief Transfers a stable multibit bus between asynchronous clock domains.
//!
//! The module transfers i_src_data from the source clock domain to the
//! destination clock domain using a bundled-data four-phase handshake.
//!
//! The source must present a stable value on i_src_data and assert
//! i_src_valid. The request is synchronized into the destination domain.
//! When the synchronized request is detected, the destination captures the
//! bus into o_dst_data, asserts o_dst_valid for one i_dst_clk cycle, and raises
//! an acknowledge signal.
//!
//! The acknowledge is synchronized back into the source domain and exposed
//! through o_src_ready. After observing o_src_ready, the source must
//! deassert i_src_valid. The handshake returns to the idle state once the
//! deasserted request reaches the destination and the acknowledge returns low.
//!
//! Four-phase handshake sequence:
//!
//!     1. i_src_valid  : 0 -> 1
//!     2. o_src_ready  : 0 -> 1
//!     3. i_src_valid  : 1 -> 0
//!     4. o_src_ready  : 1 -> 0
//!
//! Source-side requirements:
//!
//!     - i_src_data must be valid before i_src_valid is asserted.
//!     - i_src_data must remain stable until o_src_ready is asserted.
//!     - i_src_valid must remain asserted until o_src_ready is observed.
//!
//! Destination-side behavior:
//!
//!     - o_dst_data is registered in the i_dst_clk domain.
//!     - o_dst_valid is asserted for one i_dst_clk cycle when a new transfer
//!       is captured.
//!     - o_dst_data remains stable after the transfer until a new transaction.
//!
//! @param DATA_W Width of the transferred data bus.
//! @param PIPE   Number of synchronization stages used for request and
//!               acknowledge signals. PIPE must be at least 2.
//!
//! @note Only the single-bit request and acknowledge signals are passed
//! through synchronizer chains. The multibit bus is transferred directly,
//! relying on the bundled-data requirement that i_src_data remains stable
//! throughout the handshake.

`timescale 1ns/1ps

module sync_bus_handshake #(
    parameter int DATA_W = 20,
    parameter int PIPE   = 2
) (
    //! Source clock domain
    input  logic                  i_src_clk,
    input  logic                  i_src_rst_n,
    input  logic [DATA_W - 1 : 0] i_src_data,
    input  logic                  i_src_valid,
    output logic                  o_src_ready,

    //! Destination clock domain
    input  logic                  i_dst_clk,
    input  logic                  i_dst_rst_n,
    output logic [DATA_W - 1 : 0] o_dst_data,
    output logic                  o_dst_valid
);
    //! Source clock domain signals
    logic ack_src;

    //! Destination clock domain signals
    logic [DATA_W - 1 : 0] data_dst_r;
    logic ack_dst_r;
    logic dst_valid_r;
    logic req_dst;
    logic w_dst_en;
    
    sync_level #(
        .PIPE(PIPE)
    ) u_sync_valid (
        .i_clk   (i_dst_clk),
        .i_rst_n (i_dst_rst_n),
        .i_data  (i_src_valid),
        .o_data  (req_dst)
    );
 
    rise_detector u_rise_detector(
        .i_clk    (i_dst_clk),
        .i_rst_n  (i_dst_rst_n),
        .i_signal (req_dst),
        .o_flag   (w_dst_en)
    );

    always_ff @(posedge i_dst_clk) begin
        if (!i_dst_rst_n) begin
            data_dst_r  <= '0;
            ack_dst_r   <= 1'b0;
            dst_valid_r <= 1'b0;
        end else begin
            //! o_dst_valid is a one-cycle pulse
            dst_valid_r <= w_dst_en;

            //! Capture a new word when the synchronized request rises
            if (w_dst_en) begin
                data_dst_r <= i_src_data;
            end

            //! Keep acknowledge asserted while the request remains active
            if (w_dst_en) begin
                ack_dst_r <= 1'b1;
            end else if (!req_dst) begin
                ack_dst_r <= 1'b0;
            end
        end
    end

    sync_level #(
        .PIPE(PIPE)
    ) u_sync_ready (
        .i_clk   (i_src_clk),
        .i_rst_n (i_src_rst_n),
        .i_data  (ack_dst_r),
        .o_data  (ack_src)
    );

    assign o_src_ready = ack_src;
    assign o_dst_data  = data_dst_r;
    assign o_dst_valid = dst_valid_r;

endmodule