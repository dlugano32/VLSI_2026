package fir_par_pkg;

    import fir_sop_pkg::*;

    localparam PAR = 4;

    typedef din_t  [PAR - 1 : 0] par_din_t;
    typedef dout_t [PAR - 1 : 0] par_dout_t;
    typedef din_t  [N_TAPS - 2 : 0] par_mem_t;
    typedef din_t  [PAR + N_TAPS - 2 : 0] par_regresor_t;

endpackage : fir_par_pkg
