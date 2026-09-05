`timescale 1ns/1ps
module sat_trunc #(
    parameter NB_IN = 20,
    parameter NBF_IN = 13,
    parameter NB_OUT = 8,
    parameter NBF_OUT = 7,
    localparam NBI_IN = NB_IN - NBF_IN,
    localparam NBI_OUT = NB_OUT - NBF_OUT,
    localparam NBI_DIFF = NBI_IN - NBI_OUT
)
(
    input logic signed [NB_IN-1:0] i_data,
    output logic signed [NB_OUT-1:0] o_data
);

logic fit_cond;
logic sign;

assign fit_cond = (&i_data[NB_IN - 1 -: (NBI_DIFF+1)]) | (~|i_data[NB_IN - 1 -: (NBI_DIFF+1)]);
assign sign = i_data[$bits(i_data)-1];


assign o_data = (fit_cond) ? $signed(i_data[(NB_IN - 1 - NBI_DIFF) -: NB_OUT]) :
                (sign)     ? $signed({1'b1,{NB_OUT-1{1'b0}}}) : $signed({1'b0,{NB_OUT-1{1'b1}}});



endmodule
