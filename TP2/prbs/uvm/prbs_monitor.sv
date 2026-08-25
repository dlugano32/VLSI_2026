class prbs_monitor;

    localparam int WIDTH = 15;

    virtual prbs_if.MON vif;
    integer fd;

    function new(virtual prbs_if.MON vif);
        this.vif = vif;
        fd = $fopen("prbs_output.csv", "w");
        $fwrite(fd, "transaction_id,sample_idx,sel,seed,actual\n");
    endfunction

    task run();
        int transaction_id = 0;
        int sample_idx     = 0;
        bit active         = 0;
        bit [WIDTH-1:0] active_seed;
        bit [2:0] active_sel;

        forever begin
            @(vif.cb_mon);

            if (!vif.cb_mon.rst_n) begin
                active = 0;
                sample_idx = 0;
            end else begin
                if (vif.cb_mon.i_start) begin
                    active_seed = vif.cb_mon.i_seed;
                    active_sel  = vif.cb_mon.i_sel;
                    sample_idx  = 0;
                    active      = 1;
                end

                if (active && vif.cb_mon.o_running) begin
                    for (int lane = 0; lane < 4; lane++) begin
                        $fwrite(
                            fd,
                            "%0d,%0d,%0d,%0h,%0b\n",
                            transaction_id,
                            sample_idx,
                            active_sel,
                            active_seed,
                            vif.cb_mon.o_prbs[lane]
                        );

                        sample_idx++;
                    end
                end else if (active && !vif.cb_mon.o_running && !vif.cb_mon.i_start) begin
                    transaction_id++;
                    sample_idx = 0;
                    active = 0;
                end
            end
        end
    endtask

    function void close();
        $fclose(fd);
    endfunction

endclass
