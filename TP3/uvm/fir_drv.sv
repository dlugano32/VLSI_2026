class fir_drv;

    mailbox #(fir_txn) gen2drv;
    virtual fir_if.DRV vif;

    bit done = 0;

    function new(virtual fir_if.DRV vif, mailbox #(fir_txn) gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task do_reset(int cycles = 5);
        vif.i_rst           = 1'b1;
        vif.cb_drv.i_valid <= 1'b0;
        vif.cb_drv.i_data  <= '0;

        repeat (cycles) @(vif.cb_drv);
        vif.i_rst = 1'b0;
    endtask

    task drive_bus(fir_txn txn);
        @(vif.cb_drv);

        case (txn.op)
            fir_txn::SEND_SAMPLE: begin
                vif.cb_drv.i_valid <= 1'b1;
                vif.cb_drv.i_data  <= txn.data;
            end

            fir_txn::IDLE: begin
                vif.cb_drv.i_valid <= 1'b0;
                vif.cb_drv.i_data  <= '0;
            end

            fir_txn::STOP: begin
                vif.cb_drv.i_valid <= 1'b0;
                vif.cb_drv.i_data  <= '0;
                done = 1'b1;
            end
        endcase
    endtask

    task run ();
        fir_txn txn;
        done = 0;
        do_reset();

        forever begin
            gen2drv.get(txn);
            drive_bus(txn);
        end
    endtask

endclass
