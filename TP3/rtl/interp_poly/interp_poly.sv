`timescale 1ps/1ps

module interp_poly
    import fir_pkg::*;
    import interp_poly_pkg::*;
(
    input  logic  i_clk,
    input  logic  i_rst,
    input  logic  i_valid,
    input  data_t  i_data,

    output logic  o_valid,
    output data_t o_data
);

    data_phases_t phase_data;

    generate
        for(genvar ix = 0; ix < L; ix++) begin : gen_phases
            fir u_fir_phase (
                .i_clk    (i_clk),
                .i_rst    (i_rst),
                .i_en     (i_valid),
                .i_data   (i_data),
                .i_coeffs (COEFFS_PHASE[ix]),
                .o_data   (phase_data[ix])
            );
        end
    endgenerate

    logic input_seen;
    logic phase_output_valid;

    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            input_seen <= 1'b0;
        end else if(i_valid) begin
            input_seen <= 1'b1;
        end
    end

    // La primera salida válida ocurre L ciclos despues del primer i_valid
    assign phase_output_valid = i_valid & input_seen;

    phase_idx_t phase_sel;
    logic       output_started;

    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            phase_sel      <= '0;
            output_started <= 1'b0;
        end else if(phase_output_valid) begin
            phase_sel      <= '0;   // Siempre se comienza entregando la fase cero
            output_started <= 1'b1;
        end else if(output_started) begin
            phase_sel <= phase_sel + phase_idx_t'(1);
        end
    end

    assign o_valid = output_started;
    assign o_data  = phase_data[phase_sel];

endmodule
