//! @title Truncation and Saturation
//! @file truncNsat.sv
//! @author Damian Lugano
//! @date 27-9-2024
//!
//! - Fixed-point truncation and saturation module. This block converts a signed
//!     fixed-point input word from format `NB_I.NBF_I` to format `NB_O.NBF_O`.
//!     The number of fractional bits is adjusted by truncating LSBs when
//!     `NBF_I >= NBF_O`, or by zero-padding the fractional field when
//!     `NBF_I < NBF_O`.
//!
//! - This module assumes signed two's-complement fixed-point representation.
//!     It performs truncation, not rounding. Therefore, quantization error is
//!     introduced when fractional bits are discarded.

module truncNsat#(
    parameter int NB_I  = 16,
    parameter int NBF_I = 14,

    parameter int NB_O  = 8,
    parameter int NBF_O = 7
   )
  (
    input  logic signed [NB_I - 1 : 0] i_data,
    output logic signed [NB_O - 1 : 0] o_data
   );

    logic signed [NBF_O - 1 : 0] w_frac;
    logic signed [NB_O  - 1 : 0] w_saturation;
    logic signed [NB_O  - 1 : 0] w_truncation;
    logic w_condition;

    localparam NBI_I  = NB_I - NBF_I;
    localparam NBI_O  = NB_O - NBF_O;
    localparam NB_SAT = NBI_I - NBI_O;

    generate

      if(NBF_I >= NBF_O) begin
        assign w_frac = i_data[(NBF_I - 1) -: NBF_O];
      end else begin
        assign w_frac = {i_data[NBF_I - 1 : 0], {(NBF_O - NBF_I){1'b0}}};
      end

      if(NBI_I > NBI_O) begin
        assign w_condition  = (~|i_data[(NB_I - 1) -: (NB_SAT + 1)]) || &(i_data[(NB_I - 1) -: (NB_SAT + 1)]);
        assign w_truncation = {i_data[(NB_I - 1) -: NBI_O], w_frac};
        assign w_saturation = {i_data[NB_I - 1], {(NB_O - 1){~i_data[NB_I - 1]}}};
        assign o_data       = w_condition ? w_truncation : w_saturation;
      end 
      else if(NBI_I == NBI_O) begin
        assign o_data = {i_data[(NB_I - 1) -: NBI_I], w_frac};
      end else begin
        assign o_data = {{(NBI_O - NBI_I){i_data[NB_I - 1]}}, i_data[(NB_I - 1) -: NBI_I], w_frac};
      end
    endgenerate

endmodule