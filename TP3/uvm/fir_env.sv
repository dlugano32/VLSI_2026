class fir_env;
    
    virtual fir_if vif;

    mailbox #(fir_txn) gen2drv;
    mailbox #(data_t)  mon2scb;

    fir_gen gen;
    fir_drv drv;
    fir_mon mon;
    fir_scb scb;
    
    function new(virtual fir_if vif);
        this.vif = vif;

        gen2drv = new();
        mon2scb = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2scb);
        scb = new(mon2scb);
    endfunction
    
    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0)
            $fatal(1, "Interpolator regression failed with %0d mismatches", scb.error_count);

        $display("Interpolator regression PASS: %0d outputs matched", scb.checked_count);
    endtask
endclass
