`timescale 1ns/1ps

module sop #(
    parameter int NB_O     = 12,
    parameter int NBF_O    = 10,

    parameter int NB_TAPS  = 12,
    parameter int NBF_TAPS = 10,

    parameter int N_TAPS   = 19
) (
    output logic signed [NB_O    - 1 : 0] o_y,
    input  logic signed [          1 : 0] i_x    [N_TAPS - 1 : 0],
    input  logic signed [NB_TAPS - 1 : 0] i_taps [((N_TAPS + 1) / 2) - 1 : 0],

    input  logic i_en,    //! Enable
    input  logic i_rst_n, //! Reset
    input  logic i_clk    //! Clock
);

    localparam int NB_I     = 2;
    localparam int NBF_I    = 0;
    localparam int NBI_O    = NB_O - NBF_O;
    localparam int N_PAIRS  = N_TAPS / 2;
    localparam int N_PREADD = (N_TAPS + 1) / 2;
    localparam int NB_PROD  = NB_TAPS + 1;     // Product width is extended by one bit to represent `±2h`.

    //! Vars
    logic signed [NB_I        : 0] pre_add_w [N_PREADD - 1 : 0];
    logic signed [NB_PROD - 1 : 0] prod_next [N_PREADD - 1 : 0];
    logic signed [NB_PROD - 1 : 0] prod_reg  [N_PREADD - 1 : 0];
    logic signed [NB_PROD - 1 : 0] taps_ext  [N_PREADD - 1 : 0];

    genvar i, j, lvl;
    
    //! Pre-adders for symmetric input pairs
    //! For odd `N_TAPS`, the center tap is passed through without addition.
    generate
        for (i = 0; i < N_PREADD; i++) begin : gen_pre_adders

            if (i < N_PAIRS) begin : gen_symmetric_pair

                assign pre_add_w[i] =
                    {i_x[i][NB_I-1], i_x[i]}
                + {i_x[N_TAPS-1-i][NB_I-1], i_x[N_TAPS-1-i]};

            end else begin : gen_center_tap

                assign pre_add_w[i] =
                    {i_x[i][NB_I-1], i_x[i]};
            end
        end
    endgenerate

    //! Taps product with pre-added inputs
    //! The pre-added PAM-2 values are decoded as {-2, -1, 0, +1, +2}
    //! and mapped to {-2*tap, -tap, 0, +tap, +2*tap}.
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
            always_ff @(posedge i_clk or negedge i_rst_n) begin : product_reg
                if (!i_rst_n) begin
                    prod_reg[i] <= '0;
                end else if (i_en) begin
                    prod_reg[i] <= prod_next[i];
                end
            end
        end
    endgenerate

    //! Sum tree
    localparam int N_LEVELS = $clog2(N_PREADD);
    localparam int NB_ACC   = NB_PROD + $clog2(N_PREADD);

    logic signed [NB_ACC - 1 : 0] sum_tree [0 : N_LEVELS][0 : N_PREADD - 1];

    generate
        for (j = 0; j < N_PREADD; j++) begin : gen_sum_tree_input
            assign sum_tree[0][j] =
                $signed({{(NB_ACC-NB_PROD){prod_reg[j][NB_PROD-1]}}, prod_reg[j]});
        end

        for (lvl = 0; lvl < N_LEVELS; lvl++) begin : gen_sum_tree_level
            localparam int N_IN  = (N_PREADD + (1 << lvl)     - 1) >> lvl;      // ceil(N_PREADD / 2^lvl)
            localparam int N_OUT = (N_PREADD + (1 << (lvl+1)) - 1) >> (lvl+1);  // ceil(N_PREADD / 2^(lvl+1))

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

    //! Asigno la salida del arbol de suma, truncado en los bits de salida.
    assign o_y = sum_tree[N_LEVELS][0][NB_O - 1 : 0];

endmodule
