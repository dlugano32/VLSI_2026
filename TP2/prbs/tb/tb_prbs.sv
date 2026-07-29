`timescale 1ns/1ps

module tb_prbs();

    localparam int MAX_ORDER = 15;

    localparam int NB_DATA = 1;
    localparam int N_DATA = 2**10;
    localparam int N_CLK_DELAY = 0;

    logic clk;
    logic i_rst_n;
    logic i_en;
    logic [2 : 0] i_sel;
    logic [MAX_ORDER - 1 : 0] i_seed;

    logic o_prbs;
    logic o_expected;
    logic [$clog2(N_DATA + N_CLK_DELAY + 1) - 1 : 0] o_cnt;
    logic o_flag;

    localparam time CLK_PERIOD = 4ns;
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    prbs # (
    .MAX_ORDER(MAX_ORDER)
    ) u_prbs_gen (
        .i_clk(clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_sel(i_sel),
        .i_seed(i_seed),

        .o_prbs(o_prbs)
    );

    tb_output_asserter #(
      .NB_DATA(NB_DATA),
      .N_DATA(N_DATA),
      .N_CLK_DELAY(N_CLK_DELAY),
      .MEM_INIT_FILE("sim/tb/mem/prbs10_reference.mem")
    ) u_output_asserter_0 (
        .i_asserted(o_prbs),
        .i_en(i_en),
        .i_clock(clk),
        .i_reset(~i_rst_n),

        .o_expected(o_expected),
        .o_cnt(o_cnt),
        .o_flag(o_flag)
      );

    //! Waves
    initial begin $dumpfile("sim/waves/prbs.vcd"); 
    $dumpvars(0,tb_prbs); end

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

        repeat (5) @(negedge clk);

        i_rst_n = 1'b1;

        repeat (2) @(negedge clk);

        i_en = 1'b1;

        wait(o_flag);

        @(negedge clk);

        i_en = 1'b0;
        $display("");
        $display("Assertion completed.");
        $display("Number of assertions SUCCEEDED: %0d", o_cnt);
        $display("Number of assertions FAILED: %0d", (N_DATA - o_cnt));

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