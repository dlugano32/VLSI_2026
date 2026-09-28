`timescale 1ps/1ps

module fir 
    import fir_pkg::*; 
(
    input  logic       clk,
    input  logic       i_arst_n,
    input  logic       i_en,

    input  din_t       i_data,
    input  coeff_bus_t i_coeffs,
    output dout_t      o_data
);

    din_bus_t data_r;
    coeff_bus_t coeffs_r;
    prod_bus_t pp;
    out_fr_t sum;
    dout_t data_out;

    //! Load coeffs
    always_ff @(posedge clk or negedge i_arst_n) begin
        if(!i_arst_n) begin
            coeffs_r <= '0;
        end else begin
            coeffs_r <= i_coeffs;
        end
    end

    //! Shift Register
    always_ff @(posedge clk or negedge i_arst_n) begin
        if(!i_arst_n) begin
            data_r <= '0;
        end else if(i_en) begin
            data_r <= {data_r[N_TAPS - 2 : 0], i_data};
        end
    end

    //! Partial Products
    generate
        for(genvar ix = 0; ix < N_TAPS; ix++) begin
            assign pp[ix] = prod_t'(data_r[ix]) * prod_t'(coeffs_r[ix]);
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
        .NB_OUT(NB_OUT),
        .NBF_OUT(NBF_OUT)
    ) u_sat_trunc (
        .i_data(sum),
        .o_data(data_out)
    );

    //! Output
    always_ff @(posedge clk or negedge i_arst_n) begin
        if(!i_arst_n) begin
            o_data <= '0;
        end else if(i_en) begin
            o_data <= data_out;
        end
    end

endmodule