class fir_par_env;
    
    virtual fir_par_if vif;

    mailbox #(fir_par_txn) gen2drv;

    fir_par_gen gen;
    fir_par_drv drv;
    fir_par_mon mon;
    
    function new(virtual fir_par_if vif);
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
