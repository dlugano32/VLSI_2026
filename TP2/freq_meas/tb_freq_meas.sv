`timescale 1ps/1ps

//! @title Frequency Meas
//! @file tb_freq_meas.sv
//! @author dlugano
//! @date 31/07/2026

module tb_freq_meas ();

    //! Testbench parameters
    parameter int WIN_W = 19;
    parameter int CNT_W = 20;

    //! Measurement window in reference-clock cycles
    parameter int WINDOW_LEN = 266_667;

    //! Clock periods
    parameter time CLK_REF_PERIOD = 5_000ps; //! 200 MHz
    parameter time CLK_IN_PERIOD  = 1_332ps; //! Approximately 750 MHz

    //! Expected count
    parameter int EXPECTED_COUNT = (WINDOW_LEN * CLK_REF_PERIOD) / CLK_IN_PERIOD;

    //! DUT signals
    logic [CNT_W - 1 : 0] o_count;
    logic                 o_done;

    logic [WIN_W - 1 : 0] i_window_len;
    logic                 i_start;
    logic                 i_rst_n;
    logic                 i_clk_ref;
    logic                 i_clk_in;

    //! Testbench variables
    int measured_count;
    int count_error;

    logic [CNT_W - 1 : 0] stored_count;

    //! Instance of frequency meter
    freq_meas #(
        .WIN_W (WIN_W),
        .CNT_W (CNT_W)
    ) u_freq_meas (
        .o_count      (o_count),
        .o_done       (o_done),
        .i_window_len (i_window_len),
        .i_start      (i_start),
        .i_rst_n      (i_rst_n),
        .i_clk_ref    (i_clk_ref),
        .i_clk_in     (i_clk_in)
    );

    //! Reference-clock generation: 200 MHz
    initial i_clk_ref = 1'b0;
    always #(CLK_REF_PERIOD / 2) i_clk_ref = ~i_clk_ref;

    //! Input-clock generation: approximately 749.6 MHz
    initial i_clk_in = 1'b0;
    always #(CLK_IN_PERIOD / 2) i_clk_in = ~i_clk_in;

    //! Waveform generation
    initial begin
        $dumpfile("sim/waves/freq_meas.vcd");
        $dumpvars(0, tb_freq_meas);
    end

    //! Test sequence
    initial begin
        $display("");
        $display("========================================");
        $display("Frequency Meter Simulation Started");
        $display("========================================");

        //! Initial values
        i_rst_n      = 1'b0;
        i_start      = 1'b0;
        i_window_len = WINDOW_LEN;

        //! Keep the module in reset
        repeat (5) @(negedge i_clk_ref);
        i_rst_n = 1'b1;

        repeat (5) @(negedge i_clk_ref);
        i_start = 1'b1;
        @(negedge i_clk_ref);
        i_start = 1'b0;

        //! Wait for done status
        wait (o_done == 1'b1);

        $display("Measurement is done. Count is available");

        //! Store the measured result
        stored_count = o_count;
        count_error = o_count - EXPECTED_COUNT;

        if (count_error < 0) begin
            count_error = -count_error;
        end

        $display("");
        $display("Reference-clock period : %0t", CLK_REF_PERIOD);
        $display("Input-clock period     : %0t", CLK_IN_PERIOD);
        $display("Window cycles          : %0d", WINDOW_LEN);
        $display("Expected count         : %0d", EXPECTED_COUNT);
        $display("Measured count         : %0d", stored_count);
        $display("Absolute error         : %0d", count_error);

        //! Verify that o_done and o_count remains stables after count was finished
        repeat (10) @(posedge i_clk_ref);

        if (o_done == 1'b1) begin
            $display("PASS: o_done flag is still up.");
        end else begin
            $error("FAILED: o_done flag is down.");
        end

        if (o_count !== stored_count) begin
            $error("FAIL: o_count changed after the measurement completed.");
        end else begin
            $display("PASS: o_count remained stable after completion.");
        end

        //! Start a second measurement
        @(negedge i_clk_ref);
        i_start = 1'b1;
        @(negedge i_clk_ref);
        i_start = 1'b0;

        //! The previous result must be invalidated immediately
        @(posedge i_clk_ref);

        if (o_done !== 1'b0) begin
            $error("FAIL: o_done was not cleared after starting again.");
        end else begin
            $display("PASS: o_done was cleared after starting again.");
        end

        repeat (5) @(posedge i_clk_ref);

        //! Checking if changing window_len in the middle of the count breaks the sequence
        i_window_len = '0;

        //! Wait for the second result
        wait (o_done == 1'b1);

        if (o_count == stored_count) begin
            $display("PASS: second measurement matches the first one.");
        end else begin
            $display("WARNING: Measurements differ. First=%0d, second=%0d.", stored_count, o_count);
        end

        $display("");
        $display("========================================");
        $display("Frequency Meter Simulation Finished");
        $display("========================================");
        $display("");

        $finish;
    end

    //! Simulation timeout
    initial begin
        #1s;

        $fatal(
            1,
            "Simulation timeout at time %0t.",
            $time
        );
    end

endmodule