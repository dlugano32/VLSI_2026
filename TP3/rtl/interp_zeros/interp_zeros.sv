`timescale 1ps/1ps

module interp_zeros
    import interp_zeros_pkg::*;
    import fir_pkg::*;
(
    input  logic  i_clk,
    input  logic  i_rst,
    input  logic  i_valid,
    input  data_t  i_data,

    output logic  o_valid,
    output data_t o_data
);

    data_t data_in;

    // i_valid vale uno cada L ciclos. En los restantes ciclos se inserta
    // explicitamente un cero, pero el FIR continua avanzando a L*f_s.
    assign data_in = i_valid ? i_data : data_t'(0);

    fir u_fir (
        .i_clk    (i_clk),
        .i_rst    (i_rst),
        .i_en     (1'b1),
        .i_data   (data_in),
        .i_coeffs (COEFFS),
        .o_data   (o_data)
    );

    // El FIR registra su salida un ciclo despues de aceptar el primer dato.
    // Desde ese momento hay una salida valida en cada ciclo.
    logic input_seen;

    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            input_seen <= 1'b0;
            o_valid    <= 1'b0;
        end else begin
            input_seen <= input_seen | i_valid;
            o_valid    <= input_seen;
        end
    end
endmodule
