interface prbs_if #( parameter int WIDTH = 15) (input logic clk);
 
    logic                 rst_n;        // Internal signal, drived by the TB
    logic [WIDTH - 1 : 0] i_seed;
    logic                 i_en;
    logic [2         : 0] i_sel;
    logic                 o_prbs;
    
    clocking cb @(posedge clk);
        default input #1step output #1ns;   // To prevent race conditions
        output rst_n, i_seed, i_en, i_sel;
        input  o_prbs;
    endclocking
    
    modport TB  (clocking cb, output rst_n, input clk);

    clocking cb_mon @(posedge clk);
        default input #1step;
        input rst_n, i_en, i_sel, i_seed, o_prbs;
    endclocking

    modport MON (clocking cb_mon, input clk);

endinterface
