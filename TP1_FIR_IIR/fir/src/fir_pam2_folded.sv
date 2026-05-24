//! @title Folded PAM-2 Fixed-Point FIR Filter for RC/RRC Pulse Shaping
//! @file fir_pam2_folded.sv
//! @author Damian Lugano
//! @date 21-5-2026
//!
//! @brief Multiplierless folded FIR filter for PAM-2 input symbols and symmetric coefficients.
//!
//! This module implements an `N_TAPS`-tap signed fixed-point FIR filter optimized
//! for PAM-2 symbols and symmetric RC/RRC coefficients. The folded architecture
//! exploits coefficient symmetry by pre-adding symmetric input samples and using
//! a reduced coefficient set of `(N_TAPS + 1) / 2` taps.
//!
//! @details
//! - Intended for Raised Cosine (RC) and Root Raised Cosine (RRC) FIR filters.
//! - Input symbols are encoded as signed 2-bit values:
//!   - `2'b01` : `+1`
//!   - `2'b11` : `-1`
//! - Coefficients are assumed symmetric.
//! - Only the first `(N_TAPS + 1) / 2` coefficients are provided.
//! - Symmetric input pairs are pre-added before coefficient scaling.
//! - Pair products are implemented without multipliers using sign selection and shifts:
//!   - `3'b010` : `+2h`
//!   - `3'b001` : `+h`
//!   - `3'b000` : `0`
//!   - `3'b111` : `-h`
//!   - `3'b110` : `-2h`
//! - Any other input value is treated as zero.
//! - For odd `N_TAPS`, the center tap only uses `-h`, `0`, and `+h`.
//! - Product width is extended by one bit to represent `±2h`.
//! - The accumulator grows by `$clog2((N_TAPS + 1) / 2)` bits.
//! - The output is truncated and saturated to `S(NB_O, NBF_O)`.
//!
//! @note
//! This implementation assumes that coefficients do not take the minimum
//! negative representable value, so that sign inversion remains valid.
//!
//! @param NB_O      Output total bit width.
//! @param NBF_O     Output fractional bit width.
//! @param NB_TAPS   Coefficient total bit width.
//! @param NBF_TAPS  Coefficient fractional bit width.
//! @param N_TAPS    Number of FIR taps.
//!
//! @input  i_data   PAM-2 input symbol.
//! @input  i_taps   Reduced symmetric coefficient vector.
//! @input  i_en     Clock enable.
//! @input  i_srst   Synchronous reset.
//! @input  clk      System clock.
//!
//! @output o_data   Filtered output sample.


module fir_pam2_folded #(
    parameter int NB_O     = 12,
    parameter int NBF_O    = 10,

    parameter int NB_TAPS  = 12,
    parameter int NBF_TAPS = 10,

    parameter int N_TAPS   = 19
) (
    output logic signed [NB_O    - 1 : 0] o_data,
    input  logic signed [          1 : 0] i_data,   //! Entrada en formato PAM-2
    input  logic signed [NB_TAPS - 1 : 0] i_taps [((N_TAPS + 1) / 2) - 1 : 0],    
    input  logic i_en,   //! Enable
    input  logic i_srst, //! Reset
    input  logic clk     //! Clock
);

    localparam int NB_I     = 2;
    localparam int NBF_I    = 0;
    localparam int N_PAIRS  =  N_TAPS / 2;
    localparam int N_PREADD = (N_TAPS + 1) / 2;
    localparam int NB_PROD  =  NB_TAPS + 1;     // Product width is extended by one bit to represent `±2h`.
    localparam int NBF_PROD =  NBF_TAPS;
    localparam int NB_ACC   =  NB_PROD + $clog2(N_PREADD);
    localparam int NBF_ACC  =  NBF_PROD;

    //! Vars
    logic signed [NB_I    - 1 : 0] data_reg  [N_TAPS   - 1 : 0];
    logic signed [NB_I        : 0] pre_add_w [N_PREADD - 1 : 0];
    logic signed [NB_PROD - 1 : 0] prod_next [N_PREADD - 1 : 0];
    logic signed [NB_PROD - 1 : 0] prod_reg  [N_PREADD - 1 : 0];
    logic signed [NB_PROD - 1 : 0] taps_ext  [N_PREADD - 1 : 0];
    logic signed [NB_ACC  - 1 : 0] acc_full_w;

    genvar i;

    //! Shift register for input data
    always_ff @(posedge clk) begin : shift_reg_0
        if (i_srst) begin
            data_reg[0] <= '0;
        end else if (i_en) begin
            data_reg[0] <= i_data;
        end
    end

    generate
        for (i = 1; i < N_TAPS; i++) begin : gen_shift_reg
            always_ff @(posedge clk) begin : shift_reg
                if (i_srst) begin
                    data_reg[i] <= '0;
                end else if (i_en) begin
                    data_reg[i] <= data_reg[i-1];
                end
            end
        end
    endgenerate

    //! Pre-adders
    generate
        for (i = 0; i < N_PREADD; i++) begin : gen_pre_adders

            if (i < N_PAIRS) begin : gen_symmetric_pair

                assign pre_add_w[i] =
                    {data_reg[i][NB_I-1], data_reg[i]}
                + {data_reg[N_TAPS-1-i][NB_I-1], data_reg[N_TAPS-1-i]};

            end else begin : gen_center_tap

                assign pre_add_w[i] =
                    {data_reg[i][NB_I-1], data_reg[i]};
            end
        end
    endgenerate

    //! Taps product with pre-added inputs
    generate
        for (i = 0; i < N_PREADD; i++) begin : gen_mux_product
            
            assign taps_ext[i] = {{(NB_PROD-NB_TAPS){i_taps[i][NB_TAPS-1]}}, i_taps[i]};

            if (i < N_PAIRS) begin : gen_mux_product_pair

                assign prod_next[i] =   (pre_add_w[i] ==  3'b000) ? '0 :
                                        (pre_add_w[i] ==  3'b001) ? taps_ext[i] :
                                        (pre_add_w[i] ==  3'b010) ? taps_ext[i] <<< 1 :
                                        (pre_add_w[i] ==  3'b110) ? (~taps_ext[i] + 1) <<< 1 :
                                        (pre_add_w[i] ==  3'b111) ? (~taps_ext[i] + 1) :
                                                                    '0;

            end else begin : gen_mux_product_center

                assign prod_next[i] =   (pre_add_w[i] ==  3'b000) ? '0 :
                                        (pre_add_w[i] ==  3'b001) ? taps_ext[i] :
                                        (pre_add_w[i] ==  3'b111) ? (~taps_ext[i] + 1) : 
                                                                    '0;

            end
        end
    endgenerate

    //! Product register
    generate
        for (i = 0; i < N_PREADD; i++) begin : gen_product_reg
            always_ff @(posedge clk) begin : product_reg
                if (i_srst) begin
                    prod_reg[i] <= '0;
                end else if (i_en) begin
                    prod_reg[i] <= prod_next[i];
                end
            end
        end
    endgenerate

    //! Sum tree
    sum_tree #(
        .N    (N_PREADD),
        .NB_I (NB_PROD),
        .NB_O (NB_ACC)
    ) u_sum_tree (
        .i_op  (prod_reg),
        .o_res (acc_full_w)
    );

    //! Final truncation & saturation
    truncNsat #(
        .NB_I   (NB_ACC),
        .NBF_I  (NBF_ACC),
        .NB_O   (NB_O),
        .NBF_O  (NBF_O)
    ) u_truncNsat_out (
        .i_data (acc_full_w),
        .o_data (o_data)
    );

endmodule