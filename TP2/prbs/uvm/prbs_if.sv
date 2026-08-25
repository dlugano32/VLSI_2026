interface prbs_if (input logic clk);

    localparam int WIDTH = 15;
    localparam int P = 4;
 
    logic                 rst_n;        // Internal signal, drived by the TB
    logic [WIDTH - 1 : 0] i_seed;
    logic                 i_start;
    logic                 i_stop;
    logic [2         : 0] i_sel;
    logic                 o_prbs [P - 1 : 0];
    logic                 o_running;
    
    clocking cb @(posedge clk);
        default input #1step output #1ns;   // To prevent race conditions
        output rst_n, i_seed, i_start, i_stop, i_sel;
        input  o_prbs, o_running;
    endclocking
    
    modport TB  (clocking cb, output rst_n, input clk);

    clocking cb_mon @(posedge clk);
        default input #1step;
        input rst_n, i_start, i_stop, i_sel, i_seed, o_prbs, o_running;
    endclocking

    modport MON (clocking cb_mon, input clk);

endinterface
