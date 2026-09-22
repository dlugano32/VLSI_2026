class fir_txn;
    import fir_pkg::*;

    typedef enum {
        LOAD_COEFFS,
        SEND_SAMPLE,
        IDLE,
        STOP
    } op_t;

    rand op_t op;
    rand din_t data;
    rand coeff_bus_t coeffs;

    constraint c_data { data inside {din_t'(1), din_t'(-1)}; }
endclass