class fir_par_mon;
    import fir_par_pkg::*;
    
    virtual fir_par_if.MON vif;

    function new(virtual fir_par_if.MON vif);
        this.vif = vif;
    endfunction

    task run();
        int unsigned cycle = 0;

        forever begin
            @(vif.cb_mon);

            if (!vif.cb_mon.i_arst_n) begin
                $display("MON cycle=%0d reset active", cycle);
            end else if (vif.cb_mon.i_en) begin
                for(int i=0; i<PAR; i++) begin
                    $display("MON cycle=%0d data[%0d]=%0d output[%0d]=%0d",
                        cycle,
                        i,
                        $signed(vif.cb_mon.i_data[i]),
                        i,
                        $signed(vif.cb_mon.o_data[i])
                    );
                end
            end

            cycle++;
        end
    endtask

endclass
