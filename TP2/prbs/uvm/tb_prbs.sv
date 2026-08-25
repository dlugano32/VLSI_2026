`timescale 1ns/1ps

module tb_prbs();

    //! Import classes
    import prbs_pkg::*;
    
    //! Generates clock
    logic i_clk = 0;
    always #5 i_clk = ~i_clk;
    
    //! Interface instantiation
    prbs_if pif (.clk(i_clk));
    
    //! Instantiate DUT
    prbs_parallel u_prbs_parallel (
      .i_clk     (i_clk         ),
      .i_rst_n   (pif.rst_n     ),
      .i_start   (pif.i_start   ),
      .i_stop    (pif.i_stop    ),
      .i_sel     (pif.i_sel     ),
      .i_seed    (pif.i_seed    ),
      .o_prbs    (pif.o_prbs    ),
      .o_running (pif.o_running )
    );
    
    //! Inits the sim
    tb_program u_tb (pif);

    //! Outputs
    //initial begin
    //    $dumpfile("../sim/waves_uvm/prbs.vcd"); 
    //    $dumpvars(0, tb_prbs);    
    //end

endmodule

//! This program receives the interface, creates the enviroment and initializes the simulation
program automatic tb_program (prbs_if pif);

    import prbs_pkg::*;

    prbs_env env;

    initial begin
        env = new(pif);
        env.run();
        env.report();
        $finish;
    end

endprogram
