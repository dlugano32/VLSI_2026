package interp_zeros_pkg;
    import fir_pkg::*;

    // h[k] cuantizado en signed Q1.11
    localparam coeff_bus_t COEFFS = '{
         0: 12'hFF5,
         1: 12'hFD4,
         2: 12'hF9B,
         3: 12'hFA8,
         4: 12'h0A7,
         5: 12'h2E4,
         6: 12'h5B6,
         7: 12'h7B3,
         8: 12'h7B3,
         9: 12'h5B6,
        10: 12'h2E4,
        11: 12'h0A7,
        12: 12'hFA8,
        13: 12'hF9B,
        14: 12'hFD4,
        15: 12'hFF5
    };
    
endpackage : interp_zeros_pkg
