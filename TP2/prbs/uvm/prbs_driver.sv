class prbs_driver #(parameter int WIDTH = 15);

    virtual prbs_if.TB vif;
    mailbox #(prbs_txn) gen2drv;
    int prbs_done = 0;


    function new(virtual prbs_if.TB vif, mailbox #(prbs_txn) gen2drv);
        if (vif == null) $fatal(1, "prbs_driver: vif is null");
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction


    task do_reset(int cycles = 3);
        vif.cb.rst_n  <= 0;
        vif.cb.i_en   <= 0;
        repeat (cycles) @(vif.cb);
        vif.cb.rst_n <= 1;
        @(vif.cb);
    endtask

    task configure(bit [WIDTH-1:0] seed, bit [2:0] sel);
        vif.cb.rst_n  <= 1;
        vif.cb.i_en   <= 0;
        vif.cb.i_seed <= seed;
        vif.cb.i_sel  <= sel;
        @(vif.cb);
    endtask

    task transmit(int n);
        vif.cb.i_en <= 1;
        repeat (n) @(vif.cb);
        vif.cb.i_en <= 0;
        @(vif.cb);
    endtask


    task run();
        prbs_txn tr;

        forever begin
            gen2drv.get(tr);
            tr.display("DRV");
            configure(tr.seed, tr.sel);
            do_reset(3);
            transmit(tr.iteration);

            prbs_done++;
        end
    endtask

endclass
