package fir_tb_pkg;

    import fir_pkg::*;

    localparam int INTERPOLATION      = 4;
    localparam int N_INPUTS           = 2000;
    localparam int N_EXPECTED         = 8015;
    localparam int FLUSH_SAMPLES      = 5;

    `include "fir_txn.sv"
    `include "fir_drv.sv"
    `include "fir_mon.sv"
    `include "fir_gen.sv"
    `include "fir_scb.sv"
    `include "fir_env.sv"

endpackage
