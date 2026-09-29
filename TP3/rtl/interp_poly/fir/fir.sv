`timescale 1ps/1ps

module fir 
    import fir_pkg::*; 
(
    input  logic       i_clk,
    input  logic       i_rst,
    input  logic       i_en,

    input  data_t       i_data,
    input  coeff_bus_t i_coeffs,
    output data_t      o_data
);

    data_bus_t data_r;
    prod_bus_t pp;
    out_fr_t sum;
    data_t data_out;

    //! Shift register. data_r[0] contiene siempre la muestra mas reciente.
    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            data_r <= '0;
        end else if(i_en) begin
            data_r <= {data_r[N_TAPS - 2 : 0], i_data};
        end
    end

    //! Partial Products
    generate
        for(genvar ix = 0; ix < N_TAPS; ix++) begin
            assign pp[ix] = data_r[ix] * i_coeffs[ix];
        end
    endgenerate

    //! Sum tree
    always_comb begin
        sum = out_fr_t'(0);
        for(int ix = 0; ix < N_TAPS; ix++) begin
            sum = sum + out_fr_t'(pp[ix]);
        end
    end

    //! Saturation and Truncation
    sat_trunc #(
        .NB_IN(NB_OUT_FR),
        .NBF_IN(NBF_OUT_FR),
        .NB_OUT(NB_DATA),
        .NBF_OUT(NBF_DATA)
    ) u_sat_trunc (
        .i_data(sum),
        .o_data(data_out)
    );

    //! Output
    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            o_data <= '0;
        end else if(i_en) begin
            o_data <= data_out;
        end
    end

endmodule
