//! @title Generic Folded Symmetric Fixed-Point FIR Filter
//! @file fir_folded.sv
//! @author Damian Lugano
//! @date 19-5-2026
//!
//! - Generic signed fixed-point FIR filter optimized for symmetric impulse responses.

module fir_folded #(
    parameter int NB_I     = 8,
    parameter int NBF_I    = 7,

    parameter int NB_O     = 8,
    parameter int NBF_O    = 7,

    parameter int NB_TAPS  = 8,
    parameter int NBF_TAPS = 7,

    parameter int N_TAPS   = 4
) (
    output logic signed [NB_O    - 1 : 0] o_data,
    input  logic signed [NB_I    - 1 : 0] i_data,
    input  logic signed [NB_TAPS - 1 : 0] i_taps [((N_TAPS + 1) / 2) - 1 : 0],    
    input  logic i_en,   //! Enable
    input  logic i_srst, //! Reset
    input  logic i_clk     //! Clock
);

    localparam int N_PAIRS  =  N_TAPS / 2;
    localparam int N_PREADD = (N_TAPS + 1) / 2;
    localparam int NB_PROD  =  NB_I   + 1 + NB_TAPS;
    localparam int NBF_PROD =  NBF_I  + NBF_TAPS;
    localparam int NB_ACC   =  NB_O   + $clog2(N_PREADD);
    localparam int NBF_ACC  =  NBF_O;

    //! Vars
    logic signed [NB_I    - 1 : 0] data_reg  [N_TAPS   - 1 : 0];
    logic signed [NB_I        : 0] pre_add_w [N_PREADD - 1 : 0];
    logic signed [NB_PROD - 1 : 0] prod_next [N_PREADD - 1 : 0];
    logic signed [NB_PROD - 1 : 0] prod_reg  [N_PREADD - 1 : 0];
    logic signed [NB_O    - 1 : 0] prod_ts_w [N_PREADD - 1 : 0];
    logic signed [NB_ACC  - 1 : 0] acc_full_w;

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
        for (i = 0; i < N_PREADD; i++) begin : gen_product
            assign prod_next[i] = i_taps[i] * pre_add_w[i];
        end
    endgenerate

    //! Product register
    generate
        for (i = 0; i < N_PREADD; i++) begin : gen_product_reg
            always_ff @(posedge i_clk) begin : product_reg
                if (i_srst) begin
                    prod_reg[i] <= '0;
                end else if (i_en) begin
                    prod_reg[i] <= prod_next[i];
                end
            end
        end
    endgenerate

    //! Truncation & Saturation of products
    generate
        for (i = 0; i < N_PREADD; i++) begin : gen_truncNsat_prod
            truncNsat #(
                .NB_I   (NB_PROD),
                .NBF_I  (NBF_PROD),
                .NB_O   (NB_O),
                .NBF_O  (NBF_O)
            ) u_truncNsat_products (
                .i_data (prod_reg[i]),
                .o_data (prod_ts_w[i])
            );
        end
    endgenerate

    //! Sum tree
    sum_tree #(
        .N    (N_PREADD),
        .NB_I (NB_O),
        .NB_O (NB_ACC)
    ) u_sum_tree (
        .i_op  (prod_ts_w),
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