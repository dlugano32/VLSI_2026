`timescale 1ps/1ps

module fir_par
    import fir_par_pkg::*;
    import fir_sop_pkg::*;
(
    input  logic       clk,
    input  logic       i_arst_n,
    input  logic       i_en,

    input  par_din_t   i_data,
    input  coeff_bus_t i_coeffs,
    output par_dout_t  o_data
);

    coeff_bus_t coeffs_r;
    par_mem_t mem;
    par_din_t regresor_in;
    par_regresor_t regresor;

    //! i_data[0] is the first sample in time. The lanes are reversed so regresor_in[0] is the most recent sample
    generate
        for(genvar ix = 0; ix < PAR; ix++) begin : reverse_input
            assign regresor_in[ix] = i_data[PAR-1-ix];
        end
    endgenerate

    //! Load coeffs
    always_ff @(posedge clk or negedge i_arst_n) begin
        if(!i_arst_n) begin
            coeffs_r <= '0;
        end else begin
            coeffs_r <= i_coeffs;
        end
    end

    //! Mem
    always_ff @(posedge clk or negedge i_arst_n) begin
        if(!i_arst_n) begin
            mem <= '0;
        end else if (i_en) begin
            mem <= {mem[N_TAPS-PAR-2 : 0], regresor_in};
        end
    end

    //! Regresor
    assign regresor = {mem, regresor_in};

    //! Generate parallel firs
    generate
        for(genvar ix = 0; ix < PAR; ix++) begin : sops
            fir_sop u_fir_sop (
                .clk(clk),
                .i_arst_n(i_arst_n),
                .i_en(i_en),
                .i_data(regresor[(PAR+N_TAPS-2) - ix -: N_TAPS]),
                .i_coeffs(coeffs_r),
                .o_data(o_data[ix])
            );
        end
    endgenerate

endmodule
