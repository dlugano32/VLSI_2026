package fir_pkg;

    localparam int N_TAPS = 16;
    
    localparam int NB_DATA  = 12;
    localparam int NBF_DATA = 11;

    localparam int NB_COEFFS  = 12;
    localparam int NBF_COEFFS = 11;

    localparam int NB_PROD  = NB_DATA  + NB_COEFFS;
    localparam int NBF_PROD = NBF_DATA + NBF_COEFFS;

    localparam int NB_OUT_FR  = NB_PROD + $clog2(N_TAPS);
    localparam int NBF_OUT_FR = NBF_PROD;

    localparam int NB_OUT  = NB_DATA;
    localparam int NBF_OUT = NBF_DATA;

    typedef logic signed [NB_DATA - 1 : 0] data_t;
    typedef data_t [N_TAPS - 1 : 0] data_bus_t;

    typedef logic signed [NB_COEFFS - 1 : 0] coeff_t;
    typedef coeff_t [N_TAPS - 1 : 0] coeff_bus_t;

    typedef logic signed [NB_PROD - 1 : 0] prod_t;
    typedef prod_t [N_TAPS - 1 : 0] prod_bus_t;

    typedef logic signed [NB_OUT_FR - 1 : 0] out_fr_t;

endpackage : fir_pkg
