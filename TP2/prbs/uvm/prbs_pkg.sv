package prbs_pkg;

    parameter int WIDTH = 15;

    `include "prbs_txn.sv"
    `include "prbs_generator.sv"
    `include "prbs_driver.sv"
    `include "prbs_monitor.sv"
    `include "prbs_env.sv"

endpackage