class top_env;

    virtual top_if vif;

    mailbox #(top_txn) seq2drv;
    mailbox #(top_txn) drv2seq;
    mailbox #(top_txn) mon2sb;

    //! Other clasess
    top_sequence   seq;
    top_driver     drv;
    top_monitor    mon;
    top_scoreboard sb;

    function new(virtual top_if vif);
        this.vif = vif;

        seq2drv = new();
        drv2seq = new();
        mon2sb  = new();

        seq = new(seq2drv, drv2seq);
        drv = new(vif, seq2drv, drv2seq);
        mon = new(vif, mon2sb);
        sb  = new(mon2sb);
    endfunction

    task run();
        fork
            drv.run();
            mon.run();
            sb.run();
        join_none

        wait (drv.reset_done);
        seq.run();

        //! Allow the passive monitor and scoreboard to consume the final reads.
        repeat (10) @(vif.cb_mon);
    endtask

    function void report();
        int unsigned total_errors;

        sb.report();
        total_errors = seq.error_count + drv.error_count + mon.error_count + sb.error_count;

        if (total_errors != 0)
            $fatal(1, "Top integration test failed with %0d errors.", total_errors);

        $display("========================================");
        $display("Top integration simulation: PASS");
        $display("========================================");
    endfunction

endclass
