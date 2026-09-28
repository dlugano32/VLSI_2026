class fir_par_drv;

    mailbox #(fir_par_txn) gen2drv;
    virtual fir_par_if.DRV vif;

    bit done = 0;

    function new(virtual fir_par_if.DRV vif, mailbox #(fir_par_txn) gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task do_reset(int cycles = 5);
        vif.i_arst_n         = 1'b0;
        vif.cb_drv.i_en     <= 1'b0;
        vif.cb_drv.i_data   <= '0;
        vif.cb_drv.i_coeffs <= '0;

        repeat (cycles) @(vif.cb_drv);
        vif.i_arst_n = 1'b1;
    endtask

    task drive_bus(fir_par_txn txn);
        @(vif.cb_drv);

        case (txn.op)
            fir_par_txn::LOAD_COEFFS: begin
                vif.cb_drv.i_en     <= 1'b0;
                vif.cb_drv.i_coeffs <= txn.coeffs;
            end

            fir_par_txn::SEND_SAMPLES: begin
                vif.cb_drv.i_en   <= 1'b1;
                vif.cb_drv.i_data <= txn.data;
            end

            fir_par_txn::IDLE: begin
                vif.cb_drv.i_en <= 1'b0;
            end

            fir_par_txn::STOP: begin
                vif.cb_drv.i_en <= 1'b0;
                done = 1'b1;
            end
        endcase
    endtask

    task run ();
        fir_par_txn txn;
        done = 0;
        do_reset();

        forever begin
            gen2drv.get(txn);
            drive_bus(txn);
        end
    endtask

endclass
