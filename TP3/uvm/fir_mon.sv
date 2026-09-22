class fir_mon;
    virtual fir_if.MON vif;

    function new(virtual fir_if.MON vif);
        this.vif = vif;
    endfunction

    task run();
        int unsigned cycle = 0;

        forever begin
            @(vif.cb_mon);

            if (!vif.cb_mon.i_arst_n) begin
                $display("MON cycle=%0d reset active", cycle);
            end else if (vif.cb_mon.i_en) begin
                $display("MON cycle=%0d data=%0d output=%0d",
                    cycle,
                    $signed(vif.cb_mon.i_data),
                    $signed(vif.cb_mon.o_data)
                );
            end

            cycle++;
        end
    endtask

endclass
