class prbs_generator;

    mailbox #(prbs_txn) gen2drv;

    int iteration = 3;

    function new (mailbox #(prbs_txn) gen2drv);
        this.gen2drv=gen2drv;
    endfunction

    task run();
        prbs_txn tr;

        repeat (iteration) begin
            tr=new();
            assert(tr.randomize());

            tr.display("GEN");
            
            gen2drv.put(tr);
        end
    endtask

endclass
