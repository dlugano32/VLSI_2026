`timescale 1ps/1ps

//! @title Diagnostic Unit Testbench
//! @file tb_du.sv
//! @author dlugano
//! @date 01/08/2026

module tb_du ();

    //! DUT parameters
    localparam int WIDTH  = 1;
    localparam int DEPTH  = 256; // Debe ser siempre potencia de 2
    localparam int ADDR_W = $clog2(DEPTH);

    //! Input-data memory parameters
    localparam int N_DATA      = 1024;
    localparam int DATA_ADDR_W = $clog2(N_DATA);

    //! Clock periods
    localparam time WR_CLK_PERIOD = 1ns; //! DSP: 1 GHz
    localparam time RD_CLK_PERIOD = 5ns; //! CPU: 200 MHz

    //! DUT inputs
    logic                        i_arm;
    logic                        i_trigger;
    logic                [1 : 0] i_mode;
    logic signed [WIDTH - 1 : 0] data_r;
    logic                        i_wr_clk;
    logic                        i_wr_rst_n;
    logic                        i_rd_clk;
    logic                        i_rd_rst_n;
    logic                        i_rd_en;
    logic       [ADDR_W - 1 : 0] i_rdaddr;

    //! DUT outputs
    logic signed [WIDTH - 1 : 0] o_data;
    logic                        o_rd_valid;
    logic       [ADDR_W - 1 : 0] o_ptr;
    logic                        o_done;

    //! Input-data memory
    logic  [WIDTH       - 1 : 0] reference [N_DATA - 1 : 0];
    logic  [DATA_ADDR_W - 1 : 0] ptr_rd;
    logic  [DATA_ADDR_W - 1 : 0] data_idx_r;
    logic  [DATA_ADDR_W - 1 : 0] trigger_idx_r;

    //! Output-data memory
    logic        [WIDTH - 1 : 0] stored_data [DEPTH - 1 : 0];
    
    //! TB vars
    int match_count = 0;
    int expected_idx = 0;

    //! Clock generators
    initial i_wr_clk = 1'b0;
    always #(WR_CLK_PERIOD / 2) i_wr_clk = ~i_wr_clk;

    initial i_rd_clk = 1'b0;
    always #(RD_CLK_PERIOD / 2) i_rd_clk = ~i_rd_clk;

    //! Load the input samples
    initial begin
        $readmemb("sim/tb/mem/prbs10_reference.mem", reference);
    end

    //! Generate one input sample per clock cycle
    //! Data is updated on the falling edge so that it remains stable before the DU captures it on the following rising edge.
    always_ff @(negedge i_wr_clk or negedge i_wr_rst_n) begin
        if (!i_wr_rst_n) begin
            data_r <= '0;
            ptr_rd <= '0;
            data_idx_r <= '0;
        end else begin
            data_r <= reference[ptr_rd];
            ptr_rd <= ptr_rd + 1'b1;    // Wrap around counter
            data_idx_r <= ptr_rd;
        end
    end
    
    //! Saves the index of the input array to the DU when the trigger is active
    always_ff @(posedge i_wr_clk or negedge i_wr_rst_n) begin
        if (!i_wr_rst_n) begin
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
        .i_wr_clk   (i_wr_clk),
        .i_wr_rst_n (i_wr_rst_n),
        .i_arm      (i_arm),
        .i_trigger  (i_trigger),
        .i_mode     (i_mode),
        .i_data     (data_r),

        .i_rd_clk   (i_rd_clk),
        .i_rd_rst_n (i_rd_rst_n),
        .i_rd_en    (i_rd_en),
        .i_rdaddr   (i_rdaddr),

        .o_data     (o_data),
        .o_rd_valid (o_rd_valid),
        .o_ptr      (o_ptr),
        .o_done     (o_done)
    );

    //! Read the complete dual-clock memory in chronological order. The read
    //! port returns one registered sample per CPU clock while o_rd_valid is up.
    task automatic read_capture(input logic [ADDR_W - 1 : 0] start_addr);
        @(negedge i_rd_clk);
        i_rd_en   = 1'b1;
        i_rdaddr  = start_addr;

        for (int i = 0; i < DEPTH; i++) begin
            @(posedge i_rd_clk);
            #1ps;

            if (!o_rd_valid)
                $fatal(1, "DU read response was not valid for sample %0d.", i);

            stored_data[i] = o_data;

            @(negedge i_rd_clk);
            i_rdaddr = i_rdaddr + 1'b1;
        end

        i_rd_en = 1'b0;
    endtask

    //! Wrap a potentially negative or overflowing reference index into the
    //! valid [0, N_DATA-1] range. SystemVerilog remainder keeps the sign of
    //! its left operand, hence the second modulo operation.
    function automatic int wrap_reference_idx(input int idx);
        return ((idx % N_DATA) + N_DATA) % N_DATA;
    endfunction

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
        i_wr_rst_n = 1'b0;
        i_rd_rst_n = 1'b0;
        i_arm      = 1'b0;
        i_trigger  = 1'b0;
        i_mode     = 2'b00;
        i_rd_en    = 1'b0;
        i_rdaddr   = '0;

        //! Release each reset synchronously in its own clock domain.
        fork
            begin
                repeat (5) @(posedge i_wr_clk);
                #1ps;
                i_wr_rst_n = 1'b1;
            end
            begin
                repeat (5) @(posedge i_rd_clk);
                #1ps;
                i_rd_rst_n = 1'b1;
            end
        join

        $display("");
        $display("================================================================");
        $display("Test 1: MID mode");
        $display("================================================================");
        $display("");

        match_count = 0;
        expected_idx = 0;

        //! Arm the DU and store the selected mode
        @(negedge i_wr_clk);
        i_mode = 2'b01;
        i_arm  = 1'b1;

        @(negedge i_wr_clk);
        i_arm = 1'b0;

        //! Allow the circular buffer to wrap before applying the trigger
        repeat (DEPTH) @(negedge i_wr_clk);
        
        //! Generate a one-cycle trigger pulse
        i_trigger = 1'b1;

        @(negedge i_wr_clk);
        i_trigger = 1'b0;

        //! Wait until the post-trigger capture is complete
        wait (o_done);

        $display("");
        $display("DU finished capturing the signal.");
        $display("Oldest sample address: o_ptr = %0d", o_ptr);

        //! Read the complete circular buffer in chronological order
        read_capture(o_ptr);

        //! Check wether the stored_data relates to the input data in the triggered moment
        for (int i = 0; i < DEPTH; i++) begin
            expected_idx = wrap_reference_idx( int'(trigger_idx_r) - (DEPTH / 2) + i );

            if (stored_data[i] == reference[expected_idx])
                match_count++;

            $display("Sample %0d: expected reference[%0d]=%0d, got=%0d", i, expected_idx, reference[expected_idx], stored_data[i]);
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
        @(negedge i_wr_clk);
        i_mode = 2'b00;
        i_arm  = 1'b1;

        @(negedge i_wr_clk);
        i_arm = 1'b0;

        //! Allow the circular buffer to wrap before applying the trigger
        repeat (DEPTH) @(negedge i_wr_clk);
        
        //! Generate a one-cycle trigger pulse
        i_trigger = 1'b1;

        @(negedge i_wr_clk);
        i_trigger = 1'b0;

        //! Wait until the post-trigger capture is complete
        wait (o_done);

        $display("");
        $display("DU finished capturing the signal.");
        $display("Oldest sample address: o_ptr = %0d", o_ptr);

        //! Read the complete circular buffer in chronological order
        read_capture(o_ptr);

        //! Check wether the stored_data relates to the input data in the triggered moment
        for (int i = 0; i < DEPTH; i++) begin
            expected_idx = wrap_reference_idx( int'(trigger_idx_r) - (DEPTH - 1) + i);

            if (stored_data[i] == reference[expected_idx])
                match_count++;

            $display("Sample %0d: expected reference[%0d]=%0d, got=%0d", i, expected_idx, reference[expected_idx], stored_data[i]);
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
        @(negedge i_wr_clk);
        i_mode = 2'b10;
        i_arm  = 1'b1;

        @(negedge i_wr_clk);
        i_arm = 1'b0;

        //! Allow the circular buffer to wrap before applying the trigger
        repeat (DEPTH) @(negedge i_wr_clk);
        
        //! Generate a one-cycle trigger pulse
        i_trigger = 1'b1;

        @(negedge i_wr_clk);
        i_trigger = 1'b0;

        //! Wait until the post-trigger capture is complete
        wait (o_done);

        $display("");
        $display("DU finished capturing the signal.");
        $display("Oldest sample address: o_ptr = %0d", o_ptr);

        //! Read the complete circular buffer in chronological order
        read_capture(o_ptr);

        //! Check wether the stored_data relates to the input data in the triggered moment
        for (int i = 0; i < DEPTH; i++) begin
            expected_idx = wrap_reference_idx(int'(trigger_idx_r) + i);

            if (stored_data[i] == reference[expected_idx])
                match_count++;

            $display("Sample %0d: expected reference[%0d]=%0d, got=%0d", i, expected_idx, reference[expected_idx], stored_data[i]);
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
