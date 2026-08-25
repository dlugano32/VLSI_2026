`timescale 1ps/1ps

module tb_prbs_parallel();

    localparam int MAX_ORDER = 15;
    localparam int P = 4;

    localparam int N_DATA = 2**12;

    logic i_rst_n;
    logic i_start;
    logic i_stop;
    logic [2 : 0] i_sel;
    logic [MAX_ORDER - 1 : 0] i_seed;
    logic o_prbs [P  - 1 : 0];
    logic o_running;

    int unsigned match_count;
    logic reference [0 : N_DATA-1];
    logic stopped_output [P - 1 : 0];

    //! Clock
    logic clk;

    parameter time CLK_T  = 1ns; //! 1GHz
    
    //! Clock generation: 1GHz
    initial clk = 1'b1;
    always #(CLK_T / 2) clk = ~clk;

    //! DUT instantiation
    prbs_parallel u_prbs_parallel_gen (
        .i_clk(clk),
        .i_rst_n(i_rst_n),
        .i_start(i_start),
        .i_stop(i_stop),
        .i_sel(i_sel),
        .i_seed(i_seed),

        .o_prbs(o_prbs),
        .o_running(o_running)
    );

    initial begin
        $readmemb(
            "sim/tb/mem/prbs15_reference.mem",
            reference
        );
    end

    //! Waves
    initial begin $dumpfile("sim/waves/prbs_parallel.vcd"); 
    $dumpvars(0,tb_prbs_parallel); end

    initial begin
        $display("");
        $display("========================================");
        $display("PRBS Simulation Started");
        $display("========================================");
        $display("");

        // Initial values
        i_start = 1'b0;
        i_stop  = 1'b0;
        i_rst_n = 1'b0;
        i_seed  = 15'h7FFF;
        i_sel   = 3'b101;

        match_count = 0;

        repeat (4) @(negedge clk);

        i_rst_n = 1'b1;

        repeat (2) @(negedge clk);

        //! Start PRBS10. The active seed is i_seed[9:0] = 10'h3FF.
        i_start = 1'b1;
        @(negedge clk);
        i_start = 1'b0;

        if (!o_running)
            $fatal(1, "PRBS did not enter the running state after i_start.");

        //! Changing the configuration inputs while running must not alter the
        //! active sequence. The DUT uses the values captured by i_start.
        i_seed = '0;
        i_sel  = 3'b101;

        for(int i = 0; i < (N_DATA/P); i++) begin
            for(int j; j<P; j++) begin
                if( o_prbs[j] == reference[j+i*P] )
                    match_count++;
            end

            @(negedge clk);
        end

        //! Stop the sequence and verify that its state remains frozen.
        i_stop = 1'b1;
        @(negedge clk);
        i_stop = 1'b0;

        if (o_running)
            $fatal(1, "PRBS remained running after i_stop.");

        for (int j = 0; j < P; j++)
            stopped_output[j] = o_prbs[j];

        repeat (4) @(negedge clk);

        for (int j = 0; j < P; j++) begin
            if (o_prbs[j] !== stopped_output[j])
                $fatal(1, "PRBS output changed while stopped on lane %0d.", j);
        end

        //! A new start must reload the programmed seed and order.
        i_seed  = 15'h7FFF;
        i_sel   = 3'b101;
        i_start = 1'b1;
        @(negedge clk);
        i_start = 1'b0;

        for (int j = 0; j < P; j++) begin
            if (o_prbs[j] !== reference[j])
                $fatal(1, "PRBS did not reload its seed on lane %0d.", j);
        end
        
        $display("Assertion completed.");
        $display("Number of assertions SUCCEEDED: %0d", match_count);
        $display("Number of assertions FAILED: %0d", (N_DATA - match_count));

        if (match_count != N_DATA)
            $fatal(1, "PRBS sequence does not match the reference.");

        $display("");
        $display("========================================");
        $display("PRBS Simulation Finished");
        $display("========================================");
        $display("");

        $finish;
    end

    initial begin
        #20us;

        $fatal(1, "Simulation timeout at time %0t", $time);
    end

endmodule;
