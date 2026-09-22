class fir_env;
    
    virtual fir_if vif;

    mailbox #(fir_txn) gen2drv;

    fir_gen gen;
    fir_drv drv;
    fir_mon mon;
    
    function new(virtual fir_if vif);
        this.vif = vif;

        gen2drv = new();

        gen = new(gen2drv, 100);
        drv = new(vif, gen2drv);
        mon = new(vif);
    endfunction
    
    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
        join_none

        wait (drv.done);

        repeat(5) @(vif.cb_drv);
    endtask
endclass
