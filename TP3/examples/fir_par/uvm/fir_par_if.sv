interface fir_par_if 
    import fir_par_pkg::*;
    import fir_sop_pkg::*;
(
    input logic clk
);
    logic i_arst_n;
    logic i_en;

    par_din_t   i_data;
    coeff_bus_t i_coeffs;
    par_dout_t  o_data;

    clocking cb_drv @(posedge clk);
        default input #1step output #0;
        output i_en, i_coeffs, i_data;
        input o_data;
    endclocking

    modport DRV (clocking cb_drv, input clk, output i_arst_n);

    clocking cb_mon @(posedge clk);
        default input #1step;
        input i_arst_n, i_en, i_coeffs, i_data, o_data;
    endclocking

    modport MON (clocking cb_mon, input clk);

endinterface
