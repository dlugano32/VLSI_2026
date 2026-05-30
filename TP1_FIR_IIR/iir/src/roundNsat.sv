//! @title Rounding and Saturation
//! @file roundNsat.sv
//! @author Damian Lugano
//! @date 30-5-2026
//!
//! - Fixed-point rounding and saturation module. This block converts a signed
//!     fixed-point input word from format `NB_I.NBF_I` to format `NB_O.NBF_O`.

module roundNsat #(
    parameter int NB_I  = 32,
    parameter int NBF_I = 30,

    parameter int NB_O  = 16,
    parameter int NBF_O = 15
) (
    input  logic signed [NB_I - 1 : 0] i_data,
    output logic signed [NB_O - 1 : 0] o_data
);

    localparam int NBI_I = NB_I - NBF_I;
    localparam int NBI_O = NB_O - NBF_O;

    //! The rounding operation can generate an additional integer carry bit.
    localparam int NBI_R  = NBI_I + 1;
    localparam int NB_RND = NBI_R + NBF_O;
    localparam int NB_SAT = NBI_R - NBI_O;

    logic signed [NB_RND - 1 : 0] w_round;
    logic signed [NB_O   - 1 : 0] w_saturation;
    logic signed [NB_O   - 1 : 0] w_rounded_resize;
    logic                         w_condition;

    generate
        //! Rounding / fractional alignment
        if (NBF_I > NBF_O) begin : gen_frac_round //! Parte fraccionaria de entrada mayor a la de salida. Redondeo.
            localparam int N_SHIFT = NBF_I - NBF_O;

            logic signed [NB_I : 0] w_data_ext;
            logic signed [NB_I : 0] w_round_ext;

            assign w_data_ext  = {i_data[NB_I - 1], i_data};
            assign w_round_ext = w_data_ext + ({{NB_I{1'b0}}, 1'b1} <<< (N_SHIFT - 1));
            assign w_round     = w_round_ext >>> N_SHIFT;

        end else if (NBF_I == NBF_O) begin : gen_frac_same //! Parte fraccionaria de entrada igual a la de salida. Sin redondeo.
            assign w_round = {i_data[NB_I - 1], i_data};

        end else begin : gen_frac_extend //! Parte fraccionaria de salida mayor a la de entrada. Zero padding.
            assign w_round = {i_data[NB_I - 1], i_data, {(NBF_O - NBF_I){1'b0}}};
        end

        //! Integer resizing and saturation
        if (NBI_R > NBI_O) begin : gen_sat //! Entero redondeado mayor al entero de salida. Resize con saturación.
            assign w_condition      = (~|w_round[(NB_RND - 1) -: (NB_SAT + 1)]) || (&w_round[(NB_RND - 1) -: (NB_SAT + 1)]);
            assign w_rounded_resize = w_round[NB_O - 1 : 0];
            assign w_saturation     = {w_round[NB_RND - 1], {(NB_O - 1){~w_round[NB_RND - 1]}}};
            assign o_data           = w_condition ? w_rounded_resize : w_saturation;

        end else if (NBI_R == NBI_O) begin : gen_same_int //! Entero redondeado igual al entero de salida. Sin saturación.
            assign o_data = w_round[NB_O - 1 : 0];

        end else begin : gen_extend_int //! Entero de salida mayor al entero redondeado. Extensión de signo.
            assign o_data = {{(NBI_O - NBI_R){w_round[NB_RND - 1]}}, w_round};
        end
    endgenerate

endmodule
