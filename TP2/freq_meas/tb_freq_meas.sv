`timescale 1ps/1ps

//! @title Frequency Meter - Testbench
//! @file tb_freq_meter.sv
//! @author dlugano
//! @date 20/07/2026

module tb_freq_meter ();

    //! Testbench parameters
    parameter int WIN_W = 19;
    parameter int CNT_W = 20;

    //! Measurement window in reference-clock cycles
    parameter int WINDOW_LEN = 266_667;

    //! Clock periods
    parameter time CLK_REF_PERIOD = 5_000ps; //! 200 MHz
    parameter time CLK_IN_PERIOD  = 1_334ps; //! Approximately 749.6 MHz

    //! Expected count
    parameter int EXPECTED_COUNT = (WINDOW_LEN * CLK_REF_PERIOD) / CLK_IN_PERIOD;

    //! CDC uncertainty tolerance
    parameter int COUNT_TOLERANCE = 4;

    //! DUT signals
    logic [CNT_W - 1 : 0] o_count;
    logic                 o_done;

    logic [WIN_W - 1 : 0] i_window_len;
    logic                 i_rst_n;
    logic                 i_clk_ref;
    logic                 i_clk_in;

    //! Testbench variables
    int measured_count;
    int count_error;

    logic [CNT_W - 1 : 0] stored_count;

    //! Instance of frequency meter
    freq_meter #(
        .WIN_W (WIN_W),
        .CNT_W (CNT_W)
    ) u_freq_meter (
        .o_count      (o_count),
        .o_done       (o_done),
        .i_window_len (i_window_len),
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
        $dumpfile("sim/waves/freq_meter.vcd");
        $dumpvars(0, tb_freq_meter);
    end

    //! Test sequence
    initial begin
        $display("");
        $display("========================================");
        $display("Frequency Meter Simulation Started");
        $display("========================================");

        //! Initial values
        i_rst_n      = 1'b0;
        i_window_len = WINDOW_LEN;

        //! Keep the module in reset
        repeat (5) @(posedge i_clk_ref);

        //! Release the asynchronous reset away from a clock edge
        @(negedge i_clk_ref);
        i_rst_n = 1'b1;

        //! Wait for the result-valid pulse
        wait (o_done == 1'b1);

        $display("Done check");

        //! Store the measured result
        measured_count = int'(o_count);
        stored_count   = o_count;

        count_error = measured_count - EXPECTED_COUNT;

        if (count_error < 0) begin
            count_error = -count_error;
        end

        $display("");
        $display("Reference-clock period : %0t", CLK_REF_PERIOD);
        $display("Input-clock period     : %0t", CLK_IN_PERIOD);
        $display("Window cycles          : %0d", WINDOW_LEN);
        $display("Expected count         : %0d", EXPECTED_COUNT);
        $display("Measured count         : %0d", measured_count);
        $display("Absolute error         : %0d", count_error);

        //! Verify the measured count
        if (count_error <= COUNT_TOLERANCE) begin
            $display("PASS: Frequency count is within tolerance.");
        end else begin
            $error("FAIL: Expected approximately %0d counts, obtained %0d.", EXPECTED_COUNT, measured_count);
        end

        //! Verify that o_done is deasserted on the following reference cycle
        @(posedge i_clk_ref);
        #1ps;

        if (o_done !== 1'b0) begin
            $error("FAIL: o_done lasted longer than one reference-clock cycle.");
        end else begin
            $display("PASS: o_done was asserted for one reference-clock cycle.");
        end

        //! Verify that o_count remains stable after the measurement
        repeat (5) @(posedge i_clk_ref);

        if (o_count !== stored_count) begin
            $error("FAIL: o_count changed after the measurement completed.");
        end else begin
            $display("PASS: o_count remained stable after completion.");
        end

        //! Assert reset again
        i_rst_n = 1'b0;

        //! Allow both internal reset synchronizers to react
        repeat (5) @(posedge i_clk_ref);

        //! Verify reset behavior
        if (o_done !== 1'b0) begin
            $error("FAIL: o_done was not cleared by reset.");
        end

        if (o_count !== '0) begin
            $error("FAIL: o_count was not cleared by reset.");
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