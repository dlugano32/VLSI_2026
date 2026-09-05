package fir_pkg;

  localparam PAM = 2;

  // N_TAPS es la cantidad de taps de UNA fase
  localparam N_TAPS = 5;

  localparam NB_FIR_DATA_IN = $clog2(PAM)+1;
  // Los vectores pam2_input_Q2_0.hex usan formato signed Q(2,0).
  localparam NBF_FIR_DATA_IN = 0;

  localparam NB_COEFFS = 12;
  localparam NBF_COEFFS = 10;

  localparam NB_PROD = NB_COEFFS + NB_FIR_DATA_IN;
  localparam NBF_PROD = NBF_COEFFS + NBF_FIR_DATA_IN;

  localparam NB_OUT_FIR_FR = NB_PROD + $clog2(N_TAPS);
  localparam NBF_OUT_FIR_FR = NBF_PROD;

  localparam NB_OUR_FIR = 12;
  localparam NBF_OUR_FIR = 10;

  typedef logic signed [NB_FIR_DATA_IN - 1 : 0] din_t;
  typedef din_t [N_TAPS - 1 : 0] din_bus_t;

  typedef logic signed [NB_COEFFS - 1 : 0] coeff_t;
  typedef coeff_t [N_TAPS - 1 : 0] coeff_bus_t;

  typedef logic signed [NB_PROD - 1 : 0] prod_t;
  typedef prod_t [N_TAPS - 1 : 0] prod_bus_t;

  typedef logic signed [NB_OUT_FIR_FR - 1 : 0] out_fr_t;

  typedef logic signed [NB_OUR_FIR - 1 : 0] dout_t;



endpackage : fir_pkg
