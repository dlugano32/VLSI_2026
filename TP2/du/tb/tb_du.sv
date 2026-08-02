`timescale 1ps/1ps

//! @title Diagnostic Unit Testbench
//! @file tb_du.sv
//! @author dlugano
//! @date 01/08/2026

module tb_du ();

    //! DUT parameters
    localparam int WIDTH  = 1;
    localparam int DEPTH  = 64; // Debe ser siempre potencia de 2
    localparam int ADDR_W = $clog2(DEPTH);

    //! Input-data memory parameters
    localparam int N_DATA      = 1024;
    localparam int DATA_ADDR_W = $clog2(N_DATA);

    //! Clock period
    localparam time CLK_PERIOD = 4_000ps; //! 250 MHz

    //! DUT inputs
    logic                   i_arm;
    logic                   i_trigger;
    logic [          1 : 0] i_mode;
    logic [WIDTH   - 1 : 0] data_r;
    logic                   clk;
    logic                   i_rst_n;
    logic [ADDR_W -  1 : 0] i_add_rd;

    //! DUT outputs
    logic [WIDTH  - 1 : 0] o_data;
    logic [ADDR_W - 1 : 0] o_ptr;
    logic                  o_done;

    //! Input-data memory
    logic [WIDTH       - 1 : 0] mem_data [N_DATA - 1 : 0];
    logic [DATA_ADDR_W - 1 : 0] ptr_rd;
    logic [DATA_ADDR_W - 1 : 0] trigger_idx;

    //! Output-data memory
    logic [WIDTH  - 1 : 0] stored_data   [DEPTH - 1 : 0];
    
    int match_count = 0;

    //! Clock generator
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    //! Load the input samples
    initial begin
        $readmemb("sim/tb/mem/data.mem", mem_data);
    end

    //! Generate one input sample per clock cycle
    //! Data is updated on the falling edge so that it remains stable before the DU captures it on the following rising edge.
    always @(negedge clk) begin
        if (!i_rst_n) begin
            data_r <= '0;
            ptr_rd <= '0;
            trigger_idx <= '0;
        end else begin
            data_r <= mem_data[ptr_rd];
            ptr_rd <= ptr_rd + 1'b1;

            if(i_trigger)   // Tener en cuenta posible condición de carrera
                trigger_idx <= ptr_rd;

        end
    end

    //! DUT instance
    du #(
        .WIDTH (WIDTH),
        .DEPTH (DEPTH)
    ) u_du (
        .i_arm     (i_arm),
        .i_trigger (i_trigger),
        .i_mode    (i_mode),
        .i_data    (data_r),
        .i_clk     (clk),
        .i_rst_n   (i_rst_n),
        .i_add_rd  (i_add_rd),

        .o_data    (o_data),
        .o_ptr     (o_ptr),
        .o_done    (o_done)
    );

    //! Waveform generation
    initial begin
        $dumpfile("sim/waves/du.vcd");
        $dumpvars(0, tb_du);
    end

    //! Test sequence
    initial begin
        $display("");
        $display("========================================");
        $display("DU Simulation Started");
        $display("========================================");
        $display("");

        //! Initial values
        i_rst_n   = 1'b0;
        i_arm     = 1'b0;
        i_trigger = 1'b0;
        i_mode    = 2'b00;
        i_add_rd  = '0;

        //! Keep the DUT in reset
        repeat (5) @(negedge clk);

        //! Release reset away from the DUT active clock edge
        i_rst_n = 1'b1;

        //! ================================================================
        //! Test 1: MID mode
        //! ================================================================

        //! Arm the DU and store the selected mode
        i_mode = 2'b01;
        i_arm  = 1'b1;

        @(negedge clk);
        i_arm = 1'b0;

        //! Allow the circular buffer to wrap before applying the trigger
        repeat (64) @(negedge clk);

        //! Generate a one-cycle trigger pulse
        i_trigger = 1'b1;

        @(negedge clk);
        i_trigger = 1'b0;

        //! Wait until the post-trigger capture is complete
        wait (o_done);

        //! When the circular buffer is full, o_ptr points to the oldest stored sample.
        i_add_rd = o_ptr;

        $display("");
        $display("DU finished capturing the signal.");
        $display("Oldest sample address: %0d", o_ptr);
        $display("Captured samples:");

        //! Read the complete circular buffer in chronological order
        for (int i = 0; i < DEPTH; i++) begin
            //! Allow the combinational memory output to settle
            @(negedge clk);
            stored_data[i] = o_data;
            $display("sample[%0d] | mem[%0d] = %0d", i, i_add_rd, o_data);

            i_add_rd = i_add_rd + 1'b1;
        end

        //! Check wether the stored_data relates to the input data in the triggered moment
        for (int i = 0; i < DEPTH; i++) begin
            expected_idx = int'(trigger_sample_idx) - (DEPTH / 2) + i;

            if (stored_data[i] == mem_data[expected_idx])
                match_count++;
        end

        $display(""); 
        $display("Matched samples : %0d/%0d", match_count, DEPTH); 
        $display(""); 

        $display("");
        $display("========================================");
        $display("DU Simulation Finished");
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