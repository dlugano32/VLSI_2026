class prbs_monitor #(parameter int WIDTH = 15);

    virtual prbs_if #(WIDTH).MON vif;
    integer fd;

    function new(virtual prbs_if #(WIDTH).MON vif);
        this.vif = vif;
        fd = $fopen("prbs_output.csv", "w");
        $fwrite(fd, "transaction_id,sample_idx,sel,seed,actual\n");
    endfunction

    task run();
        int transaction_id = 0;
        int sample_idx     = 0;

        forever begin
            @(vif.cb_mon);

            if (vif.cb_mon.i_en) begin
                $fwrite(
                    fd,
                    "%0d,%0d,%0d,%0h,%0b\n",
                    transaction_id,
                    sample_idx,
                    vif.cb_mon.i_sel,
                    vif.cb_mon.i_seed,
                    vif.cb_mon.o_prbs
                );

                sample_idx++;
            end
            else if (sample_idx != 0) begin
                transaction_id++;
                sample_idx = 0;
            end
        end
    endtask

endclass