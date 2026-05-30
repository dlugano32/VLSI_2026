//! @title Combinational Sum Tree
//! @file sum_tree.sv
//! @author Damian Lugano
//! @date 19-5-2026
//!
//! - Generic combinational sum tree for `N` signed operands. The module reduces
//!     an array of `N` input operands into a single accumulated result by adding
//!     operands pairwise at each level of the tree.
//!
//! - At every level, operands are grouped in pairs. If the number of operands
//!     at a given level is odd, the last operand is passed directly to the next
//!     level without modification. This process is repeated until a single
//!     result remains.
//!
//! - The total number of adders generated is `N-1`, while the tree depth is
//!     `$clog2(N)`. The output width should be large enough to avoid overflow
//!     when accumulating all input operands. For signed fixed-point operands,
//!     a typical safe choice is:
//!
//!         NB_O = NB_I + $clog2(N)

module sum_tree #(
    parameter int N      = 4,   //! Operands
    parameter int NB_I   = 8,

    parameter int NB_O   = NB_I + $clog2(N)
)(
    input  logic signed [NB_I - 1 : 0] i_op [N - 1 : 0],
    output logic signed [NB_O - 1 : 0] o_res
);

    localparam int N_LEVELS = $clog2(N);

    // Tree levels.
    // level[0] contains the sign-extended inputs.
    // level[N_LEVELS][0] contains the final accumulated result.
    logic signed [NB_O - 1 : 0] level [0 : N_LEVELS][0 : N - 1];

    genvar i, l;

    // Input sign extension
    generate
        for (i = 0; i < N; i++) begin : gen_input_extend
            assign level[0][i] = {{(NB_O - NB_I){i_op[i][NB_I - 1]}}, i_op[i]};
        end
    endgenerate

    // Adder tree
    generate
        for (l = 0; l < N_LEVELS; l++) begin : gen_levels

            localparam int CUR_DIV  = (1 << l);
            localparam int NEXT_DIV = (1 << (l + 1));

            localparam int CUR_N  = (N + CUR_DIV  - 1) / CUR_DIV;
            localparam int NEXT_N = (N + NEXT_DIV - 1) / NEXT_DIV;

            for (i = 0; i < NEXT_N; i++) begin : gen_adders

                if ((2*i + 1) < CUR_N) begin : gen_pair_sum
                    assign level[l + 1][i] = level[l][2*i] + level[l][2*i + 1];
                end else begin : gen_passthrough
                    assign level[l + 1][i] = level[l][2*i];
                end

            end
        end
    endgenerate

    assign o_res = level[N_LEVELS][0];

endmodule