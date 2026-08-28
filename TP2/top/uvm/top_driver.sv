class top_driver;

    localparam int ACK_TIMEOUT_CYCLES = 100;

    virtual top_if.DRV vif;
    mailbox #(top_txn) seq2drv;
    mailbox #(top_txn) drv2seq;

    bit reset_done;
    int unsigned error_count;

    function new(
        virtual top_if.DRV vif,
        mailbox #(top_txn) seq2drv,
        mailbox #(top_txn) drv2seq
    );
        if (vif == null)
            $fatal(1, "top_driver: vif is null");

        this.vif     = vif;
        this.seq2drv = seq2drv;
        this.drv2seq = drv2seq;
        reset_done   = 0;
        error_count  = 0;
    endfunction

    task do_reset(int cycles = 5);
        vif.arst_n         = 1'b0;
        vif.cb_drv.addr     <= '0;
        vif.cb_drv.wdata    <= '0;
        vif.cb_drv.req      <= 1'b0;
        vif.cb_drv.is_write <= 1'b0;

        repeat (cycles) @(vif.cb_drv);
        vif.arst_n = 1'b1;

        //! Allow both internal reset synchronizers to release
        repeat (cycles) @(vif.cb_drv);
        reset_done = 1'b1;
    endtask

    task drive_bus(top_txn tr);
        int unsigned wait_cycles;

        if (tr.kind == BUS_IDLE) begin
            repeat (tr.idle_cycles) @(vif.cb_drv);
            tr.completed = 1'b1;
            drv2seq.put(tr);
            return;
        end

        @(vif.cb_drv);
        vif.cb_drv.addr     <= tr.addr;
        vif.cb_drv.wdata    <= tr.wdata;
        vif.cb_drv.is_write <= (tr.kind == BUS_WRITE);
        vif.cb_drv.req      <= 1'b1;

        //! Requests are one CPU-clock pulse. The regmap stores a delayed DU read.
        @(vif.cb_drv);
        vif.cb_drv.req <= 1'b0;

        wait_cycles = 0;
        while (wait_cycles < ACK_TIMEOUT_CYCLES) begin
            @(vif.cb_drv);

            if (vif.cb_drv.ack === 1'b1) begin
                tr.rdata     = vif.cb_drv.rdata;
                tr.completed = 1'b1;
                drv2seq.put(tr);
                return;
            end

            wait_cycles++;
        end

        error_count++;
        tr.completed = 1'b0;
        $error("Bus timeout: kind=%0d addr=0x%02h", tr.kind, tr.addr);
        drv2seq.put(tr);
    endtask

    task run();
        top_txn tr;

        do_reset();

        forever begin
            seq2drv.get(tr);
            drive_bus(tr);
        end
    endtask

endclass
