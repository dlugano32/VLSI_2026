`timescale 1ps/1ps

//! @title Polyphase FIR Filter - Testbench
//! @file tb_pp_filter.sv

module tb_pp_filter;

    import fir_pkg::*;
    import pp_filter_pkg::*;

    localparam time CLK_T = 1ns;

    // Cantidad de valores presentes en cada archivo de vectores
    localparam int N_IDATA  = 192;
    localparam int N_COEFFS = N_PHASES * N_TAPS; // 4 fases * 5 taps
    localparam int N_ODATA  = 262;

    // Cantidad de ciclos necesarios
    localparam int N_INPUT_CYCLES  = (N_IDATA + PAR_IN  - 1) / PAR_IN;
    localparam int N_OUTPUT_CYCLES = (N_ODATA + PAR_OUT - 1) / PAR_OUT;
    // Se pueden usar 2 ciclos mas para el flush
    localparam int N_TEST_STEPS    = (N_INPUT_CYCLES > (N_OUTPUT_CYCLES + 2)) ? N_INPUT_CYCLES : (N_OUTPUT_CYCLES + 2);

    localparam string INPUT_FILE    = "sim/vectors/pam2_input_Q2_0.hex";
    localparam string COEFF_FILE    = "sim/vectors/coeffs_polyphase_Q12_10.hex";
    localparam string EXPECTED_FILE = "sim/vectors/pam2_polyphase_expected_Q12_10.hex";

    logic       clk;
    pp_din_t    i_data;
    pp_coeffs_t i_coeffs;
    pp_out_t    o_data;

    // Los archivos son seriales: una muestra hexadecimal por linea
    din_t   input_data    [0 : N_IDATA  - 1];
    coeff_t coeff_data    [0 : N_COEFFS - 1];
    dout_t  expected_data [0 : N_ODATA  - 1];

    int unsigned match_count;
    int unsigned error_count;

    pp_filter u_pp_filter (
        .clk      (clk),
        .i_data   (i_data),
        .i_coeffs (i_coeffs),
        .o_data   (o_data)
    );

    initial clk = 1'b0;
    always #(CLK_T / 2) clk = ~clk;

    initial begin : waveform
        $dumpfile("tb_pp_filter.vcd");
        $dumpvars(0, tb_pp_filter);
    end

    initial begin : test_sequence
        int input_idx;
        int output_idx;
        int output_block;

        i_data      = '0;
        i_coeffs    = '0;
        match_count = 0;
        error_count = 0;

        $readmemh(INPUT_FILE,    input_data);
        $readmemh(COEFF_FILE,    coeff_data);
        $readmemh(EXPECTED_FILE, expected_data);

        // El archivo de coeficientes esta ordenado primero por fase y luego por tap: coeff_data[phase*N_TAPS + tap].
        for (int phase = 0; phase < N_PHASES; phase++) begin
            for (int tap = 0; tap < N_TAPS; tap++) begin
                i_coeffs[phase][tap] = coeff_data[phase * N_TAPS + tap];
            end
        end

        $display("");
        $display("========================================");
        $display("Polyphase FIR Simulation Started");
        $display("Input samples : %0d", N_IDATA);
        $display("Coefficients  : %0d (%0d phases x %0d taps)", N_COEFFS, N_PHASES, N_TAPS);
        $display("Output samples: %0d", N_ODATA);
        $display("PAR_IN=%0d, PAR_OUT=%0d, UP/DW=%0d/%0d", PAR_IN, PAR_OUT, UP, DW);
        $display("========================================");

        // El DUT no tiene reset. Este primer input de ceros inicializa mem y los registros internos de los FIR antes del primer bloque util.
        // Siendo el latency del modulo de 2 ciclos: uno para registrar la entrada y otro para registrar la salida
        @(negedge clk);
        i_data = '0;

        for (int step = 0; step < N_TEST_STEPS; step++) begin
            @(negedge clk);

            
            output_block = step - 2;

            if ((output_block >= 0) && (output_block < N_OUTPUT_CYCLES)) begin
                for (int lane = 0; lane < PAR_OUT; lane++) begin
                    output_idx = output_block * PAR_OUT + lane;

                    // El ultimo bloque puede estar incompleto.
                    if (output_idx < N_ODATA) begin
                        if (o_data[lane] === expected_data[output_idx]) begin
                            match_count++;
                        end else begin
                            error_count++;
                            $error({"Mismatch: block=%0d lane=%0d sample=%0d ", "expected=0x%0h actual=0x%0h"},
                                output_block,
                                lane,
                                output_idx,
                                expected_data[output_idx],
                                o_data[lane]
                            );
                        end
                    end
                end
            end

            // Se agrupan PAR_IN muestras seriales en cada palabra de entrada.
            // El ultimo bloque se completa con ceros.
            for (int lane = 0; lane < PAR_IN; lane++) begin
                input_idx = step * PAR_IN + lane;

                if (input_idx < N_IDATA)
                    i_data[lane] = input_data[input_idx];
                else
                    i_data[lane] = '0;
            end
        end

        $display("");
        $display("Checked samples: %0d", N_ODATA);
        $display("Matched samples: %0d", match_count);
        $display("Failed samples : %0d", error_count);

        if (error_count != 0)
            $fatal(1, "Polyphase FIR regression failed.");

        if (match_count != N_ODATA)
            $fatal(1, "No se verificaron todas las muestras esperadas.");

        $display("========================================");
        $display("Polyphase FIR Simulation Finished: PASS");
        $display("========================================");
        $finish;
    end

    initial begin : timeout
        #20us;
        $fatal(1, "Simulation timeout at time %0t.", $time);
    end

endmodule
