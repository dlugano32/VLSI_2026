interface fir_if 
    import fir_pkg::*;
(
    input logic clk
);
    logic i_rst;
    logic i_valid;

    data_t i_data;
    logic  o_valid;
    data_t o_data;

    clocking cb_drv @(posedge clk);
        default input #1step output #0;
        output i_valid, i_data;
        input  o_valid, o_data;
    endclocking

    modport DRV (clocking cb_drv, input clk, output i_rst);

    clocking cb_mon @(posedge clk);
        default input #1step;
        input i_rst, i_valid, i_data, o_valid, o_data;
    endclocking

    modport MON (clocking cb_mon, input clk);

endinterface
