//! @title Truncation and Saturation
//! @file truncNsat.sv
//! @author Damian Lugano
//! @date 27-9-2024
//!
//! - Fixed-point truncation and saturation module. This block converts a signed
//!     fixed-point input word from format `NB_I.NBF_I` to format `NB_O.NBF_O`.

module truncNsat #(
    parameter int NB_I  = 16,
    parameter int NBF_I = 14,

    parameter int NB_O  = 8,
    parameter int NBF_O = 7
) (
    input  logic signed [NB_I - 1 : 0] i_data,
    output logic signed [NB_O - 1 : 0] o_data
);

    localparam int NBI_I  = NB_I - NBF_I;
    localparam int NBI_O  = NB_O - NBF_O;
    localparam int NB_SAT = NBI_I - NBI_O;

    logic signed [NB_O - 1 : 0] w_saturation;
    logic signed [NB_O - 1 : 0] w_truncation;
    logic                       w_condition;

    generate
        if (NBF_O == 0) begin : gen_no_frac_out //! Sin salida fraccional

            if (NBI_I > NBI_O) begin : gen_sat_no_frac  //! Entero de entrada mayor al entero de salida. Truncado con saturación
                assign w_condition  = (~|i_data[(NB_I - 1) -: (NB_SAT + 1)]) || ( &i_data[(NB_I - 1) -: (NB_SAT + 1)]);
                assign w_truncation = i_data[(NBF_I + NBI_O - 1) -: NBI_O];
                assign w_saturation = {i_data[NB_I - 1], {(NB_O - 1){~i_data[NB_I - 1]}}};
                assign o_data = w_condition ? w_truncation : w_saturation;

            end else if (NBI_I == NBI_O) begin : gen_same_int_no_frac //! Entero de entrada igual al entero de salida. Osea truncado sin saturación
                assign o_data = i_data[(NBF_I + NBI_O - 1) -: NBI_O];
                
            end else begin : gen_extend_int_no_frac //! Entero de salida mayor al entero de entrada. Osea extensión de signo.
                assign o_data = { {(NBI_O - NBI_I){i_data[NB_I - 1]}}, i_data[(NBF_I + NBI_I - 1) -: NBI_I]};

            end
        end else begin : gen_frac_out //! Salida fraccional

            logic signed [NBF_O - 1 : 0] w_frac;

            //! Parte fraccionaria
            if (NBF_I >= NBF_O) begin : gen_frac_trunc //! Parte fraccionaria de entrada mayor o igual a la de salida. Slicing.
                assign w_frac = i_data[(NBF_I - 1) -: NBF_O];
            end else begin : gen_frac_extend  //! Parte fraccionaria de salida mayor a la de entrada. Zero padding.
                assign w_frac = {i_data[NBF_I - 1 : 0], {(NBF_O - NBF_I){1'b0}}};
            end

            //! Parte entera
            if (NBI_I > NBI_O) begin : gen_sat_frac  //! Parte entera de entrada mayor a la de salida. Truncado y saturación
                assign w_condition = (~|i_data[(NB_I - 1) -: (NB_SAT + 1)]) || ( &i_data[(NB_I - 1) -: (NB_SAT + 1)]);
                assign w_truncation = { i_data[(NBF_I + NBI_O - 1) -: NBI_O], w_frac };
                assign w_saturation = {i_data[NB_I - 1], {(NB_O - 1){~i_data[NB_I - 1]}}};
                assign o_data = w_condition ? w_truncation : w_saturation;

            end else if (NBI_I == NBI_O) begin : gen_same_int_frac  //! Parte entera de entrada igual a la de salida. Unicamente se trata la parte fraccionaria
                assign o_data = {i_data[(NBF_I + NBI_O - 1) -: NBI_O], w_frac};

            end else begin : gen_extend_int_frac  //! Parte entero de entrada menor a la de salida. Se trata la parte fraccionaria y se extiende signo.
                assign o_data = {{(NBI_O - NBI_I){i_data[NB_I - 1]}}, i_data[(NBF_I + NBI_I - 1) -: NBI_I], w_frac};
            end
        end

    endgenerate

endmodule