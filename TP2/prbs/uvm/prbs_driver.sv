class prbs_driver;

    localparam int WIDTH = 15;

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
        vif.cb.i_start <= 0;
        vif.cb.i_stop  <= 0;
        vif.cb.i_seed  <= '0;
        vif.cb.i_sel   <= '0;
        repeat (cycles) @(vif.cb);
        vif.cb.rst_n <= 1;
        @(vif.cb);
    endtask

    task start_sequence(bit [WIDTH-1:0] seed, bit [2:0] sel);
        vif.cb.i_seed <= seed;
        vif.cb.i_sel  <= sel;
        vif.cb.i_stop <= 0;
        vif.cb.i_start <= 1;
        @(vif.cb);
        vif.cb.i_start <= 0;
    endtask

    task transmit(int cycles);
        //! The first output group is observed on the first clock after start.
        //! Assert stop before the clock following the final requested group.
        repeat (cycles - 1) @(vif.cb);
        vif.cb.i_stop <= 1;
        @(vif.cb);
        vif.cb.i_stop <= 0;

        do @(vif.cb); while (vif.cb.o_running);
    endtask


    task run();
        prbs_txn tr;

        do_reset();

        forever begin
            gen2drv.get(tr);
            tr.display("DRV");
            start_sequence(tr.seed, tr.sel);
            transmit(tr.cycles);

            prbs_done++;
        end
    endtask

endclass
