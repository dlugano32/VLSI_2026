class fir_par_txn;
    import fir_par_pkg::*;
    import fir_sop_pkg::*;

    typedef enum {
        LOAD_COEFFS,
        SEND_SAMPLES,
        IDLE,
        STOP
    } op_t;

    op_t op;
    coeff_bus_t coeffs;
    par_din_t data;

    rand bit [PAR - 1 : 0] pam2;

    function void post_randomize();
        foreach (data[lane]) begin
            data[lane] = pam2[lane] ? din_t'(-1) : din_t'(1);
        end
    endfunction
endclass