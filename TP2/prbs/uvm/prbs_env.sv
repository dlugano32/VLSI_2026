class prbs_env #(parameter int WIDTH = 15);

    virtual prbs_if #(WIDTH) vif;

    mailbox #(prbs_txn) gen2drv;

    prbs_generator           gen;
    prbs_driver  #(WIDTH)    drv;
    prbs_monitor #(WIDTH)    mon;

    function new(virtual prbs_if #(WIDTH) vif);
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

        repeat (50) @(vif.cb);
    endtask 
    
    function void report();
        $display("Fin");
    endfunction
endclass
