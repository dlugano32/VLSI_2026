class top_monitor;

    virtual top_if.MON vif;
    mailbox #(top_txn) mon2sb;

    int unsigned error_count;

    function new(virtual top_if.MON vif, mailbox #(top_txn) mon2sb);
        if (vif == null)
            $fatal(1, "top_monitor: vif is null");

        this.vif    = vif;
        this.mon2sb = mon2sb;
        error_count = 0;
    endfunction

    task run();
        top_txn pending_tr;
        top_txn observed_tr;
        bit pending;

        pending = 0;

        forever begin
            @(vif.cb_mon);

            if (!vif.cb_mon.arst_n) begin
                pending = 0;
            end else begin
                if (!pending && (vif.cb_mon.req === 1'b1)) begin
                    pending_tr       = new();
                    pending_tr.kind  = vif.cb_mon.is_write ? BUS_WRITE : BUS_READ;
                    pending_tr.addr  = vif.cb_mon.addr;
                    pending_tr.wdata = vif.cb_mon.wdata;
                    pending          = 1'b1;
                end

                if (vif.cb_mon.ack === 1'b1) begin
                    if (!pending) begin
                        error_count++;
                        $error("Monitor observed ACK without a pending request.");
                    end else begin
                        observed_tr           = new();
                        observed_tr.kind      = pending_tr.kind;
                        observed_tr.addr      = pending_tr.addr;
                        observed_tr.wdata     = pending_tr.wdata;
                        observed_tr.rdata     = vif.cb_mon.rdata;
                        observed_tr.completed = 1'b1;
                        mon2sb.put(observed_tr);
                        pending = 1'b0;
                    end
                end
            end
        end
    endtask

endclass
