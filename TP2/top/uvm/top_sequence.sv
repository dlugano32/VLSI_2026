class top_sequence;

    localparam bit [7:0] ADDR_PRBS_CTRL      = 8'h00;
    localparam bit [7:0] ADDR_PRBS_SEED      = 8'h01;
    localparam bit [7:0] ADDR_PRBS_STATUS    = 8'h02;
    localparam bit [7:0] ADDR_FIR_TAP_0      = 8'h10;
    localparam bit [7:0] ADDR_FIR_CTRL       = 8'h1A;
    localparam bit [7:0] ADDR_FIR_STATUS     = 8'h1B;
    localparam bit [7:0] ADDR_DU_CTRL        = 8'h20;
    localparam bit [7:0] ADDR_DU_THRESHOLD   = 8'h21;
    localparam bit [7:0] ADDR_DU_STATUS      = 8'h22;
    localparam bit [7:0] ADDR_DU_RDADDR      = 8'h23;
    localparam bit [7:0] ADDR_DU_RDDATA      = 8'h24;
    localparam bit [7:0] ADDR_DU_RDPTR       = 8'h25;
    localparam bit [7:0] ADDR_DU_SELECT      = 8'h26;
    localparam bit [7:0] ADDR_CLKMEAS_CTRL   = 8'h30;
    localparam bit [7:0] ADDR_CLKMEAS_WINDOW = 8'h31;
    localparam bit [7:0] ADDR_CLKMEAS_COUNT  = 8'h32;
    localparam bit [7:0] ADDR_CLKMEAS_STATUS = 8'h33;

    localparam logic [31:0] PRBS_SEED = 32'h0000_FFFF;
    localparam logic [2:0]  PRBS_SEL  = 3'b101;

    localparam time CLK_CPU_PERIOD = 5ns; //! 200 MHz
    localparam time CLK_DSP_PERIOD = 1ns; //! 1 GHz
    localparam int unsigned CLKMEAS_WINDOW = 200000;

    mailbox #(top_txn) seq2drv;
    mailbox #(top_txn) drv2seq;

    logic [11:0] fir_coeff [10];
    int unsigned error_count;

    function new(mailbox #(top_txn) seq2drv, mailbox #(top_txn) drv2seq);
        this.seq2drv = seq2drv;
        this.drv2seq = drv2seq;
        error_count  = 0;

        //! First ten coefficients for symmetric FIR.
        fir_coeff[0] = 12'hFE6;
        fir_coeff[1] = 12'hFFD;
        fir_coeff[2] = 12'h038;
        fir_coeff[3] = 12'h03A;
        fir_coeff[4] = 12'hFC3;
        fir_coeff[5] = 12'hF44;
        fir_coeff[6] = 12'hFAA;
        fir_coeff[7] = 12'h157;
        fir_coeff[8] = 12'h36D;
        fir_coeff[9] = 12'h461;
    endfunction

    task automatic execute(top_txn request, output logic [31:0] rdata);
        top_txn response;

        seq2drv.put(request);
        drv2seq.get(response);
        rdata = response.rdata;

        if (!response.completed) begin
            error_count++;
            $error("Sequence transaction failed: kind=%0d addr=0x%02h", response.kind, response.addr);
        end
    endtask

    task automatic write_reg(bit [7:0] addr, logic [31:0] data);
        top_txn tr;
        logic [31:0] unused;

        tr       = new();
        tr.kind  = BUS_WRITE;
        tr.addr  = addr;
        tr.wdata = data;
        execute(tr, unused);
    endtask

    task automatic read_reg(bit [7:0] addr, output logic [31:0] data);
        top_txn tr;

        tr      = new();
        tr.kind = BUS_READ;
        tr.addr = addr;
        execute(tr, data);
    endtask

    task automatic wait_cpu_cycles(int unsigned cycles);
        top_txn tr;
        logic [31:0] unused;

        tr             = new();
        tr.kind        = BUS_IDLE;
        tr.idle_cycles = cycles;
        execute(tr, unused);
    endtask

    task automatic expect_read(
        bit [7:0] addr,
        logic [31:0] expected,
        logic [31:0] mask,
        string label
    );
        logic [31:0] actual;

        read_reg(addr, actual);
        if ((actual & mask) !== (expected & mask)) begin
            error_count++;
            $error("Readback mismatch for %s: expected=0x%08h actual=0x%08h mask=0x%08h",
                   label, expected, actual, mask);
        end
    endtask

    task automatic poll_mask(
        bit [7:0] addr,
        logic [31:0] mask,
        logic [31:0] expected,
        int unsigned max_reads,
        string label
    );
        logic [31:0] actual;

        for (int unsigned attempt = 0; attempt < max_reads; attempt++) begin
            read_reg(addr, actual);
            if ((actual & mask) === (expected & mask))
                return;
        end

        error_count++;
        $error("Polling timeout for %s: expected masked value 0x%08h", label, expected & mask);
    endtask

    task run();
        logic [31:0] rdata;
        logic [31:0] expected_count;
        int unsigned count_error;

        $display("");
        $display("========================================");
        $display("Top integration sequence started");
        $display("========================================");

        //! ---------------------------------------------------------------------
        //! Stage 1: configure and verify all programmable blocks.
        //! ---------------------------------------------------------------------
        write_reg(ADDR_PRBS_SEED, PRBS_SEED);
        write_reg(ADDR_PRBS_CTRL, {27'b0, PRBS_SEL, 2'b00});

        for (int tap = 0; tap < 10; tap++)
            write_reg(ADDR_FIR_TAP_0 + tap, {20'b0, fir_coeff[tap]});

        //! Commit coefficients while keeping the FIR disabled.
        write_reg(ADDR_FIR_CTRL, 32'h0000_0001);
        poll_mask(ADDR_FIR_STATUS, 32'h1, 32'h1, 50, "FIR busy assertion");
        poll_mask(ADDR_FIR_STATUS, 32'h1, 32'h0, 50, "FIR busy deassertion");

        //! POST mode, zero threshold. No arm yet.
        write_reg(ADDR_DU_THRESHOLD, 32'h0000_0000);
        write_reg(ADDR_DU_CTRL,      32'h0000_0004);
        write_reg(ADDR_DU_SELECT,    32'h0000_0000);
        write_reg(ADDR_DU_RDADDR,    32'h0000_0000);

        write_reg(ADDR_CLKMEAS_WINDOW, CLKMEAS_WINDOW);

        expect_read(ADDR_PRBS_SEED, PRBS_SEED, 32'h0000_7FFF, "PRBS seed");
        expect_read(ADDR_PRBS_CTRL, {27'b0, PRBS_SEL, 2'b00}, 32'h0000_001C, "PRBS order");

        for (int tap = 0; tap < 10; tap++)
            expect_read(ADDR_FIR_TAP_0 + tap, {{20{1'b0}}, fir_coeff[tap]}, 32'h0000_03FF, $sformatf("FIR tap %0d", tap));

        expect_read(ADDR_FIR_CTRL,       32'h0000_0000, 32'h0000_0002, "FIR enable");
        expect_read(ADDR_DU_THRESHOLD,   32'h0000_0000, 32'hFFFF_FFFF, "DU threshold");
        expect_read(ADDR_DU_CTRL,        32'h0000_0004, 32'h0000_0006, "DU mode");
        expect_read(ADDR_CLKMEAS_WINDOW, CLKMEAS_WINDOW, 32'h0007_FFFF, "frequency window");

        //! ---------------------------------------------------------------------
        //! Stage 2: execute the frequency meter through the integrated regmap.
        //! ---------------------------------------------------------------------
        write_reg(ADDR_CLKMEAS_CTRL, 32'h0000_0001);
        poll_mask(ADDR_CLKMEAS_STATUS, 32'h1, 32'h0, 20, "frequency done clear");
        wait_cpu_cycles(CLKMEAS_WINDOW);
        poll_mask(ADDR_CLKMEAS_STATUS, 32'h1, 32'h1, 50, "frequency completion");
        read_reg(ADDR_CLKMEAS_COUNT, rdata);

        expected_count = (CLKMEAS_WINDOW * CLK_CPU_PERIOD) / CLK_DSP_PERIOD;
        count_error = (rdata > expected_count)
                    ? (rdata - expected_count)
                    : (expected_count - rdata);

        if (count_error > (expected_count / 100)) begin
            error_count++;
            $error("Frequency mismatch: expected=%0d measured=%0d", expected_count, rdata);
        end

        //! ---------------------------------------------------------------------
        //! Stage 3: start PRBS and observe its running status.
        //! ---------------------------------------------------------------------
        write_reg(ADDR_PRBS_CTRL, {27'b0, PRBS_SEL, 2'b01});
        poll_mask(ADDR_PRBS_STATUS, 32'h1, 32'h1, 50, "PRBS running");

        //! ---------------------------------------------------------------------
        //! Stage 4: enable FIR and allow its pipeline to fill.
        //! ---------------------------------------------------------------------
        write_reg(ADDR_FIR_CTRL, 32'h0000_0002);
        wait_cpu_cycles(20);

        //! ---------------------------------------------------------------------
        //! Stage 5: arm all four DUs and wait for a complete POST acquisition.
        //! ---------------------------------------------------------------------
        write_reg(ADDR_DU_CTRL, 32'h0000_0005);
        poll_mask(ADDR_DU_STATUS, 32'hF, 32'hF, 1000, "DU completion");

        //! ---------------------------------------------------------------------
        //! Stage 6: read pointer and full memory from every DU lane.
        //! ---------------------------------------------------------------------
        for (int lane = 0; lane < 4; lane++) begin
            write_reg(ADDR_DU_SELECT, lane);
            read_reg(ADDR_DU_RDPTR, rdata);

            for (int addr = 0; addr < 256; addr++) begin
                write_reg(ADDR_DU_RDADDR, addr);
                read_reg(ADDR_DU_RDDATA, rdata);

                if ($isunknown(rdata)) begin
                    error_count++;
                    $error("DU read returned X/Z: lane=%0d addr=%0d data=0x%08h", lane, addr, rdata);
                end
            end
        end

        //! Stop PRBS and disable FIR after acquisition data is safely stored.
        write_reg(ADDR_PRBS_CTRL, {27'b0, PRBS_SEL, 2'b10});
        poll_mask(ADDR_PRBS_STATUS, 32'h1, 32'h0, 50, "PRBS stopped");
        write_reg(ADDR_FIR_CTRL, 32'h0000_0000);

        wait_cpu_cycles(10);

        $display("Top integration sequence finished with %0d sequence errors.", error_count);
    endtask

endclass
