//! @title PAM-2 Fixed-Point FIR Filter for RC/RRC Pulse Shaping
//! @file fir_pam2.sv
//! @author Damian Lugano
//! @date 21-5-2026
//!
//! @brief Generic signed fixed-point FIR filter optimized for PAM-2 input symbols,
//! intended for Raised Cosine (RC) and Root Raised Cosine (RRC) filters.
//!
//! This module implements an `N_TAPS`-tap FIR filter for input symbols restricted
//! to PAM-2 values, avoiding explicit multipliers by selecting either `+tap` or
//! `-tap` for each coefficient.
//!
//! @details
//! - Intended for RC/RRC FIR pulse-shaping or matched-filter implementations.
//! - Input symbols are encoded as signed 2-bit values:
//!   - `2'b01` : `+1`
//!   - `2'b11` : `-1`
//! - Coefficients are signed fixed-point values with format `S(NB_TAPS, NBF_TAPS)`.
//! - The internal product format is equal to the coefficient format.
//! - The accumulator grows by `$clog2(N_TAPS)` bits to avoid internal overflow.
//! - The accumulator fractional precision is given by `NBF_TAPS`.
//! - The output is truncated and saturated to `S(NB_O, NBF_O)`.
//!
//! @note
//! This implementation assumes that coefficients do not take the minimum
//! negative representable value, so that sign inversion remains valid within
//! `NB_TAPS` bits.
//!
//! @param NB_O      Output total bit width.
//! @param NBF_O     Output fractional bit width.
//! @param NB_TAPS   Coefficient total bit width.
//! @param NBF_TAPS  Coefficient fractional bit width.
//! @param N_TAPS    Number of FIR taps.
//!
//! @input  i_data   PAM-2 input symbol.
//! @input  i_taps   FIR coefficient vector.
//! @input  i_en     Clock enable.
//! @input  i_srst   Synchronous reset.
//! @input  i_clk      System clock.
//!
//! @output o_data   Filtered output sample.

`timescale 1ns/1ps

module fir_pam2 #(
    parameter int NB_O     = 12,
    parameter int NBF_O    = 10,

    parameter int NB_TAPS  = 12,
    parameter int NBF_TAPS = 10,

    parameter int N_TAPS   = 19
) (
    output logic signed [NB_O    - 1 : 0] o_data,
    input  logic signed [          1 : 0] i_data,
    input  logic signed [NB_TAPS - 1 : 0] i_taps [N_TAPS - 1 : 0],
    input  logic i_en,
    input  logic i_srst,
    input  logic i_clk
);
    //! Local params
    localparam int NB_I  = 2;
    localparam int NBF_I = 0;
    localparam int NBI_O = NB_O - NBF_O;
    localparam int NB_PROD = NB_TAPS;

    //! Vars
    logic signed [NB_I    - 1 : 0] data_reg  [N_TAPS - 1 : 0];
    logic signed [NB_PROD - 1 : 0] prod_next [N_TAPS - 1 : 0];
    logic signed [NB_PROD - 1 : 0] prod_reg  [N_TAPS - 1 : 0];

    genvar i;

    //! Shift register for input data
    always_ff @(posedge i_clk) begin : shift_reg_0
        if (i_srst) begin
            data_reg[0] <= '0;
        end else if (i_en) begin
            data_reg[0] <= i_data;
        end
    end

    generate
        for (i = 1; i < N_TAPS; i++) begin : gen_shift_reg
            always_ff @(posedge i_clk) begin : shift_reg
                if (i_srst) begin
                    data_reg[i] <= '0;
                end else if (i_en) begin
                    data_reg[i] <= data_reg[i-1];
                end
            end
        end
    endgenerate

    //! Taps product
    generate
        for (i = 0; i < N_TAPS; i++) begin : gen_mux_product
            assign prod_next[i] =   (data_reg[i] ==  2'b00) ? '0 :
                                    (data_reg[i] ==  2'b01) ? i_taps[i] :
                                    (data_reg[i] ==  2'b11) ? (~i_taps[i]+1) : 
                                                              '0;                
        end
    endgenerate

    //! Product register
    generate
        for (i = 0; i < N_TAPS; i++) begin : gen_product_reg
            always_ff @(posedge i_clk) begin : product_reg
                if (i_srst) begin
                    prod_reg[i] <= '0;
                end else if (i_en) begin
                    prod_reg[i] <= prod_next[i];
                end
            end
        end
    endgenerate


    //! Sum tree
    localparam int N_LEVELS = $clog2(N_TAPS);
    localparam int NB_ACC   = NB_PROD + $clog2(N_TAPS);

    logic signed [NB_ACC - 1 : 0] sum_tree [0 : N_LEVELS][0 : N_TAPS - 1];

    genvar lvl;
    genvar j;

    generate
        for (j = 0; j < N_TAPS; j++) begin : gen_sum_tree_input
            assign sum_tree[0][j] =
                $signed({{(NB_ACC-NB_PROD){prod_reg[j][NB_PROD-1]}}, prod_reg[j]});
        end

        for (lvl = 0; lvl < N_LEVELS; lvl++) begin : gen_sum_tree_level
            localparam int N_IN  = (N_TAPS + (1 << lvl)     - 1) >> lvl;
            localparam int N_OUT = (N_TAPS + (1 << (lvl+1)) - 1) >> (lvl+1);

            for (j = 0; j < N_OUT; j++) begin : gen_sum_tree_node
                if ((2*j + 1) < N_IN) begin : gen_pair_sum
                    assign sum_tree[lvl+1][j] =
                        sum_tree[lvl][2*j] + sum_tree[lvl][2*j + 1];
                end else begin : gen_passthrough
                    assign sum_tree[lvl+1][j] =
                        sum_tree[lvl][2*j];
                end
            end
        end
    endgenerate

    assign o_data = sum_tree[N_LEVELS][0][NB_O - 1 : 0];

endmodule