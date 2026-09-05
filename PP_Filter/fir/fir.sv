`timescale 1ns/1ps

module fir
    import fir_pkg::*;
(
  input logic clk,

  input din_bus_t i_data,
  input coeff_bus_t i_coeffs,

  output dout_t o_data
);

din_bus_t data_r;
coeff_bus_t coeffs_r;

always_ff @(posedge clk) begin
  data_r <= i_data;
  coeffs_r <= i_coeffs;
end

prod_bus_t pp;

generate
  for (genvar ix = 0; ix < N_TAPS; ix ++) begin
    assign pp[ix] =  prod_t'(data_r[ix] * coeffs_r[ix]);
  end
endgenerate

out_fr_t sum;

always_comb begin
  sum = out_fr_t'(0);
  for (int ix = 0; ix < N_TAPS; ix++) begin
    sum = sum + out_fr_t'(pp[ix]);
  end
end

dout_t data_out;

sat_trunc #(
  .NB_IN(NB_OUT_FIR_FR),
  .NBF_IN(NBF_OUT_FIR_FR),
  .NB_OUT(NB_OUR_FIR),
  .NBF_OUT(NBF_OUR_FIR)
)
u_sat_trunc
(
  .i_data(sum),
  .o_data(data_out)
);

always_ff @(posedge clk) begin
  o_data <= data_out;
end

endmodule
