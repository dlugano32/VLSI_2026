class fir_mon;
    import fir_pkg::*;

    virtual fir_if.MON vif;
    mailbox #(data_t) mon2scb;

    function new(virtual fir_if.MON vif, mailbox #(data_t) mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        data_t sample;

        forever begin
            @(vif.cb_mon);

            if (!vif.cb_mon.i_rst && (vif.cb_mon.o_valid === 1'b1)) begin
                sample = vif.cb_mon.o_data;
                mon2scb.put(sample);
            end
        end
    endtask

endclass
