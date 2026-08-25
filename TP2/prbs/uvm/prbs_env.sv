class prbs_env;

    virtual prbs_if vif;

    mailbox #(prbs_txn) gen2drv;

    prbs_generator gen;
    prbs_driver    drv;
    prbs_monitor   mon;

    function new(virtual prbs_if vif);
        this.vif = vif;

        gen2drv = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv);
        mon = new(vif);
    endfunction

    task run();
        gen.iteration = 5;

        fork
            drv.run();
            mon.run();
        join_none

        gen.run();
        
        wait (drv.prbs_done == gen.iteration);

        repeat (5) @(vif.cb);
        mon.close();
    endtask 
    
    function void report();
        $display("Fin");
    endfunction
endclass
