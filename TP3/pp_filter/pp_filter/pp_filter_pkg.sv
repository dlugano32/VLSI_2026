package pp_filter_pkg;

//upsampling 4/3

import fir_pkg::*;

localparam PAR_IN = 30;
localparam PAR_OUT = 40;
localparam UP = 4;
localparam DW = 3;

localparam N_PHASES = UP;

typedef din_t [PAR_IN - 1 : 0]    pp_din_t;
typedef dout_t [PAR_OUT - 1 : 0]  pp_out_t;
typedef coeff_bus_t [N_PHASES - 1 : 0] pp_coeffs_t;
typedef din_t [N_TAPS - 2 : 0] pp_mem_t;
typedef din_t [PAR_IN + N_TAPS - 2 : 0] pp_regresor_t;


endpackage : pp_filter_pkg
