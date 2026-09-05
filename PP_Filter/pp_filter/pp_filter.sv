`timescale 1ns/1ps

module pp_filter
    import pp_filter_pkg::*;
    import fir_pkg::*;
(
  input logic clk,

  input pp_din_t i_data,
  input pp_coeffs_t i_coeffs,

  output pp_out_t o_data
);

pp_mem_t mem;

always_ff @(posedge clk) begin
  mem <= i_data[PAR_IN - 1 -: (N_TAPS-1)];
end

pp_regresor_t regresor;

assign regresor = {i_data, mem};

generate
  for (genvar ix = 0; ix < PAR_OUT; ix++) begin : FILTERS
    localparam start_idx = (ix * DW) / UP;
    localparam phase_idx = (ix * DW) % UP;

  fir
  u_fir
  (
    .clk(clk),
    .i_data(regresor[start_idx +: N_TAPS]),
    .i_coeffs(i_coeffs[phase_idx]),
    .o_data(o_data[ix])
  );
  end
endgenerate


endmodule
