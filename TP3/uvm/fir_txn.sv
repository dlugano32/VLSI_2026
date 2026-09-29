class fir_txn;
    import fir_pkg::*;

    typedef enum {
        SEND_SAMPLE,
        IDLE,
        STOP
    } op_t;

    rand op_t op;
    rand data_t data;
endclass
