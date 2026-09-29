package interp_poly_pkg;
    import fir_pkg::*;

    localparam int L = 4;

    localparam int PHASE_W = $clog2(L);

    typedef logic [PHASE_W - 1 : 0] phase_idx_t;
    typedef coeff_bus_t [L - 1 : 0] coeff_phases_t;
    typedef data_t      [L - 1 : 0] data_phases_t;

    // E_p[r] = h[r*L+p]. Cada fila contiene los cuatro taps de una fase.
    localparam coeff_phases_t COEFFS_PHASE = '{
        0: '{
            0: -12'sd11,
            1:  12'sd167,
            2:  12'sd1971,
            3: -12'sd88
        },
        1: '{
            0: -12'sd44,
            1:  12'sd740,
            2:  12'sd1462,
            3: -12'sd101
        },
        2: '{
            0: -12'sd101,
            1:  12'sd1462,
            2:  12'sd740,
            3: -12'sd44
        },
        3: '{
            0: -12'sd88,
            1:  12'sd1971,
            2:  12'sd167,
            3: -12'sd11
        }
    };

endpackage : interp_poly_pkg
