`timescale 1ps/1ps

module tb_prbs_parallel();

    localparam int MAX_ORDER = 15;
    localparam int P = 4;

    localparam int NB_DATA = 1;
    localparam int N_DATA = 2**10;
    localparam int N_CLK_DELAY = 1;

    logic i_rst_n;
    logic i_en;
    logic [2 : 0] i_sel;
    logic [MAX_ORDER - 1 : 0] i_seed;
    logic o_prbs [P  - 1 : 0];

    logic [$clog2(N_DATA + N_CLK_DELAY + 1) - 1 : 0] cnt;
    logic reference [0 : N_DATA-1];

    //! Clock
    logic clk;

    parameter time CLK_T  = 4_000ps; //! 250 MHz
    
    //! Clock generation: 250MHz
    initial clk = 1'b1;
    always #(CLK_T / 2) clk = ~clk;

    //! DUT instantiation
    prbs_parallel # (
        .MAX_ORDER(MAX_ORDER),
        .P(P)
    ) u_prbs_parallel_gen (
        .i_clk(clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_sel(i_sel),
        .i_seed(i_seed),

        .o_prbs(o_prbs)
    );

    initial begin
        $readmemb(
            "sim/tb/mem/prbs10_reference.mem",
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
        i_en    = 1'b0;
        i_rst_n = 1'b0;
        i_seed  = 15'h7FFF;
        i_sel   = 3'b000;

        cnt = '0;

        repeat (4) @(negedge clk);

        i_rst_n = 1'b1;

        repeat (4) @(negedge clk);
        
        for(int i; i<(N_DATA/P); i++) begin
            for(int j; j<P; j++) begin
                if( o_prbs[j] == reference[j+i*P] )
                    cnt ++;
            end

            i_en = 1'b1; // Primero se hace el assertion de la salida debido a la seed, ya que la salida es directamente combinacional.
            @(negedge clk);
        end

        i_en = 1'b0;
        
        $display("Assertion completed.");
        $display("Number of assertions SUCCEEDED: %0d", cnt);
        $display("Number of assertions FAILED: %0d", (N_DATA - cnt));

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