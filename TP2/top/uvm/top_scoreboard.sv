class top_scoreboard;

    localparam bit [7:0] ADDR_PRBS_CTRL      = 8'h00;
    localparam bit [7:0] ADDR_PRBS_STATUS    = 8'h02;
    localparam bit [7:0] ADDR_FIR_TAP_FIRST  = 8'h10;
    localparam bit [7:0] ADDR_FIR_TAP_LAST   = 8'h19;
    localparam bit [7:0] ADDR_FIR_CTRL       = 8'h1A;
    localparam bit [7:0] ADDR_FIR_STATUS     = 8'h1B;
    localparam bit [7:0] ADDR_DU_CTRL        = 8'h20;
    localparam bit [7:0] ADDR_DU_STATUS      = 8'h22;
    localparam bit [7:0] ADDR_DU_RDDATA      = 8'h24;
    localparam bit [7:0] ADDR_DU_SELECT      = 8'h26;
    localparam bit [7:0] ADDR_CLKMEAS_CTRL   = 8'h30;
    localparam bit [7:0] ADDR_CLKMEAS_WINDOW = 8'h31;
    localparam bit [7:0] ADDR_CLKMEAS_COUNT  = 8'h32;
    localparam bit [7:0] ADDR_CLKMEAS_STATUS = 8'h33;
    
    localparam time CLK_CPU_PERIOD = 5ns; //! 200 MHz
    localparam time CLK_DSP_PERIOD = 1ns; //! 1 GHz
    
    mailbox #(top_txn) mon2sb;

    int unsigned transaction_count;
    int unsigned error_count;

    int unsigned selected_lane;
    int unsigned sample_count [4];
    bit          sample_nonzero [4];

    bit prbs_start_seen;
    bit prbs_running_seen;
    bit prbs_stop_seen;
    bit prbs_stopped_seen;
    logic [9:0] fir_taps_written;
    bit fir_commit_seen;
    bit fir_busy_seen;
    bit fir_ready_seen;
    bit fir_enable_seen;
    bit du_arm_seen;
    bit du_clear_seen;
    bit du_done_seen;
    bit clkmeas_start_seen;
    bit clkmeas_done_seen;
    bit clkmeas_count_seen;

    int unsigned clkmeas_window;
    int unsigned clkmeas_count;

    function new(mailbox #(top_txn) mon2sb);
        this.mon2sb = mon2sb;
        transaction_count = 0;
        error_count       = 0;
        selected_lane     = 0;

        for (int lane = 0; lane < 4; lane++) begin
            sample_count[lane]       = 0;
            sample_nonzero[lane]     = 0;
        end

        prbs_start_seen    = 0;
        prbs_running_seen  = 0;
        prbs_stop_seen     = 0;
        prbs_stopped_seen  = 0;
        fir_taps_written   = '0;
        fir_commit_seen    = 0;
        fir_busy_seen      = 0;
        fir_ready_seen     = 0;
        fir_enable_seen    = 0;
        du_arm_seen        = 0;
        du_clear_seen      = 0;
        du_done_seen       = 0;
        clkmeas_start_seen = 0;
        clkmeas_done_seen  = 0;
        clkmeas_count_seen = 0;
        clkmeas_window     = 0;
        clkmeas_count      = 0;
    endfunction

    function void process(top_txn tr);
        transaction_count++;

        if (tr.kind == BUS_WRITE) begin
            if ((tr.addr >= ADDR_FIR_TAP_FIRST) && (tr.addr <= ADDR_FIR_TAP_LAST))
                fir_taps_written[tr.addr - ADDR_FIR_TAP_FIRST] = 1'b1;

            case (tr.addr)
                ADDR_PRBS_CTRL: begin
                    if (tr.wdata[0]) prbs_start_seen = 1'b1;
                    if (tr.wdata[1]) prbs_stop_seen  = 1'b1;
                end

                ADDR_FIR_CTRL: begin
                    if (tr.wdata[0]) fir_commit_seen = 1'b1;
                    if (tr.wdata[1]) fir_enable_seen = 1'b1;
                end

                ADDR_DU_CTRL: begin
                    if (tr.wdata[0]) du_arm_seen = 1'b1;
                end

                ADDR_DU_SELECT: begin
                    selected_lane = tr.wdata[1:0];
                end

                ADDR_CLKMEAS_WINDOW: begin
                    clkmeas_window = tr.wdata;
                end

                ADDR_CLKMEAS_CTRL: begin
                    if (tr.wdata[0]) clkmeas_start_seen = 1'b1;
                end
            endcase
        end else if (tr.kind == BUS_READ) begin
            if ($isunknown(tr.rdata)) begin
                error_count++;
                $error("Read returned X/Z: addr=0x%02h data=0x%08h", tr.addr, tr.rdata);
            end

            case (tr.addr)
                ADDR_PRBS_STATUS: begin
                    if (prbs_start_seen && tr.rdata[0])
                        prbs_running_seen = 1'b1;
                    if (prbs_stop_seen && !tr.rdata[0])
                        prbs_stopped_seen = 1'b1;
                end

                ADDR_FIR_STATUS: begin
                    if (fir_commit_seen && tr.rdata[0])
                        fir_busy_seen = 1'b1;
                    if (fir_busy_seen && !tr.rdata[0])
                        fir_ready_seen = 1'b1;
                end

                ADDR_DU_STATUS: begin
                    if (du_arm_seen && (tr.rdata[3:0] == 4'b0000))
                        du_clear_seen = 1'b1;
                    if (du_clear_seen && (tr.rdata[3:0] == 4'b1111))
                        du_done_seen = 1'b1;
                end

                ADDR_DU_RDDATA: begin
                    sample_count[selected_lane]++;

                    if (tr.rdata != 32'b0)
                        sample_nonzero[selected_lane] = 1'b1;
                end

                ADDR_CLKMEAS_STATUS: begin
                    if (clkmeas_start_seen && tr.rdata[0])
                        clkmeas_done_seen = 1'b1;
                end

                ADDR_CLKMEAS_COUNT: begin
                    clkmeas_count      = tr.rdata;
                    clkmeas_count_seen = 1'b1;
                end
            endcase
        end
    endfunction

    task run();
        top_txn tr;

        forever begin
            mon2sb.get(tr);
            process(tr);
        end
    endtask

    function void report();
        int unsigned expected_count;
        int unsigned count_error;
        bit frequency_pass;

        $display("");
        $display("========================================");
        $display("Top integration scoreboard");
        $display("========================================");

        if (prbs_start_seen && prbs_running_seen) begin
            $display("[PASS] PRBS configured and running.");
        end else begin
            error_count++;
            $error("PRBS running state was not observed.");
        end

        if (&fir_taps_written) begin
            $display("[PASS] All 10 FIR coefficients were written.");
        end else begin
            error_count++;
            $error("Not all FIR coefficients were written. Mask=0x%03h", fir_taps_written);
        end

        if (fir_commit_seen && fir_busy_seen && fir_ready_seen) begin
            $display("[PASS] FIR coefficient commit completed.");
        end else begin
            if (!fir_commit_seen) begin error_count++; $error("FIR commit was not observed."); end
            if (!fir_busy_seen)   begin error_count++; $error("FIR busy state was not observed."); end
            if (!fir_ready_seen)  begin error_count++; $error("FIR ready state was not observed after commit."); end
        end

        if (fir_enable_seen) begin
            $display("[PASS] FIR enabled.");
        end else begin
            error_count++;
            $error("FIR enable was not observed.");
        end

        if (du_arm_seen && du_clear_seen && du_done_seen) begin
            $display("[PASS] Four DUs armed and completed.");
        end else begin
            if (!du_arm_seen)   begin error_count++; $error("DU arm was not observed."); end
            if (!du_clear_seen) begin error_count++; $error("DU status did not clear after arm."); end
            if (!du_done_seen)  begin error_count++; $error("All four DUs did not complete."); end
        end

        for (int lane = 0; lane < 4; lane++) begin
            if (sample_count[lane] != 256) begin
                error_count++;
                $error("DU lane %0d returned %0d samples instead of 256.", lane, sample_count[lane]);
            end
            if (!sample_nonzero[lane]) begin
                error_count++;
                $error("DU lane %0d only returned zero.", lane);
            end

            if ((sample_count[lane] == 256) && sample_nonzero[lane])
                $display("[PASS] DU lane %0d: 256 samples read and nonzero data observed.", lane);
        end

        frequency_pass = 1'b1;

        if (!clkmeas_done_seen) begin
            error_count++;
            frequency_pass = 1'b0;
            $error("Frequency measurement did not complete.");
        end

        if (!clkmeas_count_seen) begin
            error_count++;
            frequency_pass = 1'b0;
            $error("Frequency count was not read.");
        end else begin
            //! Testbench clocks are 200 MHz (reference) and 1 GHz (input).
            expected_count = (clkmeas_window * CLK_CPU_PERIOD) / CLK_DSP_PERIOD;
            count_error = (clkmeas_count > expected_count)
                        ? (clkmeas_count - expected_count)
                        : (expected_count - clkmeas_count);

            if (count_error > (expected_count / 100)) begin
                error_count++;
                frequency_pass = 1'b0;
                $error("Frequency mismatch: expected=%0d measured=%0d", expected_count, clkmeas_count);
            end
        end

        if (frequency_pass)
            $display("[PASS] Frequency measurement completed: expected=%0d measured=%0d.",
                     expected_count, clkmeas_count);

        if (prbs_stop_seen && prbs_stopped_seen) begin
            $display("[PASS] PRBS stopped.");
        end else begin
            error_count++;
            $error("PRBS stopped state was not observed.");
        end

        $display("----------------------------------------");
        $display("Transactions : %0d", transaction_count);
        $display("Errors       : %0d", error_count);
        $display("========================================");
        $display("");
    endfunction

endclass
