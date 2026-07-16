`timescale 1ns/1ps

//! @title Frequency Meter - Testbench
//! @file tb_freq_meter.sv
//! @author dlugano
//! @date 16/07/2026

module tb_freq_meter ();

    //! Testbench parameters
    parameter int W_MAX = 10;
    parameter int CNT_W = 8;

    //! Clock periods
    parameter time CLK_REF = 100; //! 10 MHz
    parameter time CLK_IN  = 10;  //! 100 MHz

    //! Expected count
    parameter int EXPECTED_COUNT = 100;
    parameter int COUNT_TOLERANCE = 2;

    //! DUT signals
    logic [CNT_W - 1 : 0] o_cnt;
    logic                 o_done;

    logic i_rst_in;
    logic i_rst_ref;

    logic i_clk_ref;
    logic i_clk_in;

    //! Testbench variables
    int measured_count;
    int count_error;

    //! Instance of frequency meter
    freq_meter #(
        .W_MAX (W_MAX),
        .CNT_W (CNT_W)
    ) u_freq_meter (
        .o_cnt     (o_cnt),
        .o_done    (o_done),
        .i_rst_in  (i_rst_in),
        .i_rst_ref (i_rst_ref),
        .i_clk_ref (i_clk_ref),
        .i_clk_in  (i_clk_in)
    );

    //! Reference-clock generation: 10 MHz
    initial i_clk_ref=0;
    always  #(CLK_REF / 2) i_clk_ref = ~i_clk_ref;

    //! Input-clock generation: 100 MHz
    initial i_clk_in=0;
    always  #(CLK_IN / 2) i_clk_in = ~i_clk_in;

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

        //! Initial reset values
        i_rst_ref = 1'b1;
        i_rst_in  = 1'b1;

        //! Keep both clock domains in reset
        repeat (5) @(posedge i_clk_ref);

        //! Release reference-domain reset first
        i_rst_ref = 1'b0;

        //! Release input-domain reset before the next reference edge
        @(negedge i_clk_in);
        i_rst_in = 1'b0;

        //! Wait until the synchronized done flag is asserted
        wait (o_done == 1'b1);

        //! Wait one additional input-clock cycle
        @(posedge i_clk_in);

        //! Store the measured result
        measured_count = int'(o_cnt);
        count_error    = measured_count - EXPECTED_COUNT;

        if (count_error < 0) begin
            count_error = -count_error;
        end

        $display("");
        $display("Reference frequency : 10 MHz");
        $display("Input frequency     : 100 MHz");
        $display("Window cycles       : %0d", W_MAX);
        $display("Expected count      : %0d", EXPECTED_COUNT);
        $display("Measured count      : %0d", measured_count);
        $display("Absolute error      : %0d", count_error);

        //! Verify the measured count
        if (count_error <= COUNT_TOLERANCE) begin
            $display("");
            $display("PASS: Frequency count is within tolerance.");
        end else begin
            $error(
                "FAIL: Expected approximately %0d counts, obtained %0d.",
                EXPECTED_COUNT,
                measured_count
            );
        end

        //! Verify that o_done remains asserted
        repeat (5) @(posedge i_clk_in);

        if (o_done !== 1'b1) begin
            $error("FAIL: o_done did not remain asserted.");
        end else begin
            $display("PASS: o_done remained asserted after completion.");
        end

        //! Apply reset again
        i_rst_ref = 1'b1;
        i_rst_in  = 1'b1;

        repeat (2) @(posedge i_clk_in);

        //! Verify reset behavior
        if (o_done !== 1'b0) begin
            $error("FAIL: o_done was not cleared by reset.");
        end

        if (o_cnt !== '0) begin
            $error("FAIL: o_cnt was not cleared by reset.");
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
        #10us;

        $fatal(
            1,
            "Simulation timeout at time %0t.",
            $time
        );
    end

endmodule