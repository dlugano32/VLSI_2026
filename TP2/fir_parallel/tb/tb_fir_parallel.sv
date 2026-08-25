`timescale 1ps/1ps

//! @title Parallel FIR Filter - Testbench
//! @file tb_fir_parallel.sv
//! @brief Checks the P parallel FIR outputs against golden reference.

module tb_fir_parallel ();

    //! DUT parameters
    localparam int NB_I      = 2;
    localparam int NB_O      = 12;
    localparam int NBF_O     = 10;
    localparam int NB_TAPS   = 12;
    localparam int NBF_TAPS  = 10;
    localparam int N_TAPS    = 19;
    localparam int P         = 4;
    localparam int N_PREADD  = (N_TAPS + 1) / 2;

    //! Test-vector sizes
    localparam int N_IDATA      = 192;
    localparam int N_ODATA      = 210;
    localparam int N_OUT_CYCLES = (N_ODATA + P - 1) / P;

    //! Clock period
    localparam time CLK_T = 1ns; //! 1GHz

    //! DUT signals
    logic signed [NB_O    - 1 : 0] yn     [P - 1 : 0];
    logic signed [NB_I    - 1 : 0] xn     [P - 1 : 0];
    logic signed [NB_TAPS - 1 : 0] i_taps [N_PREADD - 1 : 0];
    logic i_en;
    logic i_rst_n;
    logic clk;

    //! Golden vectors
    logic signed [NB_I - 1 : 0] input_data    [N_IDATA - 1 : 0];
    logic signed [NB_O - 1 : 0] expected_data [N_ODATA - 1 : 0];
    logic signed [NB_TAPS - 1 : 0] coeff_data [N_TAPS - 1 : 0];

    //! Test counters
    int unsigned match_count;
    int unsigned error_count;

    initial begin
        assert ((N_IDATA % P) == 0)
            else $fatal(1, "N_IDATA must be a multiple of P.");

        assert (N_ODATA == (N_IDATA + N_TAPS - 1))
            else $fatal(1, "N_ODATA must match the complete FIR convolution length.");
    end

    //! Load coefficients, input samples and serialized expected output.
    initial begin
        $readmemh("sim/tb/coeffs_Q12_10.hex", coeff_data);
        $readmemh("sim/tb/pam2_input_Q2_0.hex", input_data);
        $readmemh("sim/tb/pam2_expected_Q12_10.hex", expected_data);

        for (int tap = 0; tap < N_PREADD; tap++)
            i_taps[tap] = coeff_data[tap];
    end

    //! Clock generation
    initial clk = 1'b0;
    always #(CLK_T / 2) clk = ~clk;

    //! DUT instance
    fir_parallel #(
        .NB_O      (NB_O),
        .NBF_O     (NBF_O),
        .NB_TAPS   (NB_TAPS),
        .NBF_TAPS  (NBF_TAPS),
        .N_TAPS    (N_TAPS),
        .P         (P)
    ) u_fir_parallel (
        .o_data  (yn),
        .i_data  (xn),
        .i_taps  (i_taps),
        .i_en    (i_en),
        .i_rst_n (i_rst_n),
        .i_clk   (clk)
    );

    //! Waveform generation
    initial begin
        $dumpfile("sim/waves/tb_fir_parallel.vcd");
        $dumpvars(0, tb_fir_parallel);
    end

    initial begin : test_sequence
        int input_idx;
        int output_idx;

        $display("");
        $display("========================================");
        $display("Parallel FIR Simulation Started");
        $display("========================================");
        $display("");

        i_en        = 1'b0;
        i_rst_n     = 1'b0;
        match_count = 0;
        error_count = 0;

        //! Initial reset
        repeat(5) @(posedge clk);
        #1ps;
        i_rst_n = 1'b1;

        //! Apply one group of P samples per cycle.
        @(negedge clk);
        i_en = 1'b1;

        for (int cycle = 0; cycle < N_OUT_CYCLES; cycle++) begin
            for (int lane = 0; lane < P; lane++) begin
                input_idx = cycle * P + lane;

                if (input_idx < N_IDATA)
                    xn[lane] = input_data[input_idx];
                else
                    xn[lane] = '0; //! Zero padding for the convolution tail
            end

            @(negedge clk);

            for (int lane = 0; lane < P; lane++) begin
                output_idx = cycle * P + lane;

                if (output_idx < N_ODATA) begin
                    if (yn[lane] === expected_data[output_idx]) begin
                        match_count++;
                    end else begin
                        error_count++;
                        $error(
                            "Mismatch: cycle=%0d lane=%0d output_idx=%0d expected=0x%0h actual=0x%0h",
                            cycle,
                            lane,
                            output_idx,
                            expected_data[output_idx],
                            yn[lane]
                        );
                    end
                end
            end
        end

        i_en = 1'b0;

        $display("");
        $display("Checked samples : %0d", N_ODATA);
        $display("Matched samples : %0d", match_count);
        $display("Failed samples  : %0d", error_count);
        $display("");

        if (error_count != 0)
            $fatal(1, "Parallel FIR regression failed with %0d mismatches.", error_count);

        if (match_count != N_ODATA)
            $fatal(1, "Parallel FIR regression did not check every expected output.");

        $display("========================================");
        $display("Parallel FIR Simulation Finished: PASS");
        $display("========================================");
        $display("");

        $finish;
    end

    //! Simulation timeout
    initial begin
        #20us;
        $fatal(1, "Simulation timeout at time %0t.", $time);
    end

endmodule
