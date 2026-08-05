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
    localparam time CLK_PERIOD = 4ns; //! 250 MHz

    //! DUT inputs
    logic                   i_arm;
    logic                   i_trigger;
    logic [          1 : 0] i_mode;
    logic [WIDTH   - 1 : 0] data_r;
    logic                   clk;
    logic                   i_rst_n;
    logic [ADDR_W -  1 : 0] i_rdaddr;

    //! DUT outputs
    logic [WIDTH  - 1 : 0] o_data;
    logic [ADDR_W - 1 : 0] o_ptr;
    logic                  o_done;

    //! Input-data memory
    logic [WIDTH       - 1 : 0] mem_data [N_DATA - 1 : 0];
    logic [DATA_ADDR_W - 1 : 0] ptr_rd;
    logic [DATA_ADDR_W - 1 : 0] data_idx_r;
    logic [DATA_ADDR_W - 1 : 0] trigger_idx_r;

    //! Output-data memory
    logic [WIDTH  - 1 : 0] stored_data   [DEPTH - 1 : 0];
    
    //! TB vars
    int match_count = 0;
    int expected_idx = 0;

    //! Clock generator
    initial clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    //! Load the input samples
    initial begin
        $readmemb("sim/tb/mem/prbs10_reference.mem", mem_data);
    end

    //! Generate one input sample per clock cycle
    //! Data is updated on the falling edge so that it remains stable before the DU captures it on the following rising edge.
    always @(negedge clk) begin
        if (!i_rst_n) begin
            data_r <= '0;
            ptr_rd <= '0;
            data_idx_r <= '0;
        end else begin
            data_r <= mem_data[ptr_rd];
            ptr_rd <= ptr_rd + 1'b1;    // Wrap around counter
            data_idx_r <= ptr_rd;
        end
    end
    
    //! Saves the index of the input array to the DU when the trigger is active
    always @(posedge clk) begin
        if (!i_rst_n) begin
            trigger_idx_r <= '0;
        end else if (i_trigger) begin
            trigger_idx_r <= data_idx_r;
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
        .i_rdaddr  (i_rdaddr),

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
        i_rdaddr  = '0;

        //! Keep the DUT in reset
        repeat (5) @(negedge clk);

        //! Release reset away from the DUT active clock edge
        i_rst_n = 1'b1;

        $display("");
        $display("================================================================");
        $display("Test 1: MID mode");
        $display("================================================================");
        $display("");

        match_count = 0;
        expected_idx = 0;

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
        i_rdaddr = o_ptr;

        $display("");
        $display("DU finished capturing the signal.");
        $display("Oldest sample address: o_ptr = %0d", o_ptr);

        //$display("");
        //$display("Captured samples:");
        //$display("");

        //! Read the complete circular buffer in chronological order
        for (int i = 0; i < DEPTH; i++) begin
            //! Allow the combinational memory output to settle
            @(negedge clk);
            stored_data[i] = o_data;
            //$display("sample[%0d] | du_mem[%0d] = %0d", i, i_rdaddr, o_data);

            i_rdaddr = i_rdaddr + 1'b1;
        end

        //$display("");
        //$display("Captured autocheking with known signal:");
        //$display("");

        //! Check wether the stored_data relates to the input data in the triggered moment
        for (int i = 0; i < DEPTH; i++) begin
            expected_idx = int'(trigger_idx_r) - (DEPTH / 2) + i;



            if (stored_data[i] == mem_data[expected_idx])
                match_count++;

            //$display("Sample %0d: expected mem_data[%0d]=%0d, got=%0d", i, expected_idx, mem_data[expected_idx], stored_data[i]);
        end

        $display("");
        $display("Matched samples : %0d/%0d", match_count, DEPTH); 
        $display("");


        $display("");
        $display("================================================================");
        $display("Test 2: PRE mode");
        $display("================================================================");
        $display("");

        match_count = 0;
        expected_idx = 0;

        //! Arm the DU and store the selected mode
        i_mode = 2'b00;
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
        i_rdaddr = o_ptr;

        $display("");
        $display("DU finished capturing the signal.");
        $display("Oldest sample address: o_ptr = %0d", o_ptr);

        //$display("");
        //$display("Captured samples:");
        //$display("");

        //! Read the complete circular buffer in chronological order
        for (int i = 0; i < DEPTH; i++) begin
            //! Allow the combinational memory output to settle
            @(negedge clk);
            stored_data[i] = o_data;
            //$display("sample[%0d] | du_mem[%0d] = %0d", i, i_rdaddr, o_data);

            i_rdaddr = i_rdaddr + 1'b1;
        end

        //$display("");
        //$display("Captured autocheking with known signal:");
        //$display("");

        //! Check wether the stored_data relates to the input data in the triggered moment
        for (int i = 0; i < DEPTH; i++) begin
            expected_idx = int'(trigger_idx_r) - (DEPTH - 1) + i;   // offset is (DEPTH - 1) because trigger sample is stored

            if (stored_data[i] == mem_data[expected_idx])
                match_count++;

            //$display("Sample %0d: expected mem_data[%0d]=%0d, got=%0d", i, expected_idx, mem_data[expected_idx], stored_data[i]);
        end

        $display("");
        $display("Matched samples : %0d/%0d", match_count, DEPTH); 
        $display("");


        $display("");
        $display("================================================================");
        $display("Test 3: POST mode");
        $display("================================================================");
        $display("");

        match_count = 0;
        expected_idx = 0;

        //! Arm the DU and store the selected mode
        i_mode = 2'b10;
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
        i_rdaddr = o_ptr;

        $display("");
        $display("DU finished capturing the signal.");
        $display("Oldest sample address: o_ptr = %0d", o_ptr);

        //$display("");
        //$display("Captured samples:");
        //$display("");

        //! Read the complete circular buffer in chronological order
        for (int i = 0; i < DEPTH; i++) begin
            //! Allow the combinational memory output to settle
            @(negedge clk);
            stored_data[i] = o_data;
            ///$display("sample[%0d] | du_mem[%0d] = %0d", i, i_rdaddr, o_data);

            i_rdaddr = i_rdaddr + 1'b1;
        end

        //$display("");
        //$display("Captured autocheking with known signal:");
        //$display("");

        //! Check wether the stored_data relates to the input data in the triggered moment
        for (int i = 0; i < DEPTH; i++) begin
            expected_idx = int'(trigger_idx_r) + i;

            if (stored_data[i] == mem_data[expected_idx])
                match_count++;

            //$display("Sample %0d: expected mem_data[%0d]=%0d, got=%0d", i, expected_idx, mem_data[expected_idx], stored_data[i]);
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