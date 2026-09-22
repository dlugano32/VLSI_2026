package fir_pkg;

    localparam PAM = 2;

    localparam N_TAPS = 19;

    localparam NB_IN  = $clog2(PAM)+1;
    localparam NBF_IN = 0;

    localparam NB_COEFFS  = 12;
    localparam NBF_COEFFS = 10;

    localparam NB_PROD  = NB_IN  + NB_COEFFS;
    localparam NBF_PROD = NBF_IN + NBF_COEFFS;

    localparam NB_OUT_FR = NB_PROD + $clog2(N_TAPS);
    localparam NBF_OUT_FR = NBF_PROD;

    localparam NB_OUT  = 12;
    localparam NBF_OUT = 10;

    typedef logic signed [NB_IN - 1 : 0] din_t;
    typedef din_t [N_TAPS - 1 : 0] din_bus_t; 

    typedef logic signed [NB_COEFFS - 1 : 0] coeff_t;
    typedef coeff_t [N_TAPS - 1 : 0] coeff_bus_t;

    typedef logic signed [NB_PROD - 1 : 0] prod_t;
    typedef prod_t [N_TAPS - 1 : 0] prod_bus_t;

    typedef logic signed [NB_OUT_FR - 1 : 0] out_fr_t;

    typedef logic signed [NB_OUT - 1 : 0] dout_t;

endpackage : fir_pkg