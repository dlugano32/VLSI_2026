`timescale 1ns/1ps

module tb_prbs;

    //! Import classes
    import prbs_pkg::*;
    
    //! Generates clock
    logic i_clk = 0;
    always #5 i_clk = ~i_clk;
    
    //! Interface instantiation
    prbs_if #(.WIDTH(WIDTH)) pif (.clk(i_clk));
    
    //! Instantiate DUT
    prbs #(.WIDTH(WIDTH)) u_prbs (
      .i_clk    (i_clk      ),
      .i_rst_n  (pif.rst_n  ),
      .i_en     (pif.i_en   ),
      .i_sel    (pif.i_sel  ),
      .i_seed   (pif.i_seed ),
      .o_prbs   (pif.o_prbs )
    );
    
    //! Inits the sim
    tb_program #(.WIDTH(WIDTH)) u_tb (pif);

    //! Outputs
    //initial begin
    //    $dumpfile("../sim/waves_uvm/prbs.vcd"); 
    //    $dumpvars(0, tb_prbs);    
    //end

endmodule

//! This program receives the interface, creates the enviroment and initializes the simulation
program automatic tb_program #(parameter int WIDTH = 15) (prbs_if pif);

    import prbs_pkg::*;

    prbs_env #(WIDTH) env;

    initial begin
        env = new(pif);
        env.run();
        env.report();
        $finish;
    end

endprogram
